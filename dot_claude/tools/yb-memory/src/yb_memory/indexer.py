"""chunkerの出力をDBに保存するインデクサーモジュール。

セッションJSONLファイルを検出し、chunkerでパースしたチャンクを
SQLiteに冪等に書き込む。既に取り込み済みのセッションはスキップする。
"""

import json
import logging
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

from yb_memory.chunker import parse_session
from yb_memory.db import is_session_ingested
from yb_memory.models import Chunk

logger = logging.getLogger(__name__)

CLAUDE_PROJECTS_DIR: Path = Path.home() / ".claude" / "projects"
CLAUDE_SESSIONS_DIR: Path = Path.home() / ".claude" / "sessions"


def find_session_file(session_id: str) -> Path | None:
    """セッションIDに対応するJSONLファイルを探す。

    ~/.claude/projects/ 配下の全プロジェクトディレクトリを検索する。

    Args:
        session_id: 検索対象のセッションID

    Returns:
        見つかった場合はJSONLファイルのパス。見つからない場合はNone。
    """
    if not CLAUDE_PROJECTS_DIR.is_dir():
        logger.warning("プロジェクトディレクトリが存在しません: %s", CLAUDE_PROJECTS_DIR)
        return None

    target_name = f"{session_id}.jsonl"

    for project_dir in CLAUDE_PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        candidate = project_dir / target_name
        if candidate.is_file():
            return candidate

    return None


def find_all_sessions() -> list[tuple[str, Path]]:
    """全プロジェクトの全セッションJSONLファイルを見つける。

    ~/.claude/projects/ 配下の全ディレクトリから *.jsonl を列挙する。
    ファイル名（拡張子除く）をsession_idとして返す。

    Returns:
        [(session_id, jsonl_path), ...] のリスト
    """
    results: list[tuple[str, Path]] = []

    if not CLAUDE_PROJECTS_DIR.is_dir():
        logger.warning("プロジェクトディレクトリが存在しません: %s", CLAUDE_PROJECTS_DIR)
        return results

    for project_dir in CLAUDE_PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        for jsonl_file in project_dir.glob("*.jsonl"):
            session_id = jsonl_file.stem
            results.append((session_id, jsonl_file))

    return results


def find_sessions_since(since: str) -> list[tuple[str, Path]]:
    """指定日時以降のセッションを見つける。

    ~/.claude/sessions/*.json のstartedAtフィールド（ミリ秒timestamp）で
    開始日時を判定し、since以降のセッションを返す。

    Args:
        since: ISO8601形式の日付文字列（例: "2026-03-01"）

    Returns:
        [(session_id, jsonl_path), ...] のリスト
    """
    results: list[tuple[str, Path]] = []

    if not CLAUDE_SESSIONS_DIR.is_dir():
        logger.warning("セッションディレクトリが存在しません: %s", CLAUDE_SESSIONS_DIR)
        return results

    # sinceをdatetimeに変換（タイムゾーンなしの場合はUTCとして扱う）
    try:
        since_dt = datetime.fromisoformat(since)
        if since_dt.tzinfo is None:
            since_dt = since_dt.replace(tzinfo=timezone.utc)
    except ValueError:
        logger.error("日付の形式が不正です: %s", since)
        return results

    since_ms = int(since_dt.timestamp() * 1000)

    for session_file in CLAUDE_SESSIONS_DIR.glob("*.json"):
        try:
            with session_file.open("r", encoding="utf-8") as f:
                session_data = json.load(f)
        except (json.JSONDecodeError, OSError) as e:
            logger.warning("セッションファイルの読み込みに失敗: %s: %s", session_file.name, e)
            continue

        started_at_ms = session_data.get("startedAt")
        if started_at_ms is None:
            continue

        # ミリ秒タイムスタンプがsince以降か判定
        if started_at_ms < since_ms:
            continue

        session_id = session_data.get("sessionId")
        if not session_id:
            # ファイル名からsession_idを取得するフォールバック
            session_id = session_file.stem

        # 対応するJSONLファイルを探す
        jsonl_path = find_session_file(session_id)
        if jsonl_path is not None:
            results.append((session_id, jsonl_path))

    return results


