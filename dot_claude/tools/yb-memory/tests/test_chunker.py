"""chunkerモジュールのテスト"""

import json
import textwrap
from pathlib import Path

import pytest

from yb_memory.chunker import (
    MAX_TOTAL_LENGTH,
    extract_assistant_text,
    extract_tool_names,
    extract_tool_use_details,
    extract_user_text,
    parse_session,
)


class TestParseSession:
    """parse_sessionの正常系テスト"""

    def test_正常にQAチャンクが生成される(self, sample_session_path):
        """サンプルセッションから期待通りのQ&Aチャンクが生成されること"""
        chunks, title = parse_session(sample_session_path)

        # u1(テキストuser) → a1+a2(assistant) がチャンク0
        # u2(tool_resultのみ) はスキップされる
        # u3(テキストuser) → a3(assistant) がチャンク1
        assert len(chunks) == 2

        # チャンク0: fishの設定についての質問
        assert "fishの設定でaliasを追加したい" in chunks[0].question
        assert "fishでaliasを設定するには" in chunks[0].answer
        assert chunks[0].session_id == "test-session-001"
        assert chunks[0].chunk_index == 0
        assert chunks[0].project_path == "/Users/test/dotfiles"

        # チャンク1: tmuxの設定についての質問
        assert "tmuxの設定" in chunks[1].question
        assert "tmuxの設定をカスタマイズしましょう" in chunks[1].answer
        assert chunks[1].chunk_index == 1

    def test_progressメッセージが除外される(self, sample_session_path):
        """progress/systemタイプのメッセージがチャンクに含まれないこと"""
        chunks, _ = parse_session(sample_session_path)

        for chunk in chunks:
            assert "サブエージェント実行中" not in chunk.question
            assert "サブエージェント実行中" not in chunk.answer
            assert "1.5s" not in chunk.question
            assert "1.5s" not in chunk.answer

    def test_thinkingブロックが除外される(self, sample_session_path):
        """assistantメッセージのthinkingブロックが応答に含まれないこと"""
        chunks, _ = parse_session(sample_session_path)

        for chunk in chunks:
            assert "考え中" not in chunk.answer

    def test_tool_useからツール名がtool_summaryに記録される(self, sample_session_path):
        """tool_useブロックのname属性がtool_summaryに記録されること"""
        chunks, _ = parse_session(sample_session_path)

        # チャンク0: a2にtool_use(Read, Edit)が含まれる
        assert chunks[0].tool_summary is not None
        assert "Read" in chunks[0].tool_summary
        assert "Edit" in chunks[0].tool_summary

        # チャンク1: a3にはtool_useがない
        assert chunks[1].tool_summary is None

    def test_ツール詳細が回答に含まれる(self, sample_session_path):
        """tool_useブロックの主要パラメータが回答テキストに含まれること"""
        chunks, _ = parse_session(sample_session_path)

        # チャンク0: Read(/etc/fish/config.fish) と Edit(/etc/fish/config.fish) が含まれる
        assert "[Read: /etc/fish/config.fish]" in chunks[0].answer
        assert "[Edit: /etc/fish/config.fish]" in chunks[0].answer

    def test_tool_resultのみのユーザーメッセージがQA区切りにならない(self, sample_session_path):
        """tool_resultのみのuserメッセージが新しいQ&Aペアの開始にならないこと"""
        chunks, _ = parse_session(sample_session_path)

        # tool_resultのみのu2がQ&A区切りにならず、2チャンクであること
        assert len(chunks) == 2

    def test_custom_titleが正しく抽出される(self, sample_session_path):
        """custom-titleタイプのレコードからタイトルが抽出されること"""
        _, title = parse_session(sample_session_path)
        assert title == "fish設定とtmux"

    def test_空のセッションで空リストが返る(self, tmp_path):
        """空のJSONLファイルを読み込んだ場合に空リストが返ること"""
        empty_file = tmp_path / "empty.jsonl"
        empty_file.write_text("")

        chunks, title = parse_session(empty_file)
        assert chunks == []
        assert title is None


class TestExtractUserText:
    """extract_user_textのテスト"""

    def test_文字列コンテンツの抽出(self):
        """contentが文字列の場合にそのまま返ること"""
        message = {"content": "テスト質問"}
        assert extract_user_text(message) == "テスト質問"

    def test_配列コンテンツからテキスト抽出(self):
        """contentが配列の場合にtype=textのテキストを結合して返すこと"""
        message = {
            "content": [
                {"type": "text", "text": "テスト1"},
                {"type": "text", "text": "テスト2"},
            ]
        }
        assert extract_user_text(message) == "テスト1\nテスト2"

    def test_tool_resultのみの場合Noneが返る(self):
        """contentがtool_resultのみの場合にNoneが返ること"""
        message = {
            "content": [
                {"type": "tool_result", "tool_use_id": "t1", "content": "OK"}
            ]
        }
        assert extract_user_text(message) is None

    def test_contentがNoneの場合(self):
        """contentフィールドがない場合にNoneが返ること"""
        message = {}
        assert extract_user_text(message) is None

    def test_空白のみの文字列はNone(self):
        """contentが空白のみの場合にNoneが返ること"""
        message = {"content": "   "}
        assert extract_user_text(message) is None


