"""argparseベースのCLIエントリポイント。

yb-memoryコマンドのサブコマンド（ingest, search, status, reindex, serve, stop, ping, gc）を定義し、
各モジュールへのディスパッチを行う。
"""

import argparse
import json
import os
import sys
import time
from dataclasses import asdict

from yb_memory.db import DEFAULT_DB_PATH, get_connection, get_stats
from yb_memory.indexer import (
    find_all_sessions,
    find_session_file,
    find_sessions_since,
    ingest_all,
    ingest_session,
    ingest_since,
    reindex_embeddings,
)
from yb_memory.searcher import search


def _truncate(text: str, max_length: int = 200) -> str:
    """テキストを指定文字数で切り詰める。

    Args:
        text: 対象テキスト
        max_length: 最大文字数

    Returns:
        切り詰めたテキスト。max_lengthを超える場合は "..." を付加
    """
    if len(text) <= max_length:
        return text
    return text[:max_length] + "..."


def _format_size(size_bytes: int) -> str:
    """バイト数を人間が読みやすい形式に変換する。

    Args:
        size_bytes: バイト数

    Returns:
        "1.2 MB" のような文字列
    """
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.1f} GB"


def _shorten_project_path(project_path: str, max_length: int = 50) -> str:
    """プロジェクトパスを短縮表示する。

    長いパスの場合は末尾のディレクトリ名のみ表示する。

    Args:
        project_path: プロジェクトパス
        max_length: これを超える場合は短縮する

    Returns:
        短縮されたパス文字列
    """
    if len(project_path) <= max_length:
        return project_path
    return os.path.basename(project_path.rstrip("/"))


