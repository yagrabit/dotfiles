"""yb-memory daemonサーバーモジュール。

sentence-transformersモデルを常駐ロードし、
UNIXドメインソケット経由で検索リクエストを受け付ける。
"""

import json
import logging
import os
import signal
import socketserver
import sys
import time
from pathlib import Path

# --- 定数 ---
DATA_DIR = Path.home() / ".local" / "share" / "yb-memory"
SOCKET_PATH = DATA_DIR / "yb-memory.sock"
PID_FILE = DATA_DIR / "yb-memory.pid"

logger = logging.getLogger("yb-memory-server")


class MemoryRequestHandler(socketserver.StreamRequestHandler):
    """検索リクエストを処理するハンドラ"""

    def handle(self):
        """1リクエストを処理する"""
        try:
            line = self.rfile.readline().decode("utf-8").strip()
            if not line:
                return
            request = json.loads(line)
            response = self.server.process_request_data(request)
            self.wfile.write(
                (json.dumps(response, ensure_ascii=False) + "\n").encode("utf-8")
            )
        except Exception as e:
            error_resp = {"status": "error", "message": str(e)}
            self.wfile.write((json.dumps(error_resp) + "\n").encode("utf-8"))


class MemoryServer(socketserver.UnixStreamServer):
    """yb-memory検索サーバー

    socketserverのUnixStreamServerを使用し、
    モデルとDB接続を保持してリクエストを処理する。
    """

    allow_reuse_address = True

    def __init__(self, socket_path: str | Path = SOCKET_PATH):
        self.socket_path = Path(socket_path)
        self._model_loaded = False
        self._conn = None
        # 古いソケットファイルを削除
        if self.socket_path.exists():
            self.socket_path.unlink()
        super().__init__(str(self.socket_path), MemoryRequestHandler)

    def setup(self):
        """サーバー起動時の初期化。モデルとDB接続をロードする。"""
        from yb_memory.db import get_connection

        self._conn = get_connection()
        # モデルをプリロード（重い処理、起動時に1回だけ）
        try:
            from yb_memory.embedder import _load_model

            _load_model()
            self._model_loaded = True
            logger.info("モデルロード完了")
        except ImportError:
            logger.warning("sentence-transformersが利用不可、FTSのみで動作")
            self._model_loaded = False

    def process_request_data(self, request: dict) -> dict:
        """リクエストを処理して結果を返す。

        注意: socketserver.UnixStreamServerのprocess_request()との
        名前衝突を避けるため、process_request_dataという名前を使用する。
        """
        action = request.get("action")

        if action == "ping":
            return {
                "status": "ok",
                "message": "pong",
                "model_loaded": self._model_loaded,
            }

        elif action == "search":
            from yb_memory.searcher import search

            start = time.time()
            results = search(
                self._conn,
                query=request.get("query", ""),
                project_path=request.get("project_path"),
                limit=request.get("limit", 5),
                mode=request.get("mode", "hybrid"),
                use_daemon=False,  # サーバー内部からの呼び出し（デッドロック防止）
            )
            elapsed_ms = int((time.time() - start) * 1000)
            return {
                "status": "ok",
                "results": [
                    {
                        "chunk_id": r.chunk_id,
                        "score": r.score,
                        "question": r.question,
                        "answer": r.answer,
                        "tool_summary": r.tool_summary,
                        "project_path": r.project_path,
                        "created_at": r.created_at,
                        "session_id": r.session_id,
                    }
                    for r in results
                ],
                "elapsed_ms": elapsed_ms,
            }

        else:
            return {"status": "error", "message": f"不明なアクション: {action}"}

    def cleanup(self):
        """クリーンアップ。DB接続を閉じ、ソケットとPIDファイルを削除する。"""
        if self._conn:
            self._conn.close()
        if self.socket_path.exists():
            self.socket_path.unlink()
        if PID_FILE.exists():
            PID_FILE.unlink()


# --- PIDファイル管理 ---


