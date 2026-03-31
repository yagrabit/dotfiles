"""FTS5検索 + ベクトル検索 + RRF統合によるメモリ検索モジュール

FTS5 trigramトークナイザによる全文検索、sentence-transformersによる
ベクトル検索、およびRRF（Reciprocal Rank Fusion）によるハイブリッド検索を
提供する。時間減衰を組み合わせてスコアリングする。
"""

import math
import sqlite3
from datetime import datetime, timezone

from yb_memory.models import SearchResult

# FTS5/ベクトル検索から取得する中間結果の最大件数
# time_decay適用後に上位limit件に絞るため、余裕を持って取得する
_FETCH_LIMIT: int = 50


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """2つのベクトルのコサイン類似度を計算する。

    Args:
        a: ベクトルA
        b: ベクトルB

    Returns:
        コサイン類似度（-1.0 ~ 1.0）。ゼロベクトルの場合は0.0
    """
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def fts_search(
    conn: sqlite3.Connection,
    query: str,
    project_path: str | None = None,
    limit: int = 50,
) -> list[tuple[int, float, dict]]:
    """FTS5で検索し、(chunk_id, bm25_score, row_dict)のリストを返す。

    trigramトークナイザは3文字以上のクエリが必要なため、
    2文字以下のクエリでは空リストを返す。

    Args:
        conn: DB接続
        query: 検索クエリ文字列
        project_path: プロジェクトパスでフィルタ（Noneなら全プロジェクト）
        limit: 取得する最大件数

    Returns:
        (chunk_id, bm25_score（正値に変換済み）, row_dict)のリスト
    """
    # trigramトークナイザは3文字以上が必要
    if len(query.strip()) < 3:
        return []

    escaped_query: str = escape_fts5_query(query)

    # FTS5検索SQL組み立て
    if project_path is not None:
        sql = """
            SELECT c.id, c.session_id, c.question, c.answer, c.tool_summary,
                   c.project_path, c.created_at,
                   bm25(chunks_fts, 1.0, 1.0, 0.5) AS bm25_score
            FROM chunks_fts f
            JOIN chunks c ON c.id = f.rowid
            WHERE chunks_fts MATCH ?
              AND c.project_path = ?
            ORDER BY bm25_score
            LIMIT ?
        """
        params: tuple = (escaped_query, project_path, limit)
    else:
        sql = """
            SELECT c.id, c.session_id, c.question, c.answer, c.tool_summary,
                   c.project_path, c.created_at,
                   bm25(chunks_fts, 1.0, 1.0, 0.5) AS bm25_score
            FROM chunks_fts f
            JOIN chunks c ON c.id = f.rowid
            WHERE chunks_fts MATCH ?
            ORDER BY bm25_score
            LIMIT ?
        """
        params = (escaped_query, limit)

    rows = conn.execute(sql, params).fetchall()

    results: list[tuple[int, float, dict]] = []
    for row in rows:
        # bm25()は負値を返す（小さいほどマッチ度が高い）ので、-1を掛けて正にする
        bm25_positive: float = -row["bm25_score"]
        row_dict = {
            "id": row["id"],
            "session_id": row["session_id"],
            "question": row["question"],
            "answer": row["answer"],
            "tool_summary": row["tool_summary"],
            "project_path": row["project_path"],
            "created_at": row["created_at"],
        }
        results.append((row["id"], bm25_positive, row_dict))

    return results


def vector_search(
    conn: sqlite3.Connection,
    query: str,
    project_path: str | None = None,
    limit: int = 50,
) -> list[tuple[int, float, dict]]:
    """ベクトル検索し、(chunk_id, similarity_score, row_dict)のリストを返す。

    sentence-transformersでクエリを埋め込み、chunks_vecテーブルの
    全embeddingとコサイン類似度を計算して上位limit件を返す。

    Args:
        conn: DB接続
        query: 検索クエリ文字列
        project_path: プロジェクトパスでフィルタ（Noneなら全プロジェクト）
        limit: 取得する最大件数

    Returns:
        (chunk_id, similarity_score, row_dict)のリスト（類似度降順）

    Raises:
        ImportError: sentence-transformersがインストールされていない場合
    """
    from yb_memory.embedder import bytes_to_embedding, encode_query

    # クエリを埋め込みベクトルに変換
    query_vec = encode_query(query)

    # chunks_vecから全embedding取得（project_pathフィルタあり）
    if project_path is not None:
        sql = """
            SELECT v.id, v.embedding,
                   c.session_id, c.question, c.answer, c.tool_summary,
                   c.project_path, c.created_at
            FROM chunks_vec v
            JOIN chunks c ON c.id = v.id
            WHERE c.project_path = ?
        """
        rows = conn.execute(sql, (project_path,)).fetchall()
    else:
        sql = """
            SELECT v.id, v.embedding,
                   c.session_id, c.question, c.answer, c.tool_summary,
                   c.project_path, c.created_at
            FROM chunks_vec v
            JOIN chunks c ON c.id = v.id
        """
        rows = conn.execute(sql).fetchall()

    # コサイン類似度を計算
    scored: list[tuple[int, float, dict]] = []
    for row in rows:
        if row["embedding"] is None:
            continue
        doc_vec = bytes_to_embedding(row["embedding"])
        sim = cosine_similarity(query_vec, doc_vec)
        row_dict = {
            "id": row["id"],
            "session_id": row["session_id"],
            "question": row["question"],
            "answer": row["answer"],
            "tool_summary": row["tool_summary"],
            "project_path": row["project_path"],
            "created_at": row["created_at"],
        }
        scored.append((row["id"], sim, row_dict))

    # 類似度降順でソートしてlimit件返す
    scored.sort(key=lambda x: x[1], reverse=True)
    return scored[:limit]