def _cmd_ingest(args: argparse.Namespace) -> None:
    """ingestサブコマンドの実行。

    --session-id, --all, --since のいずれかで取り込み対象を指定する。
    引数なしの場合はエラーメッセージを表示する。
    """
    # 引数の排他チェック
    if not args.session_id and not args.all and not args.since:
        print(
            "エラー: --session-id, --all, --since のいずれかを指定してください。",
            file=sys.stderr,
        )
        sys.exit(1)

    conn = get_connection()
    try:
        if args.session_id:
            # 特定セッションの取り込み
            if args.dry_run:
                # dry_run: 対象セッションの情報を表示
                jsonl_path = find_session_file(args.session_id)
                if jsonl_path is None:
                    print(
                        f"エラー: セッションが見つかりません: {args.session_id}",
                        file=sys.stderr,
                    )
                    sys.exit(1)
                print("[dry-run] 取り込み対象:")
                print(f"  {args.session_id} {jsonl_path}")
                print(f"合計: 1件")
            else:
                jsonl_path = find_session_file(args.session_id)
                if jsonl_path is None:
                    print(
                        f"エラー: セッションが見つかりません: {args.session_id}",
                        file=sys.stderr,
                    )
                    sys.exit(1)
                count = ingest_session(conn, args.session_id, jsonl_path)
                if count > 0:
                    print("取り込み完了:")
                    print(f"  対象: 1件")
                    print(f"  取り込み: 1件")
                    print(f"  スキップ（既存）: 0件")
                    print(f"  エラー: 0件")
                else:
                    print("取り込み完了:")
                    print(f"  対象: 1件")
                    print(f"  取り込み: 0件")
                    print(f"  スキップ（既存）: 1件")
                    print(f"  エラー: 0件")

        elif args.all:
            # 全セッションの取り込み
            if args.dry_run:
                sessions = find_all_sessions()
                print("[dry-run] 取り込み対象:")
                for session_id, jsonl_path in sessions:
                    print(f"  {session_id} {jsonl_path}")
                print(f"合計: {len(sessions)}件")
            else:
                result = ingest_all(conn, dry_run=False)
                _print_ingest_result(result)

        elif args.since:
            # 指定日以降のセッションの取り込み
            if args.dry_run:
                sessions = find_sessions_since(args.since)
                print("[dry-run] 取り込み対象:")
                for session_id, jsonl_path in sessions:
                    print(f"  {session_id} {jsonl_path}")
                print(f"合計: {len(sessions)}件")
            else:
                result = ingest_since(conn, args.since, dry_run=False)
                _print_ingest_result(result)

    except Exception as e:
        print(f"エラー: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        conn.close()


def _print_ingest_result(result: dict) -> None:
    """ingestの結果を表示する。

    Args:
        result: {"total": N, "ingested": N, "skipped": N, "errors": N}
    """
    print("取り込み完了:")
    print(f"  対象: {result['total']}件")
    print(f"  取り込み: {result['ingested']}件")
    print(f"  スキップ（既存）: {result['skipped']}件")
    print(f"  エラー: {result['errors']}件")


def _cmd_search(args: argparse.Namespace) -> None:
    """searchサブコマンドの実行。

    クエリ文字列でFTS5検索を行い、結果を表示する。
    --projectが未指定で--all-projectsもない場合はカレントディレクトリを使用する。
    """
    # project_pathの決定
    project_path: str | None = None
    if args.all_projects:
        project_path = None
    elif args.project:
        project_path = args.project
    else:
        # カレントディレクトリをproject_pathとして使用
        project_path = os.getcwd()

    conn = get_connection()
    try:
        start_time: float = time.time()
        results = search(
            conn,
            args.query,
            project_path=project_path,
            limit=args.limit,
            mode=args.mode,
        )
        elapsed: float = time.time() - start_time

        if args.json:
            # JSON形式で出力
            json_output = [asdict(r) for r in results]
            print(json.dumps(json_output, ensure_ascii=False, indent=2))
        else:
            # 人間向け形式で出力
            if not results:
                print("検索結果が見つかりませんでした。")
                print(f"\n検索結果: 0件（{elapsed:.2f}秒）")
                return

            for i, r in enumerate(results, 1):
                # 日付部分のみ抽出（ISO8601から日付部分を取得）
                date_str = r.created_at[:10] if len(r.created_at) >= 10 else r.created_at
                display_path = _shorten_project_path(r.project_path)

                print(f"[{i}] (score: {r.score:.2f}, {date_str}) {display_path}")
                print(f"  Q: {_truncate(r.question)}")
                print(f"  A: {_truncate(r.answer)}")
                if r.tool_summary:
                    print(f"  Tools: {r.tool_summary}")
                print()

            print(f"検索結果: {len(results)}件（{elapsed:.2f}秒）")

    except Exception as e:
        print(f"エラー: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        conn.close()


def _cmd_status(args: argparse.Namespace) -> None:
    """statusサブコマンドの実行。

    DB統計情報を表示する。
    """
    conn = get_connection()
    try:
        stats = get_stats(conn)

        if args.json:
            # JSON形式で出力
            # DBパスも追加する
            stats["db_path"] = str(DEFAULT_DB_PATH)
            print(json.dumps(stats, ensure_ascii=False, indent=2))
        else:
            # 人間向け形式で出力
            from yb_memory.server import is_server_running

            daemon_status = "稼働中" if is_server_running() else "停止中"
            print("yb-memory 状態:")
            print(f"  スキーマバージョン: {stats['schema_version']}")
            print(f"  セッション数: {stats['session_count']}")
            print(f"  チャンク数: {stats['chunk_count']}")
            print(f"  DBサイズ: {_format_size(stats['db_size_bytes'])}")
            print(f"  DBパス: {DEFAULT_DB_PATH}")
            print(f"  daemon: {daemon_status}")

    except Exception as e:
        print(f"エラー: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        conn.close()


def _cmd_reindex(args: argparse.Namespace) -> None:
    """reindexサブコマンドの実行。

    既存チャンクにベクトルインデックス（embedding）を計算して保存する。
    chunks_vecに未登録のチャンクのみ対象とする。
    """
    conn = get_connection()
    try:
        result = reindex_embeddings(conn, dry_run=args.dry_run)
        if args.dry_run:
            print(f"[dry-run] ベクトルインデックス未作成: {result['total']}件")
        else:
            print(f"\nreindex完了:")
            print(f"  対象: {result['total']}件")
            print(f"  処理: {result['processed']}件")
            print(f"  スキップ: {result['skipped']}件")
    except Exception as e:
        print(f"エラー: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        conn.close()


def _cmd_serve(args: argparse.Namespace) -> None:
    """serveサブコマンドの実行。

    検索サーバーを起動する。--daemonでバックグラウンド起動が可能。
    """
    from yb_memory.server import start_server

    start_server(daemonize=args.daemon)


def _cmd_stop(args: argparse.Namespace) -> None:
    """stopサブコマンドの実行。

    検索サーバーを停止する。
    """
    from yb_memory.server import stop_server

    if not stop_server():
        sys.exit(1)


def _cmd_ping(args: argparse.Namespace) -> None:
    """pingサブコマンドの実行。

    検索サーバーの稼働状態を確認する。
    """
    from yb_memory.server import is_server_running, send_request

    if not is_server_running():
        print("サーバーは起動していません")
        sys.exit(1)

    response = send_request({"action": "ping"}, timeout=3.0)
    if response and response.get("status") == "ok":
        model_status = "ロード済み" if response.get("model_loaded") else "未ロード"
        print(f"サーバー稼働中 (モデル: {model_status})")
    else:
        print("サーバーから応答がありません")
        sys.exit(1)


def _cmd_gc(args: argparse.Namespace) -> None:
    """gcサブコマンドの実行。

    指定日数より古いチャンクを削除する。
    関連するセッション情報も整合性を保って更新する。
    """
    from datetime import datetime, timedelta, timezone

    conn = get_connection()
    try:
        cutoff = datetime.now(timezone.utc) - timedelta(days=args.older_than)
        cutoff_str = cutoff.isoformat()

        # 削除対象のカウント
        count = conn.execute(
            "SELECT COUNT(*) FROM chunks WHERE created_at < ?",
            (cutoff_str,),
        ).fetchone()[0]

        if count == 0:
            print(f"{args.older_than}日以上前のチャンクはありません")
            return

        if args.dry_run:
            print(f"[dry-run] 削除対象: {count}件（{args.older_than}日以上前）")
            return

        # 削除実行（chunks_vecとchunks_ftsはトリガーで連動削除）
        conn.execute("DELETE FROM chunks WHERE created_at < ?", (cutoff_str,))
        # セッションのchunk_countを更新
        conn.execute(
            """
            UPDATE sessions SET chunk_count = (
                SELECT COUNT(*) FROM chunks WHERE chunks.session_id = sessions.session_id
            )
        """
        )
        # chunk_count=0のセッションも削除
        conn.execute("DELETE FROM sessions WHERE chunk_count = 0")
        conn.commit()

        print(f"削除完了: {count}件（{args.older_than}日以上前）")
    finally:
        conn.close()


def main() -> None:
    """CLIエントリポイント。argparseでサブコマンドをパースしてディスパッチする。"""
    parser = argparse.ArgumentParser(
        prog="yb-memory",
        description="Claude Code用長期記憶ツール",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # --- ingest サブコマンド ---
    ingest_parser = subparsers.add_parser(
        "ingest",
        help="セッションログをDBに取り込む",
    )
    ingest_parser.add_argument(
        "--session-id",
        type=str,
        default=None,
        help="特定セッションのみ取り込む（UUID指定）",
    )
    ingest_parser.add_argument(
        "--all",
        action="store_true",
        default=False,
        help="全セッションを取り込む",
    )
    ingest_parser.add_argument(
        "--since",
        type=str,
        default=None,
        help="指定日以降のセッションを取り込む（ISO8601形式、例: 2026-03-01）",
    )
    ingest_parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="DB書き込みせず対象を表示のみ",
    )

    # --- search サブコマンド ---
    search_parser = subparsers.add_parser(
        "search",
        help="記憶を検索する",
    )
    search_parser.add_argument(
        "query",
        type=str,
        help="検索クエリ文字列",
    )
    search_parser.add_argument(
        "--project",
        type=str,
        default=None,
        help="プロジェクトパスでフィルタ",
    )
    search_parser.add_argument(
        "--all-projects",
        action="store_true",
        default=False,
        help="全プロジェクト横断で検索",
    )
    search_parser.add_argument(
        "--limit",
        type=int,
        default=5,
        help="結果件数（デフォルト: 5）",
    )
    search_parser.add_argument(
        "--mode",
        choices=["fts", "vector", "hybrid"],
        default="hybrid",
        help="検索モード（デフォルト: hybrid）",
    )
    search_parser.add_argument(
        "--json",
        action="store_true",
        default=False,
        help="JSON形式で出力",
    )

    # --- status サブコマンド ---
    status_parser = subparsers.add_parser(
        "status",
        help="DB統計情報を表示する",
    )
    status_parser.add_argument(
        "--json",
        action="store_true",
        default=False,
        help="JSON形式で出力",
    )

    # --- reindex サブコマンド ---
    reindex_parser = subparsers.add_parser(
        "reindex",
        help="既存チャンクにベクトルインデックスを作成する",
    )
    reindex_parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="対象件数のみ表示",
    )

    # --- serve サブコマンド ---
    serve_parser = subparsers.add_parser("serve", help="検索サーバーを起動する")
    serve_parser.add_argument(
        "--daemon",
        "-d",
        action="store_true",
        help="バックグラウンドで起動",
    )

    # --- stop サブコマンド ---
    subparsers.add_parser("stop", help="検索サーバーを停止する")

    # --- ping サブコマンド ---
    subparsers.add_parser("ping", help="検索サーバーの稼働を確認する")

    # --- gc サブコマンド ---
    gc_parser = subparsers.add_parser("gc", help="古いチャンクを削除する")
    gc_parser.add_argument(
        "--older-than",
        type=int,
        default=180,
        help="指定日数より古いチャンクを削除（デフォルト: 180）",
    )
    gc_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="削除対象を表示するのみ",
    )

    args = parser.parse_args()

    # サブコマンドへのディスパッチ
    if args.command == "ingest":
        _cmd_ingest(args)
    elif args.command == "search":
        _cmd_search(args)
    elif args.command == "status":
        _cmd_status(args)
    elif args.command == "reindex":
        _cmd_reindex(args)
    elif args.command == "serve":
        _cmd_serve(args)
    elif args.command == "stop":
        _cmd_stop(args)
    elif args.command == "ping":
        _cmd_ping(args)
    elif args.command == "gc":
        _cmd_gc(args)


if __name__ == "__main__":
    main()
