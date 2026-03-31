"""Claude CodeのJSONLセッションログをパースし、Q&Aペアにチャンク化するモジュール。

JSONLの各行を読み込み、user/assistantメッセージのみを抽出して
Q(ユーザー発話)とA(アシスタント応答)のペアに分割する。
"""

import json
import logging
from pathlib import Path

from yb_memory.models import Chunk

logger = logging.getLogger(__name__)

# チャンクサイズ制限
MAX_QUESTION_LENGTH: int = 2_000
MAX_TOTAL_LENGTH: int = 16_000
TRUNCATION_MARKER: str = "[truncated]"

# メインチェーンから除外するメッセージタイプ
_EXCLUDED_TYPES: frozenset[str] = frozenset(
    {
        "progress",
        "file-history-snapshot",
        "system",
        "last-prompt",
        "custom-title",
        "agent-name",
    }
)


def extract_user_text(message: dict) -> str | None:
    """ユーザーメッセージからテキストを抽出する。

    content が文字列の場合はそのまま返す。
    content が配列の場合は type="text" の text フィールドを結合して返す。
    tool_result のみの場合は None を返す。

    Args:
        message: メッセージ辞書（message.content を含む）

    Returns:
        抽出されたテキスト。テキストが存在しない場合は None。
    """
    content = message.get("content")
    if content is None:
        return None

    # content が文字列の場合
    if isinstance(content, str):
        return content if content.strip() else None

    # content が配列の場合
    if isinstance(content, list):
        texts: list[str] = []
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "text":
                text = block.get("text", "")
                if text.strip():
                    texts.append(text)
        return "\n".join(texts) if texts else None

    return None


def extract_assistant_text(message: dict) -> str:
    """アシスタントメッセージからテキスト部分のみを抽出する。

    content 配列の type="text" の text フィールドを結合して返す。
    type="thinking" は除外する。

    Args:
        message: メッセージ辞書（message.content を含む）

    Returns:
        抽出されたテキスト。テキストが無い場合は空文字列。
    """
    content = message.get("content")
    if not isinstance(content, list):
        return ""

    texts: list[str] = []
    for block in content:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "text":
            text = block.get("text", "")
            if text.strip():
                texts.append(text)

    return "\n".join(texts)


def extract_tool_names(message: dict) -> list[str]:
    """アシスタントメッセージからtool_use名を抽出する。

    Args:
        message: メッセージ辞書（message.content を含む）

    Returns:
        ツール名のリスト。ツール使用が無い場合は空リスト。
    """
    content = message.get("content")
    if not isinstance(content, list):
        return []

    names: list[str] = []
    for block in content:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "tool_use":
            name = block.get("name")
            if name:
                names.append(name)

    return names


# 主要ツールの代表的な入力パラメータ名
_TOOL_INPUT_KEYS: dict[str, str] = {
    "Read": "file_path",
    "Edit": "file_path",
    "Write": "file_path",
    "Bash": "command",
    "Grep": "pattern",
    "Glob": "pattern",
    "Agent": "description",
    "WebSearch": "query",
    "WebFetch": "url",
}


def extract_tool_use_details(message: dict) -> list[str]:
    """アシスタントメッセージからtool_use名と主要パラメータを抽出する。

    既知のツールは代表的な入力パラメータ（file_path, command等）を、
    未知のツールは最初のstring型パラメータを含めて返す。

    Args:
        message: メッセージ辞書（message.content を含む）

    Returns:
        "[ツール名: パラメータ値]" 形式の文字列リスト。
    """
    content = message.get("content")
    if not isinstance(content, list):
        return []

    details: list[str] = []
    for block in content:
        if not isinstance(block, dict) or block.get("type") != "tool_use":
            continue
        name = block.get("name", "")
        if not name:
            continue
        input_data = block.get("input", {})

        # 既知のツールは代表パラメータを取得
        key = _TOOL_INPUT_KEYS.get(name)
        if key and key in input_data:
            value = str(input_data[key])[:100]
            details.append(f"[{name}: {value}]")
        else:
            # 未知のツール: 最初のstring型入力を使用
            found = False
            for k, v in input_data.items():
                if isinstance(v, str) and v.strip():
                    details.append(f"[{name}: {k}={str(v)[:80]}]")
                    found = True
                    break
            if not found:
                details.append(f"[{name}]")

    return details


def _truncate(text: str, max_length: int) -> str:
    """テキストを指定文字数で切り詰める。

    切り詰めた場合は末尾に TRUNCATION_MARKER を付加する。

    Args:
        text: 対象テキスト
        max_length: 最大文字数

    Returns:
        切り詰め後のテキスト。
    """
    if len(text) <= max_length:
        return text
    return text[: max_length - len(TRUNCATION_MARKER)] + TRUNCATION_MARKER


