"""searcherモジュールのテスト"""

from datetime import datetime, timedelta, timezone

import pytest

from yb_memory.db import get_connection
from yb_memory.indexer import ingest_session
from yb_memory.searcher import (
    cosine_similarity,
    escape_fts5_query,
    normalize_rrf_scores,
    rrf_merge,
    search,
    time_decay,
)


class TestSearch:
    """search関数のテスト"""

    def _setup_test_data(self, conn, sample_session_path):
        """テスト用データをDBに投入するヘルパー"""
        ingest_session(conn, "test-session-001", sample_session_path)

    def test_検索で結果が返る(self, db_path, sample_session_path):
        """FTS5検索で関連する結果が返ること"""
        conn = get_connection(db_path)
        try:
            self._setup_test_data(conn, sample_session_path)

            # 「fish」で検索 → fishの設定に関するチャンクがヒットするはず
            results = search(conn, "fish", limit=10)
            assert len(results) > 0
            # 最初の結果にfishが含まれること
            assert any(
                "fish" in r.question or "fish" in r.answer
                for r in results
            )
        finally:
            conn.close()

    def test_2文字以下のクエリでFTSモードは空結果(self, db_path, sample_session_path):
        """trigramトークナイザの制約により、mode='fts'では2文字以下のクエリで空リストが返ること"""
        conn = get_connection(db_path)
        try:
            self._setup_test_data(conn, sample_session_path)

            # 2文字のクエリ（FTSモード）
            results = search(conn, "ab", mode="fts")
            assert results == []

            # 1文字のクエリ（FTSモード）
            results = search(conn, "a", mode="fts")
            assert results == []

            # 空文字のクエリ（FTSモード）
            results = search(conn, "", mode="fts")
            assert results == []

        finally:
            conn.close()

    def test_project_pathフィルタの動作(self, db_path, sample_session_path):
        """project_pathで結果をフィルタできること"""
        conn = get_connection(db_path)
        try:
            self._setup_test_data(conn, sample_session_path)

            # 正しいproject_pathでフィルタ → 結果あり
            results = search(
                conn, "fish", project_path="/Users/test/dotfiles", limit=10
            )
            assert len(results) > 0

            # 存在しないproject_pathでフィルタ → 結果なし
            results = search(
                conn, "fish", project_path="/nonexistent/path", limit=10
            )
            assert results == []
        finally:
            conn.close()


class TestTimeDecay:
    """time_decay関数のテスト"""

    def test_0日経過で1_0(self):
        """作成直後の減衰係数が1.0に近いこと"""
        now_str = datetime.now(timezone.utc).isoformat()
        decay = time_decay(now_str)
        assert decay == pytest.approx(1.0, abs=0.01)

    def test_30日経過で0_5(self):
        """半減期（30日）経過後の減衰係数が0.5に近いこと"""
        past = datetime.now(timezone.utc) - timedelta(days=30)
        decay = time_decay(past.isoformat())
        assert decay == pytest.approx(0.5, abs=0.01)

    def test_60日経過で0_25(self):
        """半減期の2倍（60日）経過後の減衰係数が0.25に近いこと"""
        past = datetime.now(timezone.utc) - timedelta(days=60)
        decay = time_decay(past.isoformat())
        assert decay == pytest.approx(0.25, abs=0.01)

    def test_未来の日時で1_0(self):
        """未来の日時の場合に減衰係数が1.0であること"""
        future = datetime.now(timezone.utc) + timedelta(days=10)
        decay = time_decay(future.isoformat())
        assert decay == 1.0

    def test_パース不能な文字列で1_0(self):
        """パースできない文字列の場合に減衰係数が1.0であること"""
        decay = time_decay("invalid-date")
        assert decay == 1.0