def rrf_merge(
    fts_ids: list[int],
    vec_ids: list[int],
    k: int = 60,
) -> list[tuple[int, float]]:
    """FTS5とベクトル検索の結果をRRF（Reciprocal Rank Fusion）で統合する。

    RRF_score(d) = sum(1 / (k + rank_i(d)))

    Args:
        fts_ids: FTS5検索結果のchunk_idリスト（スコア降順）
        vec_ids: ベクトル検索結果のchunk_idリスト（類似度降順）
        k: RRFパラメータ（デフォルト: 60）

    Returns:
        (chunk_id, rrf_score)のリスト（RRFスコア降順）
    """
    scores: dict[int, float] = {}

    # FTS5側のランクスコアを加算
    for rank, chunk_id in enumerate(fts_ids):
        scores[chunk_id] = scores.get(chunk_id, 0.0) + 1.0 / (k + rank)

    # ベクトル検索側のランクスコアを加算
    for rank, chunk_id in enumerate(vec_ids):
        scores[chunk_id] = scores.get(chunk_id, 0.0) + 1.0 / (k + rank)

    # RRFスコア降順でソート
    merged = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return merged


def normalize_rrf_scores(
    merged: list[tuple[int, float]],
    k: int = 60,
) -> list[tuple[int, float]]:
    """RRFスコアを0-1範囲に正規化する。

    理論上の最大スコア（2/k: 両方の検索でrank0に出現した場合）で割ることで
    スコアを0-1の範囲に変換する。

    Args:
        merged: (chunk_id, rrf_score)のリスト
        k: RRFパラメータ

    Returns:
        (chunk_id, normalized_score)のリスト（元の順序を維持）
    """
    if not merged:
        return []

    max_possible = 2.0 / k
    return [(chunk_id, score / max_possible) for chunk_id, score in merged]


def _try_daemon_search(
    query: str,
    project_path: str | None,
    limit: int,
    mode: str,
) -> list[SearchResult] | None:
    """daemon経由の検索を試みる。daemon未起動や通信エラー時はNoneを返す。"""
    try:
        from yb_memory.server import SOCKET_PATH, send_request

        if not SOCKET_PATH.exists():
            return None

        response = send_request(
            {
                "action": "search",
                "query": query,
                "project_path": project_path,
                "limit": limit,
                "mode": mode,
            },
            timeout=30.0,
        )

        if response is None or response.get("status") != "ok":
            return None

        results = []
        for r in response.get("results", []):
            results.append(
                SearchResult(
                    chunk_id=r["chunk_id"],
                    score=r["score"],
                    question=r["question"],
                    answer=r["answer"],
                    tool_summary=r.get("tool_summary"),
                    project_path=r["project_path"],
                    created_at=r["created_at"],
                    session_id=r["session_id"],
                )
            )
        return results
    except Exception:
        return None


