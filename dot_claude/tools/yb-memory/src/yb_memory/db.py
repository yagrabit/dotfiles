"""SQLite + FTS5 のDB管理モジュール

WALモードを有効にしたSQLite接続の管理、スキーマ作成（冪等）、
スキーマバージョン管理を提供する。
"""

import os
import sqlite3
from pathlib import Path

DEFAULT_DB_PATH: Path = Path.home() / ".local" / "share" / "yb-memory" / "memories.db"
SCHEMA_VERSION: int = 3

# スキーマ定義SQL（冪等）
_SCHEMA_SQL: str = """
CREATE TABLE IF NOT EXISTS schema_version (
  version INTEGER PRIMARY KEY,
  applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY,
  project_path TEXT NOT NULL,
  started_at TEXT,
  title TEXT,
  chunk_count INTEGER NOT NULL DEFAULT 0,
  ingested_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL REFERENCES sessions(session_id),
  chunk_index INTEGER NOT NULL,
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  tool_summary TEXT,
  created_at TEXT NOT NULL,
  project_path TEXT NOT NULL,
  UNIQUE(session_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS idx_chunks_project ON chunks(project_path);
CREATE INDEX IF NOT EXISTS idx_chunks_created ON chunks(created_at);

CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
  question, answer, tool_summary,
  content='chunks', content_rowid='id',
  tokenize='trigram'
);

-- FTS5同期トリガー: INSERT
CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
  INSERT INTO chunks_fts(rowid, question, answer, tool_summary)
  VALUES (new.id, new.question, new.answer, COALESCE(new.tool_summary, ''));
END;

-- FTS5同期トリガー: DELETE
CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
  INSERT INTO chunks_fts(chunks_fts, rowid, question, answer, tool_summary)
  VALUES ('delete', old.id, old.question, old.answer, COALESCE(old.tool_summary, ''));
END;

-- FTS5同期トリガー: UPDATE
CREATE TRIGGER IF NOT EXISTS chunks_au AFTER UPDATE ON chunks BEGIN
  INSERT INTO chunks_fts(chunks_fts, rowid, question, answer, tool_summary)
  VALUES ('delete', old.id, old.question, old.answer, COALESCE(old.tool_summary, ''));
  INSERT INTO chunks_fts(rowid, question, answer, tool_summary)
  VALUES (new.id, new.question, new.answer, COALESCE(new.tool_summary, ''));
END;

-- ベクトルインデックス（Phase 2）
CREATE TABLE IF NOT EXISTS chunks_vec (
  id INTEGER PRIMARY KEY,
  embedding BLOB
);

-- chunks削除時にchunks_vecも連動削除
CREATE TRIGGER IF NOT EXISTS chunks_ad_vec AFTER DELETE ON chunks BEGIN
  DELETE FROM chunks_vec WHERE id = old.id;
END;
"""


def get_connection(db_path: Path = DEFAULT_DB_PATH) -> sqlite3.Connection:
    """DB接続を取得する。初回はスキーマも作成する。

    DBファイルの親ディレクトリが存在しなければ自動作成する。
    WALモードとsynchronous=NORMALを有効にする。

    Args:
        db_path: DBファイルのパス。デフォルトは ~/.local/share/yb-memory/memories.db

    Returns:
        設定済みのSQLite接続オブジェクト
    """
    # 親ディレクトリを自動作成
    db_path.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    # WALモードとsynchronous設定
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")

    # 外部キー制約を有効化
    conn.execute("PRAGMA foreign_keys=ON")

    # sqlite-vec拡張のロード
    try:
        import sqlite_vec

        conn.enable_load_extension(True)
        sqlite_vec.load(conn)
        conn.enable_load_extension(False)
    except (ImportError, AttributeError, sqlite3.OperationalError):
        pass  # sqlite-vecが利用できない場合はスキップ

    # スキーマを作成（冪等）
    init_schema(conn)

    return conn


def has_vector_support(conn: sqlite3.Connection) -> bool:
    """sqlite-vecが利用可能か判定する。"""
    try:
        import sqlite_vec  # noqa: F401

        return True
    except ImportError:
        return False


# v1→v2マイグレーション用SQL
_MIGRATE_V2_SQL: str = """
-- ベクトルインデックス（Phase 2）
CREATE TABLE IF NOT EXISTS chunks_vec (
  id INTEGER PRIMARY KEY,
  embedding BLOB
);

-- chunks削除時にchunks_vecも連動削除
CREATE TRIGGER IF NOT EXISTS chunks_ad_vec AFTER DELETE ON chunks BEGIN
  DELETE FROM chunks_vec WHERE id = old.id;
END;
"""


