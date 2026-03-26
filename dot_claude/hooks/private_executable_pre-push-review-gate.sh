#!/usr/bin/env bash
# PreToolUseフック: レビュー未完了のブランチからのpushをブロックする
# /pr-3-review が完了していないブランチのpushを物理的に防止する
set -euo pipefail

# jqが未インストールの場合はスキップ（安全側に倒す）
if ! command -v jq &>/dev/null; then
  exit 0
fi

# stdinからツール入力のJSONを読み取る
input="$(cat)"

# .tool_input.command を抽出
command="$(echo "$input" | jq -r '.tool_input.command // empty')"

# コマンドが空ならスキップ
if [[ -z "$command" ]]; then
  exit 0
fi

# "git push" が含まれなければスキップ
# チェインコマンド（git add . && git push）にも対応するため行頭アンカーなし
if ! echo "$command" | grep -qE '\bgit\s+push\b'; then
  exit 0
fi

# gitリポジトリ外で実行された場合はスキップ（安全側に倒す）
if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  exit 0
fi

# 現在のブランチを取得
branch="$(git branch --show-current 2>/dev/null || echo "")"

# ブランチ名が取得できない場合はスキップ（detached HEAD等）
if [[ -z "$branch" ]]; then
  exit 0
fi

# main/master/develop への直接pushは対象外
if [[ "$branch" == "main" || "$branch" == "master" || "$branch" == "develop" ]]; then
  exit 0
fi

# ブランチ名の "/" を "-" に置換して安全なファイル名にする
safe_branch="$(echo "$branch" | tr '/' '-')"
flag_file="/tmp/claude-sessions/review-passed-${safe_branch}"

# フラグ管理ディレクトリが存在しない場合はフラグシステム未初期化として通過
# （一度もレビュースキルを実行していない環境）
if [[ ! -d "/tmp/claude-sessions" ]]; then
  exit 0
fi

# フラグファイルの存在を確認
if [[ ! -f "$flag_file" ]]; then
  echo "ブロック: レビューが未完了です。/pr-3-review を実施してからpushしてください。" >&2
  exit 2
fi

# フラグファイルからタイムスタンプを読み取る
review_timestamp="$(cat "$flag_file" 2>/dev/null || echo "0")"
current_timestamp="$(date +%s)"

# タイムスタンプが数値でない場合はブロック（不正なフラグファイル）
if ! [[ "$review_timestamp" =~ ^[0-9]+$ ]]; then
  echo "ブロック: レビューが未完了です。/pr-3-review を実施してからpushしてください。" >&2
  exit 2
fi

# 現在時刻との差が3600秒（1時間）以内か確認
elapsed=$(( current_timestamp - review_timestamp ))
if (( elapsed > 3600 )); then
  echo "ブロック: レビュー結果が期限切れです（1時間超過）。/pr-3-review を再実施してください。" >&2
  exit 2
fi

# レビュー済みかつ有効期限内 → 通過
exit 0