def search(
    conn: sqlite3.Connection,
    query: str,
    project_path: str | None = None,
    limit: int = 5,
    mode: str = "hybrid",
    use_daemon: bool = True,
) -> list[SearchResult]:
    """検索を実行し、時間減衰を適用した結果を返す。

    Args:
        conn: DB接続
        query: 検索クエリ文字列
        project_path: プロジェクトパスでフィルタ（Noneなら全プロジェクト）
        limit: 返す結果数
        mode: 検索モード（"fts", "vector", "hybrid"）
        use_daemon: daemon経由の検索を試みるか（サーバー内部からはFalseにする）

    Returns:
        スコア降順のSearchResultリスト
    """
    # daemon経由の検索を試みる（mode=hybridまたはvectorの場合のみ）
    # FTSは十分高速なのでdaemonを経由する必要がない
    # use_daemon=Falseの場合はスキップ（サーバー内部からの呼び出し時、デッドロック防止）
    if use_daemon and mode in ("hybrid", "vector"):
        daemon_results = _try_daemon_search(query, project_path, limit, mode)
        if daemon_results is not None:
            return daemon_results

    if mode == "fts":
        # FTS5のみ検索（既存動作と同等）
        fts_results = fts_search(conn, query, project_path, _FETCH_LIMIT)
        scored_results: list[tuple[float, SearchResult]] = []
        for _chunk_id, bm25_score, row_dict in fts_results:
            decay = time_decay(row_dict["created_at"])
            final_score = bm25_score * decay
            result = SearchResult(
                chunk_id=row_dict["id"],
                score=final_score,
                question=row_dict["question"],
                answer=row_dict["answer"],
                tool_summary=row_dict["tool_summary"],
                project_path=row_dict["project_path"],
                created_at=row_dict["created_at"],
                session_id=row_dict["session_id"],
            )
            scored_results.append((final_score, result))

        scored_results.sort(key=lambda x: x[0], reverse=True)
        return [result for _, result in scored_results[:limit]]

    elif mode == "vector":
        # ベクトル検索のみ
        try:
            vec_results = vector_search(conn, query, project_path, _FETCH_LIMIT)
        except ImportError:
            # sentence-transformers未インストール → FTSにフォールバック
            return search(conn, query, project_path, limit, mode="fts")

        scored_results = []
        for _chunk_id, sim_score, row_dict in vec_results:
            decay = time_decay(row_dict["created_at"])
            final_score = sim_score * decay
            result = SearchResult(
                chunk_id=row_dict["id"],
                score=final_score,
                question=row_dict["question"],
                answer=row_dict["answer"],
                tool_summary=row_dict["tool_summary"],
                project_path=row_dict["project_path"],
                created_at=row_dict["created_at"],
                session_id=row_dict["session_id"],
            )
            scored_results.append((final_score, result))

        scored_results.sort(key=lambda x: x[0], reverse=True)
        return [result for _, result in scored_results[:limit]]

    elif mode == "hybrid":
        # ハイブリッド検索: FTS5 + ベクトル検索をRRFで統合
        fts_results = fts_search(conn, query, project_path, _FETCH_LIMIT)

        try:
            vec_results = vector_search(conn, query, project_path, _FETCH_LIMIT)
        except ImportError:
            # sentence-transformers未インストール → FTSにフォールバック
            return search(conn, query, project_path, limit, mode="fts")

        # 行データをchunk_idで引けるようにまとめる
        row_by_id: dict[int, dict] = {}
        for chunk_id, _score, row_dict in fts_results:
            row_by_id[chunk_id] = row_dict
        for chunk_id, _score, row_dict in vec_results:
            if chunk_id not in row_by_id:
                row_by_id[chunk_id] = row_dict

        # RRF統合 + スコア正規化
        fts_ids = [r[0] for r in fts_results]
        vec_ids = [r[0] for r in vec_results]
        merged = rrf_merge(fts_ids, vec_ids)
        merged = normalize_rrf_scores(merged)

        # 正規化スコアにtime_decayを適用してSearchResultを構築
        scored_results = []
        for chunk_id, rrf_score in merged:
            row_dict = row_by_id[chunk_id]
            decay = time_decay(row_dict["created_at"])
            final_score = rrf_score * decay
            result = SearchResult(
                chunk_id=row_dict["id"],
                score=final_score,
                question=row_dict["question"],
                answer=row_dict["answer"],
                tool_summary=row_dict["tool_summary"],
                project_path=row_dict["project_path"],
                created_at=row_dict["created_at"],
                session_id=row_dict["session_id"],
            )
            scored_results.append((final_score, result))

        scored_results.sort(key=lambda x: x[0], reverse=True)
        return [result for _, result in scored_results[:limit]]

    else:
        raise ValueError(f"不正な検索モード: {mode}（fts, vector, hybridのいずれかを指定）")


def time_decay(created_at: str, half_life_days: float = 30.0) -> float:
    """作成時刻からの経過日数に基づく減衰係数を計算する。

    半減期（デフォルト30日）に基づく指数減衰を適用する。
    decay(age_days) = 0.5 ^ (age_days / half_life_days)

    Args:
        created_at: ISO8601形式のタイムスタンプ
        half_life_days: 半減期（日数）。デフォルトは30日

    Returns:
        0.0 < result <= 1.0 の減衰係数
    """
    now = datetime.now(timezone.utc)

    # ISO8601パース: タイムゾーン情報がない場合はUTCとして扱う
    try:
        created = datetime.fromisoformat(created_at)
    except ValueError:
        # パース失敗時は減衰なし（スコアに影響させない）
        return 1.0

    # naive datetimeの場合はUTCとして扱う
    if created.tzinfo is None:
        created = created.replace(tzinfo=timezone.utc)

    age_seconds: float = (now - created).total_seconds()
    # 未来の日時の場合は減衰なし
    if age_seconds < 0:
        return 1.0

    age_days: float = age_seconds / 86400.0
    return 0.5 ** (age_days / half_life_days)


def escape_fts5_query(query: str) -> str:
    """FTS5 trigramクエリ用にエスケープする。

    ダブルクォートをエスケープ（""に置換）し、全体をダブルクォートで
    囲むことでフレーズ検索（部分一致）にする。

    Args:
        query: ユーザー入力のクエリ文字列

    Returns:
        エスケープ済みのFTS5クエリ文字列

    Examples:
        >>> escape_fts5_query('hook設定')
        '"hook設定"'
        >>> escape_fts5_query('foo"bar')
        '"foo""bar"'
    """
    # ダブルクォートをエスケープ
    escaped: str = query.replace('"', '""')
    # 全体をダブルクォートで囲んでフレーズ検索にする
    return f'"{escaped}"'
