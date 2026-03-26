"""データクラス定義"""

from dataclasses import dataclass


@dataclass
class Chunk:
    """Q&Aチャンク: ユーザー発話(Q)とアシスタント応答(A)のペア"""

    session_id: str
    chunk_index: int
    question: str
    answer: str
    tool_summary: str | None
    created_at: str  # ISO8601タイムスタンプ
    project_path: str


@dataclass
class SearchResult:
    """検索結果"""

    chunk_id: int
    score: float
    question: str
    answer: str
    tool_summary: str | None
    project_path: str
    created_at: str
    session_id: str


@dataclass
class SessionInfo:
    """セッション情報"""

    session_id: str
    project_path: str
    started_at: str | None
    title: str | None
    chunk_count: int
