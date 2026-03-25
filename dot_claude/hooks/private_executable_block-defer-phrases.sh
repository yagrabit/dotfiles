#!/usr/bin/env bash
# PreToolUseフック: PRコメント返信やコミットメッセージ内の先送り表現をブロックする
# 「後で対応」「fix later」等の先送りフレーズを検出し、今のスコープで解決するかIssue化を促す
set -euo pipefail

# 日本語パターンをgrep -Eで扱うためにロケールを設定
export LC_ALL=en_US.UTF-8

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

# 対象コマンドの判定（対象外なら早期リターン）
# gh pr comment, gh pr review, gh issue comment, git commit のみ検査
is_target=false
if echo "$command" | grep -qE '^\s*gh\s+pr\s+comment\b'; then
  is_target=true
elif echo "$command" | grep -qE '^\s*gh\s+pr\s+review\b'; then
  is_target=true
elif echo "$command" | grep -qE '^\s*gh\s+issue\s+comment\b'; then
  is_target=true
elif echo "$command" | grep -qE '^\s*git\s+commit\b'; then
  is_target=true
fi

if [[ "$is_target" != "true" ]]; then
  exit 0
fi

# 先送り表現の検出パターン
# 日本語パターン
jp_pattern='後で対応|あとで対応|次のPRで|別PRで|別のPRで|一旦スキップ|いったんスキップ|時間があれば|余裕があれば'
# 英語パターン（大文字小文字を区別しない）
en_pattern='will fix later|fix later|in a follow-up|follow-up PR|followup PR|punt|defer to|out of scope'

# コマンド全体（-b, --body, -m フラグの値を含む）から先送り表現を検出
matched=""
if matched=$(echo "$command" | grep -oEi "$jp_pattern|$en_pattern" | head -1) && [[ -n "$matched" ]]; then
  echo "ブロック: 先送り表現「${matched}」が検出されました。問題を今のスコープで解決するか、GitHub Issueを作成してから返信してください。" >&2
  exit 2
fi

# ブロック対象外のコマンドは通過
exit 0