_MIGRATE_V3_SQL: str = """
-- FTS5テーブルにtool_summaryカラムを追加するため再作成
-- 旧トリガーを削除
DROP TRIGGER IF EXISTS chunks_ai;
DROP TRIGGER IF EXISTS chunks_ad;
DROP TRIGGER IF EXISTS chunks_au;

-- 旧FTS5テーブルを削除
DROP TABLE IF EXISTS chunks_fts;

-- tool_summary付きのFTS5テーブルを再作成
CREATE VIRTUAL TABLE chunks_fts USING fts5(
  question, answer, tool_summary,
  content='chunks', content_rowid='id',
  tokenize='trigram'
);

-- FTS5同期トリガー: INSERT
CREATE TRIGGER chunks_ai AFTER INSERT ON chunks BEGIN
  INSERT INTO chunks_fts(rowid, question, answer, tool_summary)
  VALUES (new.id, new.question, new.answer, COALESCE(new.tool_summary, ''));
END;

-- FTS5同期トリガー: DELETE
CREATE TRIGGER chunks_ad AFTER DELETE ON chunks BEGIN
  INSERT INTO chunks_fts(chunks_fts, rowid, question, answer, tool_summary)
  VALUES ('delete', old.id, old.question, old.answer, COALESCE(old.tool_summary, ''));
END;

-- FTS5同期トリガー: UPDATE
CREATE TRIGGER chunks_au AFTER UPDATE ON chunks BEGIN
  INSERT INTO chunks_fts(chunks_fts, rowid, question, answer, tool_summary)
  VALUES ('delete', old.id, old.question, old.answer, COALESCE(old.tool_summary, ''));
  INSERT INTO chunks_fts(rowid, question, answer, tool_summary)
  VALUES (new.id, new.question, new.answer, COALESCE(new.tool_summary, ''));
END;

-- 既存データをFTS5に再投入
INSERT INTO chunks_fts(rowid, question, answer, tool_summary)
SELECT id, question, answer, COALESCE(tool_summary, '') FROM chunks;
"""


def init_schema(conn: sqlite3.Connection) -> None:
    """スキーマを作成する（冪等）。

    CREATE IF NOT EXISTS を使用しているため、何度呼んでも安全。
    スキーマバージョンが未登録の場合は現在のバージョンを記録する。
    既存のv1スキーマからはv2へマイグレーションを行う。

    Args:
        conn: SQLite接続オブジェクト
    """
    conn.executescript(_SCHEMA_SQL)

    # v1→v2マイグレーション: chunks_vecテーブルとトリガーを追加
    current_max = conn.execute(
        "SELECT MAX(version) FROM schema_version"
    ).fetchone()[0]

    if current_max is not None and current_max < 2:
        conn.executescript(_MIGRATE_V2_SQL)
        conn.execute(
            "INSERT INTO schema_version (version) VALUES (?)",
            (2,),
        )
        conn.commit()
        current_max = 2

    # v2→v3マイグレーション: FTS5にtool_summaryカラムを追加
    if current_max is not None and current_max < 3:
        conn.executescript(_MIGRATE_V3_SQL)
        conn.execute(
            "INSERT INTO schema_version (version) VALUES (?)",
            (3,),
        )
        conn.commit()

    # スキーマバージョンを記録（未登録の場合のみ）
    existing = conn.execute(
        "SELECT version FROM schema_version WHERE version = ?",
        (SCHEMA_VERSION,),
    ).fetchone()

    if existing is None:
        conn.execute(
            "INSERT INTO schema_version (version) VALUES (?)",
            (SCHEMA_VERSION,),
        )
        conn.commit()


def get_stats(conn: sqlite3.Connection) -> dict:
    """DB統計情報を返す。

    Returns:
        以下のキーを含む辞書:
        - session_count: セッション数
        - chunk_count: チャンク数
        - db_size_bytes: DBファイルサイズ（バイト）
        - schema_version: 現在のスキーマバージョン
    """
    session_count: int = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
    chunk_count: int = conn.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]

    # スキーマバージョンを取得（最新）
    version_row = conn.execute(
        "SELECT MAX(version) FROM schema_version"
    ).fetchone()
    schema_version: int | None = version_row[0] if version_row else None

    # DBファイルサイズを取得
    db_path_row = conn.execute("PRAGMA database_list").fetchone()
    db_file: str = db_path_row[2] if db_path_row else ""
    db_size_bytes: int = 0
    if db_file and os.path.exists(db_file):
        db_size_bytes = os.path.getsize(db_file)

    return {
        "session_count": session_count,
        "chunk_count": chunk_count,
        "db_size_bytes": db_size_bytes,
        "schema_version": schema_version,
    }


def is_session_ingested(conn: sqlite3.Connection, session_id: str) -> bool:
    """セッションが既に取り込み済みか確認する。

    Args:
        conn: SQLite接続オブジェクト
        session_id: 確認対象のセッションID

    Returns:
        取り込み済みの場合True
    """
    row = conn.execute(
        "SELECT 1 FROM sessions WHERE session_id = ?",
        (session_id,),
    ).fetchone()
    return row is not None
