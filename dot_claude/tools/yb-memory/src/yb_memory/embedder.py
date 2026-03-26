"""sentence-transformersによるテキスト埋め込みモジュール"""

import struct
from functools import lru_cache

MODEL_NAME = "cl-nagoya/ruri-v3-70m"
EMBEDDING_DIM = 384

# Ruri v3のプレフィックススキーム
QUERY_PREFIX = "検索クエリ: "
DOCUMENT_PREFIX = "検索文書: "


@lru_cache(maxsize=1)
def _load_model():
    """モデルを遅延ロードする（初回のみ）。"""
    try:
        from sentence_transformers import SentenceTransformer
    except ImportError:
        raise ImportError(
            "sentence-transformersがインストールされていません。"
            "pip install sentence-transformers でインストールしてください。"
        )
    return SentenceTransformer(MODEL_NAME)


def encode_query(text: str) -> list[float]:
    """検索クエリをエンコードする。Ruri v3の検索クエリプレフィックスを付与。"""
    model = _load_model()
    prefixed = f"{QUERY_PREFIX}{text}"
    embedding = model.encode(prefixed, convert_to_numpy=True)
    return embedding.tolist()


def encode_document(text: str) -> list[float]:
    """検索文書をエンコードする。Ruri v3の検索文書プレフィックスを付与。"""
    model = _load_model()
    prefixed = f"{DOCUMENT_PREFIX}{text}"
    embedding = model.encode(prefixed, convert_to_numpy=True)
    return embedding.tolist()


def encode_documents_batch(texts: list[str]) -> list[list[float]]:
    """複数の検索文書をバッチエンコードする。"""
    model = _load_model()
    prefixed = [f"{DOCUMENT_PREFIX}{t}" for t in texts]
    embeddings = model.encode(prefixed, convert_to_numpy=True, show_progress_bar=False)
    return [e.tolist() for e in embeddings]


def embedding_to_bytes(embedding: list[float]) -> bytes:
    """float配列をバイト列に変換する（SQLite BLOB保存用）。"""
    return struct.pack(f"{len(embedding)}f", *embedding)


def bytes_to_embedding(data: bytes) -> list[float]:
    """バイト列をfloat配列に復元する。"""
    count = len(data) // 4  # float32 = 4 bytes
    return list(struct.unpack(f"{count}f", data))
