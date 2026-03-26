import pytest
from pathlib import Path


@pytest.fixture
def db_path(tmp_path):
    return tmp_path / "test_memories.db"


@pytest.fixture
def fixtures_dir():
    return Path(__file__).parent / "fixtures"


@pytest.fixture
def sample_session_path(fixtures_dir):
    return fixtures_dir / "sample_session.jsonl"