class TestEscapeFts5Query:
    """escape_fts5_query関数のテスト"""

    def test_通常のクエリがダブルクォートで囲まれる(self):
        """通常のクエリがダブルクォートで囲まれること"""
        result = escape_fts5_query("hook設定")
        assert result == '"hook設定"'

    def test_ダブルクォートがエスケープされる(self):
        """クエリ内のダブルクォートが二重化されること"""
        result = escape_fts5_query('foo"bar')
        assert result == '"foo""bar"'

    def test_空文字列のエスケープ(self):
        """空文字列がダブルクォートで囲まれること"""
        result = escape_fts5_query("")
        assert result == '""'

    def test_複数のダブルクォートのエスケープ(self):
        """複数のダブルクォートが全てエスケープされること"""
        result = escape_fts5_query('"a"b"')
        assert result == '"""a""b"""'


class TestCosineSimilarity:
    """cosine_similarity関数のテスト"""

    def test_同じベクトルで1_0(self):
        """同一ベクトルのコサイン類似度が1.0であること"""
        vec = [1.0, 2.0, 3.0]
        assert cosine_similarity(vec, vec) == pytest.approx(1.0)

    def test_直交ベクトルで0_0(self):
        """直交するベクトルのコサイン類似度が0.0であること"""
        a = [1.0, 0.0, 0.0]
        b = [0.0, 1.0, 0.0]
        assert cosine_similarity(a, b) == pytest.approx(0.0)

    def test_ゼロベクトルで0_0(self):
        """ゼロベクトルの場合にコサイン類似度が0.0であること"""
        zero = [0.0, 0.0, 0.0]
        vec = [1.0, 2.0, 3.0]
        assert cosine_similarity(zero, vec) == pytest.approx(0.0)
        assert cosine_similarity(vec, zero) == pytest.approx(0.0)
        assert cosine_similarity(zero, zero) == pytest.approx(0.0)

    def test_逆方向ベクトルでマイナス1_0(self):
        """逆方向のベクトルのコサイン類似度が-1.0であること"""
        a = [1.0, 0.0]
        b = [-1.0, 0.0]
        assert cosine_similarity(a, b) == pytest.approx(-1.0)

    def test_正規化済みベクトル(self):
        """正規化済みベクトルでも正しく計算されること"""
        import math
        a = [1.0 / math.sqrt(2), 1.0 / math.sqrt(2)]
        b = [1.0, 0.0]
        # cos(45°) = 1/sqrt(2) ≈ 0.7071
        assert cosine_similarity(a, b) == pytest.approx(1.0 / math.sqrt(2))


class TestRrfMerge:
    """rrf_merge関数のテスト"""

    def test_両方に含まれるIDのスコアが高い(self):
        """FTSとベクトル両方に含まれるIDのスコアが片方だけより高いこと"""
        fts_ids = [1, 2, 3]
        vec_ids = [2, 4, 1]
        merged = rrf_merge(fts_ids, vec_ids, k=60)
        scores = dict(merged)

        # id=1とid=2は両方に含まれるので高スコア
        # id=3とid=4は片方のみ
        assert scores[1] > scores[3]
        assert scores[2] > scores[4]

    def test_片方のみのIDも結果に含まれる(self):
        """FTSまたはベクトルの片方にしかないIDも結果に含まれること"""
        fts_ids = [10, 20]
        vec_ids = [30, 40]
        merged = rrf_merge(fts_ids, vec_ids, k=60)
        merged_ids = [chunk_id for chunk_id, _score in merged]

        assert 10 in merged_ids
        assert 20 in merged_ids
        assert 30 in merged_ids
        assert 40 in merged_ids

    def test_空リストの場合(self):
        """両方空リストの場合に空結果が返ること"""
        merged = rrf_merge([], [], k=60)
        assert merged == []

    def test_片方が空リストの場合(self):
        """片方が空リストでもう片方にIDがある場合"""
        merged = rrf_merge([1, 2, 3], [], k=60)
        merged_ids = [chunk_id for chunk_id, _score in merged]
        assert merged_ids == [1, 2, 3]

    def test_スコアがRRF式に従う(self):
        """スコアが1/(k+rank)の和で計算されること"""
        k = 60
        fts_ids = [1, 2]
        vec_ids = [2, 3]
        merged = rrf_merge(fts_ids, vec_ids, k=k)
        scores = dict(merged)

        # id=1: FTSのみ rank=0 → 1/(60+0) = 1/60
        assert scores[1] == pytest.approx(1.0 / (k + 0))
        # id=2: FTS rank=1 + vec rank=0 → 1/(60+1) + 1/(60+0)
        assert scores[2] == pytest.approx(1.0 / (k + 1) + 1.0 / (k + 0))
        # id=3: vecのみ rank=1 → 1/(60+1)
        assert scores[3] == pytest.approx(1.0 / (k + 1))

    def test_降順ソートされている(self):
        """結果がRRFスコアの降順でソートされていること"""
        fts_ids = [1, 2, 3]
        vec_ids = [3, 2, 1]
        merged = rrf_merge(fts_ids, vec_ids, k=60)
        scores = [score for _chunk_id, score in merged]
        assert scores == sorted(scores, reverse=True)


