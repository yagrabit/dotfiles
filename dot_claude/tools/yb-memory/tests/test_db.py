"""dbモジュールのテスト"""

import sqlite3

import pytest

from yb_memory.db import (
    SCHEMA_VERSION,
    get_connection,
    get_stats,
    has_vector_support,
    init_schema,
    is_session_ingested,
)


class TestGetConnection:
    """get_connectionのテスト"""

    def test_スキーマが正しく作成される(self, db_path):
        """DB接続時にスキーマが自動作成されること"""
        conn = get_connection(db_path)
        try:
            # sessionsテーブルが存在すること
            tables = conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
            ).fetchall()
            table_names = [row["name"] for row in tables]

            assert "sessions" in table_names
            assert "chunks" in table_names
            assert "chunks_fts" in table_names
            assert "schema_version" in table_names

            # スキーマバージョンが記録されていること
            version = conn.execute(
                "SELECT version FROM schema_version"
            ).fetchone()
            assert version["version"] == 2
        finally:
            conn.close()

    def test_WALモードが有効(self, db_path):
        """WALモードが設定されていること"""
        conn = get_connection(db_path)
        try:
            journal_mode = conn.execute("PRAGMA journal_mode").fetchone()[0]
            assert journal_mode == "wal"
        finally:
            conn.close()


class TestInitSchema:
    """init_schemaのテスト"""

    def test_冪等性_2回呼んでもエラーにならない(self, db_path):
        """init_schemaを2回呼んでもエラーが発生しないこと"""
        conn = get_connection(db_path)
        try:
            # 2回目のinit_schemaがエラーを起こさない
            init_schema(conn)

            # スキーマバージョンが重複していない
            versions = conn.execute(
                "SELECT version FROM schema_version"
            ).fetchall()
            assert len(versions) == 1
            assert versions[0]["version"] == 2
        finally:
            conn.close()


class TestIsSessionIngested:
    """is_session_ingestedのテスト"""

    def test_未取り込みセッションはFalse(self, db_path):
        """存在しないセッションIDに対してFalseが返ること"""
        conn = get_connection(db_path)
        try:
            assert is_session_ingested(conn, "nonexistent-session") is False
        finally:
            conn.close()

    def test_取り込み済みセッションはTrue(self, db_path):
        """sessionsテーブルに存在するセッションIDに対してTrueが返ること"""
        conn = get_connection(db_path)
        try:
            conn.execute(
                "INSERT INTO sessions (session_id, project_path, chunk_count) VALUES (?, ?, ?)",
                ("test-session", "/test/path", 0),
            )
            conn.commit()

            assert is_session_ingested(conn, "test-session") is True
        finally:
            conn.close()


class TestGetStats:
    """get_statsのテスト"""

    def test_空DBの統計情報(self, db_path):
        """空のDBで統計情報が正しく返ること"""
        conn = get_connection(db_path)
        try:
            stats = get_stats(conn)

            assert stats["session_count"] == 0
            assert stats["chunk_count"] == 0
            assert stats["schema_version"] == 2
            assert isinstance(stats["db_size_bytes"], int)
            assert stats["db_size_bytes"] >= 0
        finally:
            conn.close()

    def test_データ挿入後の統計情報(self, db_path):
        """データ挿入後に統計情報が正しく更新されること"""
        conn = get_connection(db_path)
        try:
            # セッションとチャンクを挿入
            conn.execute(
                "INSERT INTO sessions (session_id, project_path, chunk_count) VALUES (?, ?, ?)",
                ("s1", "/test", 1),
            )
            conn.execute(
                """INSERT INTO chunks
                   (session_id, chunk_index, question, answer, created_at, project_path)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                ("s1", 0, "質問", "回答", "2026-03-20T10:00:00Z", "/test"),
            )
            conn.commit()

            stats = get_stats(conn)
            assert stats["session_count"] == 1
            assert stats["chunk_count"] == 1
        finally:
            conn.close()


class TestSchemaV2:
    """スキーマv2（ベクトル関連）のテスト"""

    def test_SCHEMA_VERSIONが2である(self):
        """SCHEMA_VERSION定数が2であること"""
        assert SCHEMA_VERSION == 2

    def test_chunks_vecテーブルが存在する(self, db_path):
        """chunks_vecテーブルがスキーマ作成時に生成されること"""
        conn = get_connection(db_path)
        try:
            tables = conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
            ).fetchall()
            table_names = [row["name"] for row in tables]
            assert "chunks_vec" in table_names
        finally:
            conn.close()

    def test_has_vector_supportの動作確認(self, db_path):
        """has_vector_supportがboolを返すこと"""
        conn = get_connection(db_path)
        try:
            result = has_vector_support(conn)
            assert isinstance(result, bool)
        finally:
            conn.close()

    def test_chunks削除時にchunks_vecも削除される(self, db_path):
        """chunksレコード削除時にchunks_vecの対応行も連動削除されること"""
        conn = get_connection(db_path)
        try:
            # セッションとチャンクを挿入
            conn.execute(
                "INSERT INTO sessions (session_id, project_path, chunk_count) VALUES (?, ?, ?)",
                ("s1", "/test", 1),
            )
            conn.execute(
                """INSERT INTO chunks
                   (session_id, chunk_index, question, answer, created_at, project_path)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                ("s1", 0, "質問", "回答", "2026-03-20T10:00:00Z", "/test"),
            )
            # チャンクのIDを取得
            chunk_id = conn.execute("SELECT id FROM chunks WHERE session_id = 's1'").fetchone()[0]

            # chunks_vecにダミーのembeddingを挿入
            conn.execute(
                "INSERT INTO chunks_vec (id, embedding) VALUES (?, ?)",
                (chunk_id, b"\x00" * 16),
            )
            conn.commit()

            # chunks_vecにレコードが存在することを確認
            vec_count = conn.execute(
                "SELECT COUNT(*) FROM chunks_vec WHERE id = ?", (chunk_id,)
            ).fetchone()[0]
            assert vec_count == 1

            # chunksからレコードを削除（外部キー制約のためセッションは残す）
            conn.execute("PRAGMA foreign_keys=OFF")
            conn.execute("DELETE FROM chunks WHERE id = ?", (chunk_id,))
            conn.commit()

            # chunks_vecからも連動削除されていること
            vec_count_after = conn.execute(
                "SELECT COUNT(*) FROM chunks_vec WHERE id = ?", (chunk_id,)
            ).fetchone()[0]
            assert vec_count_after == 0
        finally:
            conn.close()