def parse_session(jsonl_path: Path) -> tuple[list[Chunk], str | None]:
    """セッションJSONLファイルをパースしてQ&Aチャンクのリストとセッションタイトルを返す。

    処理フロー:
    1. 全行をパースし user/assistant メッセージのみ抽出
    2. isSidechain == true のメッセージを除外
    3. timestamp でソート
    4. Q&Aペアを構築
    5. サイズ制限を適用

    Args:
        jsonl_path: セッションJSONLファイルのパス

    Returns:
        (chunks, title): チャンクのリストとセッションタイトル（あれば）
    """
    # 全行をパース
    records: list[dict] = []
    session_title: str | None = None
    session_id: str = ""
    project_path: str = ""
    first_record_processed: bool = False

    with jsonl_path.open("r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as e:
                logger.warning(
                    "JSONパースエラー（%s 行%d）: %s", jsonl_path.name, line_num, e
                )
                continue

            # セッション情報を取得（sessionIdが含まれる最初のレコードから）
            if not first_record_processed:
                sid = record.get("sessionId", "")
                if sid:
                    session_id = sid
                    project_path = record.get("cwd", "")
                    first_record_processed = True
                elif record.get("cwd"):
                    # sessionIdがなくてもcwdがあれば記録しておく
                    project_path = record.get("cwd", "")

            # セッションタイトルを抽出
            record_type = record.get("type", "")
            if record_type == "custom-title":
                session_title = record.get("title")
                continue

            # 除外対象のメッセージタイプをスキップ
            if record_type in _EXCLUDED_TYPES:
                continue

            # user/assistant 以外をスキップ
            if record_type not in ("user", "assistant"):
                continue

            # サイドチェーンのメッセージを除外
            if record.get("isSidechain") is True:
                continue

            records.append(record)

    # タイムスタンプでソート
    records.sort(key=lambda r: r.get("timestamp", ""))

    # 最初のuserメッセージのタイムスタンプを created_at として使用
    created_at: str = ""
    for record in records:
        if record.get("type") == "user":
            created_at = record.get("timestamp", "")
            break

    # Q&Aペアを構築
    chunks: list[Chunk] = []
    current_question: str | None = None
    current_answer_parts: list[str] = []
    current_tool_names: list[str] = []
    current_tool_details: list[str] = []

    def _finalize_chunk() -> None:
        """蓄積されたQ&Aデータからチャンクを確定してリストに追加する。"""
        nonlocal current_question, current_answer_parts, current_tool_names
        nonlocal current_tool_details

        if current_question is None:
            return

        answer = "\n".join(current_answer_parts).strip()
        question = current_question.strip()

        # ツール詳細を回答末尾に追加（「何をやったか」の記録）
        if current_tool_details:
            details_text = " ".join(current_tool_details)
            if answer:
                answer = f"{answer}\n{details_text}"
            else:
                answer = details_text

        # 空のチャンクは生成しない
        if not question and not answer:
            current_question = None
            current_answer_parts = []
            current_tool_names = []
            return

        # Qの切り詰め
        question = _truncate(question, MAX_QUESTION_LENGTH)

        # Q+A合計の切り詰め
        total_length = len(question) + len(answer)
        if total_length > MAX_TOTAL_LENGTH:
            max_answer_length = MAX_TOTAL_LENGTH - len(question)
            answer = _truncate(answer, max_answer_length)

        # ツールサマリーの生成
        tool_summary: str | None = None
        if current_tool_names:
            # 重複を除去しつつ順序を維持
            seen: set[str] = set()
            unique_names: list[str] = []
            for name in current_tool_names:
                if name not in seen:
                    seen.add(name)
                    unique_names.append(name)
            tool_summary = ", ".join(unique_names)

        chunk = Chunk(
            session_id=session_id,
            chunk_index=len(chunks),
            question=question,
            answer=answer,
            tool_summary=tool_summary,
            created_at=created_at,
            project_path=project_path,
        )
        chunks.append(chunk)

        # 状態をリセット
        current_question = None
        current_answer_parts = []
        current_tool_names = []
        current_tool_details = []

    for record in records:
        record_type = record.get("type", "")
        message = record.get("message", {})

        if record_type == "user":
            user_text = extract_user_text(message)
            if user_text is None:
                # tool_result のみのメッセージはスキップ
                continue

            # 新しいQが来たら、前のチャンクを確定
            _finalize_chunk()
            current_question = user_text

        elif record_type == "assistant":
            assistant_text = extract_assistant_text(message)
            if assistant_text:
                current_answer_parts.append(assistant_text)

            tool_names = extract_tool_names(message)
            current_tool_names.extend(tool_names)

            tool_details = extract_tool_use_details(message)
            current_tool_details.extend(tool_details)

    # 最後のチャンクを確定
    _finalize_chunk()

    return chunks, session_title
