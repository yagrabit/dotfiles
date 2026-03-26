"""indexerモジュールのテスト"""

import json
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

from yb_memory.db import get_connection, is_session_ingested
from yb_memory.indexer import find_session_file, ingest_session


class TestIngestSession:
    """ingest_sessionのテスト"""

    def test_チャンクが保存される(self, db_path, sample_session_path):
        """セッションを取り込むとチャンクがDBに保存されること"""
        conn = get_connection(db_path)
        try:
            count = ingest_session(conn, "test-session-001", sample_session_path)

            # チャンクが2つ生成されること（u1→a1+a2, u3→a3）
            assert count == 2

            # sessionsテーブルに記録されていること
            session = conn.execute(
                "SELECT * FROM sessions WHERE session_id = ?",
                ("test-session-001",),
            ).fetchone()
            assert session is not None
            assert session["project_path"] == "/Users/test/dotfiles"
            assert session["chunk_count"] == 2
            assert session["title"] == "fish設定とtmux"

            # chunksテーブルにデータがあること
            chunks = conn.execute(
                "SELECT * FROM chunks WHERE session_id = ? ORDER BY chunk_index",
                ("test-session-001",),
            ).fetchall()
            assert len(chunks) == 2
            assert "fish" in chunks[0]["question"]
            assert "tmux" in chunks[1]["question"]
        finally:
            conn.close()

    def test_同じセッションの再取り込みがスキップされる(self, db_path, sample_session_path):
        """既に取り込み済みのセッションを再度取り込もうとした場合に0が返ること"""
        conn = get_connection(db_path)
        try:
            # 1回目の取り込み
            count1 = ingest_session(conn, "test-session-001", sample_session_path)
            assert count1 == 2

            # 2回目の取り込み（冪等性）
            count2 = ingest_session(conn, "test-session-001", sample_session_path)
            assert count2 == 0

            # チャンク数が増えていないこと
            total_chunks = conn.execute(
                "SELECT COUNT(*) FROM chunks WHERE session_id = ?",
                ("test-session-001",),
            ).fetchone()[0]
            assert total_chunks == 2
        finally:
            conn.close()


class TestFindSessionFile:
    """find_session_fileのテスト"""

    def test_存在するセッションファイルが見つかる(self, tmp_path, monkeypatch):
        """テスト用ディレクトリにダミーファイルを作成して検索できること"""
        # ダミーのプロジェクトディレクトリ構造を作成
        projects_dir = tmp_path / "projects"
        project_dir = projects_dir / "test-project"
        project_dir.mkdir(parents=True)

        # ダミーJSONLファイルを作成
        dummy_session = project_dir / "abc-123.jsonl"
        dummy_session.write_text("{}")

        # CLAUDE_PROJECTS_DIRをモンキーパッチ
        import yb_memory.indexer as indexer_module
        monkeypatch.setattr(indexer_module, "CLAUDE_PROJECTS_DIR", projects_dir)

        result = find_session_file("abc-123")
        assert result is not None
        assert result.name == "abc-123.jsonl"

    def test_存在しないセッションファイルはNone(self, tmp_path, monkeypatch):
        """存在しないセッションIDで検索した場合にNoneが返ること"""
        projects_dir = tmp_path / "projects"
        projects_dir.mkdir(parents=True)

        import yb_memory.indexer as indexer_module
        monkeypatch.setattr(indexer_module, "CLAUDE_PROJECTS_DIR", projects_dir)

        result = find_session_file("nonexistent-session")
        assert result is None

    def test_プロジェクトディレクトリが存在しない場合None(self, tmp_path, monkeypatch):
        """CLAUDE_PROJECTS_DIRが存在しない場合にNoneが返ること"""
        nonexistent = tmp_path / "nonexistent"

        import yb_memory.indexer as indexer_module
        monkeypatch.setattr(indexer_module, "CLAUDE_PROJECTS_DIR", nonexistent)

        result = find_session_file("any-session")
        assert result is None


class TestIngestSessionEmbedding:
    """ingest_sessionのembedding関連テスト"""

    def test_chunks_vecテーブルが存在する(self, db_path, sample_session_path):
        """ingest後にchunks_vecテーブルがスキーマに含まれていること"""
        conn = get_connection(db_path)
        try:
            ingest_session(conn, "test-session-001", sample_session_path)

            # chunks_vecテーブルの存在確認
            table = conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks_vec'"
            ).fetchone()
            assert table is not None
        finally:
            conn.close()

    def test_sentence_transformers未インストールでもエラーにならない(
        self, db_path, sample_session_path
    ):
        """sentence-transformersがない環境でもingest_sessionがgraceful degradationすること"""
        conn = get_connection(db_path)
        try:
            # has_vector_supportがFalseを返す＝embedding計算をスキップ
            with patch("yb_memory.db.has_vector_support", return_value=False):
                count = ingest_session(conn, "test-session-001", sample_session_path)

            # チャンクは正常に保存される
            assert count == 2

            # chunksテーブルにデータがある
            chunk_count = conn.execute(
                "SELECT COUNT(*) FROM chunks WHERE session_id = ?",
                ("test-session-001",),
            ).fetchone()[0]
            assert chunk_count == 2
        finally:
            conn.close()

    def test_ベクトルサポート有効時にchunks_vecにデータが保存される(
        self, db_path, sample_session_path
    ):
        """has_vector_supportがTrueの場合、encode_documents_batchが呼ばれchunks_vecに保存されること"""
        conn = get_connection(db_path)
        try:
            # ダミーのembeddingを返すモック
            dummy_embeddings = [[0.1] * 384, [0.2] * 384]

            with patch(
                "yb_memory.db.has_vector_support", return_value=True
            ), patch(
                "yb_memory.embedder.encode_documents_batch",
                return_value=dummy_embeddings,
            ) as mock_encode, patch(
                "yb_memory.embedder.embedding_to_bytes",
                side_effect=lambda emb: b"\x00" * (384 * 4),
            ):
                count = ingest_session(conn, "test-session-001", sample_session_path)

            assert count == 2

            # encode_documents_batchが呼ばれていること
            mock_encode.assert_called_once()
            # 引数のテキスト数がチャンク数と一致すること
            call_args = mock_encode.call_args[0][0]
            assert len(call_args) == 2

            # chunks_vecにデータが保存されていること
            vec_count = conn.execute(
                "SELECT COUNT(*) FROM chunks_vec"
            ).fetchone()[0]
            assert vec_count == 2
        finally:
            conn.close()