def ingest_session(conn: sqlite3.Connection, session_id: str, jsonl_path: Path) -> int:
    """1セッションを取り込む。既に取り込み済みならスキップして0を返す。

    処理フロー:
    1. is_session_ingested()で取り込み済みか確認
    2. parse_session()でチャンクを生成
    3. sessionsテーブルにセッション情報を挿入
    4. chunksテーブルにチャンクを一括挿入
    5. sessionsのchunk_countを更新
    6. トランザクションでまとめてcommit

    Args:
        conn: SQLite接続オブジェクト
        session_id: 取り込み対象のセッションID
        jsonl_path: セッションJSONLファイルのパス

    Returns:
        取り込んだチャンク数。スキップした場合は0。
    """
    # 冪等性チェック: 既に取り込み済みならスキップ
    if is_session_ingested(conn, session_id):
        logger.debug("セッションは取り込み済みです: %s", session_id)
        return 0

    # チャンクを生成
    chunks, title = parse_session(jsonl_path)

    if not chunks:
        logger.info("チャンクが0件のためスキップ: %s", session_id)
        return 0

    # 最初のチャンクからproject_pathとcreated_atを取得
    project_path: str = chunks[0].project_path
    created_at: str = chunks[0].created_at

    try:
        # sessionsテーブルに挿入
        conn.execute(
            """
            INSERT INTO sessions (session_id, project_path, started_at, title, chunk_count)
            VALUES (?, ?, ?, ?, 0)
            """,
            (session_id, project_path, created_at, title),
        )

        # chunksテーブルに一括挿入
        # chunk.session_idがファイル名ベースのsession_idと異なる場合があるため
        # 引数のsession_idで統一する
        conn.executemany(
            """
            INSERT INTO chunks (session_id, chunk_index, question, answer,
                                tool_summary, created_at, project_path)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    session_id,
                    chunk.chunk_index,
                    chunk.question,
                    chunk.answer,
                    chunk.tool_summary,
                    chunk.created_at,
                    chunk.project_path,
                )
                for chunk in chunks
            ],
        )

        # chunk_countを更新
        conn.execute(
            "UPDATE sessions SET chunk_count = ? WHERE session_id = ?",
            (len(chunks), session_id),
        )

        # ベクトルインデックスの作成（sqlite-vecとsentence-transformersが利用可能な場合）
        try:
            from yb_memory.db import has_vector_support
            from yb_memory.embedder import encode_documents_batch, embedding_to_bytes

            if has_vector_support(conn):
                # 挿入したチャンクのIDを取得
                cursor = conn.execute(
                    "SELECT id, question, answer FROM chunks WHERE session_id = ? ORDER BY chunk_index",
                    (session_id,),
                )
                rows = cursor.fetchall()

                if rows:
                    # Q+Aを結合してバッチエンコード（テキスト長を制限）
                    max_text_len = 1024
                    texts = [
                        f"{row['question']} {row['answer']}"[:max_text_len]
                        for row in rows
                    ]
                    embeddings = encode_documents_batch(texts)

                    # chunks_vecに挿入
                    conn.executemany(
                        "INSERT OR IGNORE INTO chunks_vec (id, embedding) VALUES (?, ?)",
                        [
                            (row["id"], embedding_to_bytes(emb))
                            for row, emb in zip(rows, embeddings)
                        ],
                    )
        except ImportError:
            pass  # sentence-transformersが未インストールの場合はスキップ

        conn.commit()
    except sqlite3.Error:
        conn.rollback()
        raise

    logger.info("セッションを取り込みました: %s（%dチャンク）", session_id, len(chunks))
    return len(chunks)


def ingest_all(conn: sqlite3.Connection, dry_run: bool = False) -> dict:
    """全セッションを取り込む。

    find_all_sessions()で発見した全セッションを順次取り込む。
    エラーが発生したセッションはスキップして後続の処理を続行する。

    Args:
        conn: SQLite接続オブジェクト
        dry_run: Trueの場合はDB書き込みせず対象一覧を返す

    Returns:
        {"total": N, "ingested": N, "skipped": N, "errors": N}
    """
    sessions = find_all_sessions()
    return _ingest_sessions(conn, sessions, dry_run=dry_run)


def ingest_since(conn: sqlite3.Connection, since: str, dry_run: bool = False) -> dict:
    """指定日時以降のセッションを取り込む。

    Args:
        conn: SQLite接続オブジェクト
        since: ISO8601形式の日付文字列（例: "2026-03-01"）
        dry_run: Trueの場合はDB書き込みせず対象一覧を返す

    Returns:
        {"total": N, "ingested": N, "skipped": N, "errors": N}
    """
    sessions = find_sessions_since(since)
    return _ingest_sessions(conn, sessions, dry_run=dry_run)


def _ingest_sessions(
    conn: sqlite3.Connection,
    sessions: list[tuple[str, Path]],
    *,
    dry_run: bool = False,
) -> dict:
    """セッションリストを順次取り込む内部ヘルパー。

    Args:
        conn: SQLite接続オブジェクト
        sessions: [(session_id, jsonl_path), ...] のリスト
        dry_run: Trueの場合はDB書き込みせず対象一覧を返す

    Returns:
        {"total": N, "ingested": N, "skipped": N, "errors": N}
    """
    total: int = len(sessions)
    ingested: int = 0
    skipped: int = 0
    errors: int = 0

    for session_id, jsonl_path in sessions:
        # dry_runの場合はスキップ判定のみ行う
        if dry_run:
            if is_session_ingested(conn, session_id):
                skipped += 1
            else:
                ingested += 1
            continue

        try:
            count = ingest_session(conn, session_id, jsonl_path)
            if count == 0:
                skipped += 1
            else:
                ingested += 1
        except Exception:
            logger.exception("セッションの取り込みに失敗: %s", session_id)
            errors += 1

    result = {
        "total": total,
        "ingested": ingested,
        "skipped": skipped,
        "errors": errors,
    }

    logger.info(
        "取り込み結果: 合計=%d 取り込み=%d スキップ=%d エラー=%d",
        total,
        ingested,
        skipped,
        errors,
    )

    return result


def reindex_embeddings(conn: sqlite3.Connection, dry_run: bool = False) -> dict:
    """chunks_vecにembeddingがないチャンクにembeddingを計算して保存する。

    chunksテーブルに存在するがchunks_vecに未登録のチャンクを検出し、
    バッチ処理でembeddingを計算・挿入する。

    Args:
        conn: SQLite接続オブジェクト
        dry_run: Trueの場合は対象件数のみ返し、DB書き込みしない

    Returns:
        {"total": 対象チャンク数, "processed": 処理済み数, "skipped": スキップ数}
    """
    from yb_memory.embedder import encode_documents_batch, embedding_to_bytes

    # chunks_vecにembeddingがないチャンクを検索
    cursor = conn.execute(
        """
        SELECT c.id, c.question, c.answer FROM chunks c
        LEFT JOIN chunks_vec v ON c.id = v.id
        WHERE v.id IS NULL
        """
    )
    rows = cursor.fetchall()
    total = len(rows)

    if dry_run:
        return {"total": total, "processed": 0, "skipped": 0}

    if total == 0:
        return {"total": 0, "processed": 0, "skipped": 0}

    processed = 0
    skipped = 0
    batch_size = 32
    # モデルのトークン上限を考慮してテキストを切り詰める（日本語は概ね1文字1トークン）
    max_text_len = 1024

    for i in range(0, total, batch_size):
        batch = rows[i : i + batch_size]

        try:
            # Q+Aを結合してバッチエンコード（テキスト長を制限）
            texts = [
                f"{row['question']} {row['answer']}"[:max_text_len]
                for row in batch
            ]
            embeddings = encode_documents_batch(texts)

            # chunks_vecに挿入
            conn.executemany(
                "INSERT OR IGNORE INTO chunks_vec (id, embedding) VALUES (?, ?)",
                [
                    (row["id"], embedding_to_bytes(emb))
                    for row, emb in zip(batch, embeddings)
                ],
            )
            conn.commit()
            processed += len(batch)
        except Exception:
            logger.exception("バッチ処理中にエラーが発生（オフセット %d）", i)
            skipped += len(batch)

        # 進捗をstderrに出力
        print(f"\r処理中: {processed + skipped}/{total}", end="", file=sys.stderr)

    # 最後に改行を出力
    print(file=sys.stderr)

    return {"total": total, "processed": processed, "skipped": skipped}