class TestNormalizeRrfScores:
    """normalize_rrf_scores関数のテスト"""

    def test_両方に出現するトップ結果が1_0になる(self):
        """FTSとベクトル両方のrank0に出現した結果が1.0に正規化されること"""
        k = 60
        # rank0 in both: 1/(60+0) + 1/(60+0) = 2/60
        # rank1 in fts only: 1/(60+1)
        merged = [(1, 2.0 / k), (2, 1.0 / (k + 1))]
        normalized = normalize_rrf_scores(merged, k=k)
        scores = dict(normalized)

        assert scores[1] == pytest.approx(1.0)
        assert 0.0 < scores[2] < 1.0

    def test_片方のみ出現のトップ結果が0_5になる(self):
        """片方のみのrank0に出現した結果が0.5に正規化されること"""
        k = 60
        merged = [(1, 1.0 / k)]
        normalized = normalize_rrf_scores(merged, k=k)
        scores = dict(normalized)

        assert scores[1] == pytest.approx(0.5)

    def test_空リストで空が返る(self):
        """空リストが入力された場合に空リストが返ること"""
        assert normalize_rrf_scores([], k=60) == []

    def test_順序が維持される(self):
        """正規化後も降順の順序が維持されること"""
        k = 60
        merged = [(1, 2.0 / k), (2, 1.5 / k), (3, 1.0 / k)]
        normalized = normalize_rrf_scores(merged, k=k)
        scores = [s for _, s in normalized]
        assert scores == sorted(scores, reverse=True)


class TestSearchMode:
    """search関数のmode引数のテスト"""

    def _setup_test_data(self, conn, sample_session_path):
        """テスト用データをDBに投入するヘルパー"""
        ingest_session(conn, "test-session-001", sample_session_path)

    def test_mode_ftsで既存動作が変わらない(self, db_path, sample_session_path):
        """mode='fts'で既存のFTS5検索と同等の結果が返ること"""
        conn = get_connection(db_path)
        try:
            self._setup_test_data(conn, sample_session_path)

            # mode="fts"で検索
            results = search(conn, "fish", limit=10, mode="fts")
            assert len(results) > 0
            assert any(
                "fish" in r.question or "fish" in r.answer
                for r in results
            )
        finally:
            conn.close()

    def test_mode_ftsで2文字以下は空結果(self, db_path, sample_session_path):
        """mode='fts'で2文字以下のクエリに空リストが返ること"""
        conn = get_connection(db_path)
        try:
            self._setup_test_data(conn, sample_session_path)
            results = search(conn, "ab", mode="fts")
            assert results == []
        finally:
            conn.close()

    def test_不正なmodeでValueError(self, db_path, sample_session_path):
        """不正なmode値でValueErrorが発生すること"""
        conn = get_connection(db_path)
        try:
            self._setup_test_data(conn, sample_session_path)
            with pytest.raises(ValueError, match="不正な検索モード"):
                search(conn, "fish", mode="invalid")
        finally:
            conn.close()

    def test_tool_summaryでFTS検索できる(self, db_path, sample_session_path):
        """tool_summaryに含まれるツール名でFTS5検索がヒットすること"""
        conn = get_connection(db_path)
        try:
            self._setup_test_data(conn, sample_session_path)

            # "Read"はtool_summaryに含まれるはず
            results = search(conn, "Read", mode="fts", limit=10)
            assert len(results) > 0
        finally:
            conn.close()