def write_pid():
    """PIDファイルを書き込む"""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    PID_FILE.write_text(str(os.getpid()))


def read_pid() -> int | None:
    """PIDファイルを読む。存在しないかパース不能ならNoneを返す。"""
    try:
        return int(PID_FILE.read_text().strip())
    except (FileNotFoundError, ValueError):
        return None


def is_server_running() -> bool:
    """サーバーが起動中か確認する。

    PIDファイルを読み、該当プロセスが存在するかをシグナル0で検査する。
    プロセスが存在しない場合はPIDファイルを掃除する。
    """
    pid = read_pid()
    if pid is None:
        return False
    try:
        os.kill(pid, 0)  # シグナル0で存在確認
        return True
    except OSError:
        # プロセスが存在しない場合はPIDファイルを掃除
        if PID_FILE.exists():
            PID_FILE.unlink()
        return False


# --- サーバー起動・停止 ---


def start_server(
    socket_path: str | Path = SOCKET_PATH, daemonize: bool = False
):
    """サーバーを起動する。

    Args:
        socket_path: UNIXドメインソケットのパス
        daemonize: Trueならos.fork()でバックグラウンド化する
    """
    if is_server_running():
        print("サーバーは既に起動中です", file=sys.stderr)
        sys.exit(1)

    if daemonize:
        # バックグラウンド化（macOS対応のためos.fork()を使用）
        pid = os.fork()
        if pid > 0:
            # 親プロセス: 子のPIDを表示して終了
            print(f"yb-memory server started (PID: {pid})")
            sys.exit(0)
        # 子プロセス: セッションリーダーになる
        os.setsid()
        # stdin/stdout/stderrを/dev/nullにリダイレクト
        devnull = os.open(os.devnull, os.O_RDWR)
        os.dup2(devnull, 0)
        os.dup2(devnull, 1)
        os.dup2(devnull, 2)
        os.close(devnull)

    write_pid()
    server = MemoryServer(socket_path)

    def signal_handler(signum, frame):
        """SIGTERM/SIGINTを受けてクリーンアップする"""
        server.cleanup()
        sys.exit(0)

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    try:
        server.setup()
        if not daemonize:
            print(
                f"yb-memory server listening on {socket_path} (PID: {os.getpid()})"
            )
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.shutdown()
        server.cleanup()


def stop_server():
    """サーバーを停止する。SIGTERMを送信してプロセスを終了させる。"""
    pid = read_pid()
    if pid is None:
        print("サーバーは起動していません", file=sys.stderr)
        return False
    try:
        os.kill(pid, signal.SIGTERM)
        print(f"サーバーを停止しました (PID: {pid})")
        return True
    except OSError:
        print("サーバープロセスが見つかりません", file=sys.stderr)
        if PID_FILE.exists():
            PID_FILE.unlink()
        return False


# --- クライアント関数 ---


def send_request(
    request: dict,
    socket_path: str | Path = SOCKET_PATH,
    timeout: float = 10.0,
) -> dict | None:
    """サーバーにリクエストを送信する。

    UNIXドメインソケットに接続し、JSON行を送受信する。
    接続失敗時はNoneを返す。

    Args:
        request: 送信するリクエストdict
        socket_path: UNIXドメインソケットのパス
        timeout: ソケットタイムアウト（秒）

    Returns:
        レスポンスdict。接続失敗時はNone。
    """
    import socket as socket_module

    sock_path = str(socket_path)

    try:
        sock = socket_module.socket(socket_module.AF_UNIX, socket_module.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect(sock_path)

        data = (json.dumps(request, ensure_ascii=False) + "\n").encode("utf-8")
        sock.sendall(data)

        # レスポンスを読む
        response_data = b""
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            response_data += chunk
            if b"\n" in response_data:
                break

        sock.close()

        line = response_data.decode("utf-8").strip()
        if line:
            return json.loads(line)
        return None
    except (ConnectionRefusedError, FileNotFoundError, OSError):
        return None
