"""embedder.pyのテスト"""

import struct
import pytest
from yb_memory.embedder import (
    embedding_to_bytes,
    bytes_to_embedding,
    EMBEDDING_DIM,
    QUERY_PREFIX,
    DOCUMENT_PREFIX,
)


class TestEmbeddingConversion:
    """embedding <-> bytes 変換のテスト"""

    def test_float配列からバイト列への変換(self):
        embedding = [0.1, 0.2, 0.3]
        data = embedding_to_bytes(embedding)
        assert isinstance(data, bytes)
        assert len(data) == 3 * 4  # float32 = 4 bytes

    def test_バイト列からfloat配列への復元(self):
        original = [0.1, 0.2, 0.3]
        data = embedding_to_bytes(original)
        restored = bytes_to_embedding(data)
        assert len(restored) == len(original)
        for o, r in zip(original, restored):
            assert abs(o - r) < 1e-6

    def test_384次元のラウンドトリップ(self):
        original = [float(i) / EMBEDDING_DIM for i in range(EMBEDDING_DIM)]
        data = embedding_to_bytes(original)
        assert len(data) == EMBEDDING_DIM * 4
        restored = bytes_to_embedding(data)
        assert len(restored) == EMBEDDING_DIM
        for o, r in zip(original, restored):
            assert abs(o - r) < 1e-6

    def test_空配列の変換(self):
        data = embedding_to_bytes([])
        assert data == b""
        restored = bytes_to_embedding(data)
        assert restored == []


class TestConstants:
    """定数のテスト"""

    def test_embedding次元数(self):
        assert EMBEDDING_DIM == 384

    def test_クエリプレフィックス(self):
        assert QUERY_PREFIX == "検索クエリ: "

    def test_ドキュメントプレフィックス(self):
        assert DOCUMENT_PREFIX == "検索文書: "


# 注意: encode_query/encode_document/encode_documents_batchのテストは
# sentence-transformersのインストールとモデルダウンロードが必要なためここでは省略。
# E2E検証（T7）で確認する。