class TestExtractAssistantText:
    """extract_assistant_textのテスト"""

    def test_テキストブロックの抽出(self):
        """type=textのブロックからテキストが抽出されること"""
        message = {
            "content": [
                {"type": "text", "text": "応答テキスト"},
            ]
        }
        assert extract_assistant_text(message) == "応答テキスト"

    def test_thinkingブロックが除外される(self):
        """type=thinkingのブロックが結果に含まれないこと"""
        message = {
            "content": [
                {"type": "thinking", "thinking": "考え中..."},
                {"type": "text", "text": "応答テキスト"},
            ]
        }
        result = extract_assistant_text(message)
        assert "考え中" not in result
        assert "応答テキスト" in result

    def test_contentがリストでない場合は空文字(self):
        """contentがリスト以外の場合に空文字が返ること"""
        message = {"content": "文字列"}
        assert extract_assistant_text(message) == ""


class TestExtractToolNames:
    """extract_tool_namesのテスト"""

    def test_tool_use名の抽出(self):
        """tool_useブロックからツール名が抽出されること"""
        message = {
            "content": [
                {"type": "tool_use", "id": "t1", "name": "Read", "input": {}},
                {"type": "tool_use", "id": "t2", "name": "Edit", "input": {}},
                {"type": "text", "text": "テキスト"},
            ]
        }
        names = extract_tool_names(message)
        assert names == ["Read", "Edit"]

    def test_tool_useがない場合は空リスト(self):
        """tool_useブロックがない場合に空リストが返ること"""
        message = {
            "content": [
                {"type": "text", "text": "テキスト"},
            ]
        }
        assert extract_tool_names(message) == []

    def test_contentがリストでない場合は空リスト(self):
        """contentがリスト以外の場合に空リストが返ること"""
        message = {"content": "文字列"}
        assert extract_tool_names(message) == []


class TestExtractToolUseDetails:
    """extract_tool_use_detailsのテスト"""

    def test_Read_tool_からファイルパスが抽出される(self):
        """Readツールのfile_pathが[Read: パス]形式で抽出されること"""
        message = {
            "content": [
                {"type": "tool_use", "id": "t1", "name": "Read",
                 "input": {"file_path": "/path/to/file.ts"}},
            ]
        }
        details = extract_tool_use_details(message)
        assert details == ["[Read: /path/to/file.ts]"]

    def test_Bash_toolからコマンドが抽出される(self):
        """Bashツールのcommandが[Bash: コマンド]形式で抽出されること"""
        message = {
            "content": [
                {"type": "tool_use", "id": "t1", "name": "Bash",
                 "input": {"command": "npm test"}},
            ]
        }
        details = extract_tool_use_details(message)
        assert details == ["[Bash: npm test]"]

    def test_未知のツールでも最初のstring入力が抽出される(self):
        """未知のツールでも最初のstring型入力パラメータが抽出されること"""
        message = {
            "content": [
                {"type": "tool_use", "id": "t1", "name": "mcp__getPage",
                 "input": {"pageId": "12345", "spaceKey": "DEV"}},
            ]
        }
        details = extract_tool_use_details(message)
        assert len(details) == 1
        assert "mcp__getPage" in details[0]
        assert "pageId=12345" in details[0]

    def test_入力パラメータがない場合はツール名のみ(self):
        """入力パラメータがない場合に[ツール名]のみが返ること"""
        message = {
            "content": [
                {"type": "tool_use", "id": "t1", "name": "SomeTool",
                 "input": {}},
            ]
        }
        details = extract_tool_use_details(message)
        assert details == ["[SomeTool]"]

    def test_長い入力パラメータが切り詰められる(self):
        """100文字を超える入力パラメータが切り詰められること"""
        long_path = "/very/long/" + "a" * 200 + "/path.ts"
        message = {
            "content": [
                {"type": "tool_use", "id": "t1", "name": "Read",
                 "input": {"file_path": long_path}},
            ]
        }
        details = extract_tool_use_details(message)
        assert len(details) == 1
        # 100文字 + [Read: ] + ] の分
        assert len(details[0]) <= 120

    def test_複数のtool_useが全て抽出される(self):
        """複数のtool_useブロックから全てのツール詳細が抽出されること"""
        message = {
            "content": [
                {"type": "tool_use", "id": "t1", "name": "Read",
                 "input": {"file_path": "/a.ts"}},
                {"type": "text", "text": "テキスト"},
                {"type": "tool_use", "id": "t2", "name": "Bash",
                 "input": {"command": "npm test"}},
            ]
        }
        details = extract_tool_use_details(message)
        assert len(details) == 2
        assert "[Read: /a.ts]" in details
        assert "[Bash: npm test]" in details

    def test_contentがリストでない場合は空リスト(self):
        """contentがリスト以外の場合に空リストが返ること"""
        message = {"content": "文字列"}
        assert extract_tool_use_details(message) == []


class TestMaxTotalLength:
    """MAX_TOTAL_LENGTHの設定値テスト"""

    def test_上限が16000に拡大されている(self):
        """Q+A合計の文字数上限が16000であること"""
        assert MAX_TOTAL_LENGTH == 16_000
