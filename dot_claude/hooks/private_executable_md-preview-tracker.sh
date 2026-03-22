#!/bin/bash
# md-preview-tracker.sh — PostToolUse hook (Edit|Write matcher)
#
# ClaudeがMDファイルを編集した際にファイルパスをペインごとに記録する。
# tmuxのPrefix+Eでglowプレビューを開くために使用。

set -euo pipefail

INPUT=$(cat)

if ! command -v jq &>/dev/null; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# .mdファイルのみ対象
case "$FILE_PATH" in
  *.md) ;;
  *) exit 0 ;;
esac

if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# ペインID取得（notification-tracker.shと同じパターン）
pane_id="${TMUX_PANE:-}"
if [ -z "$pane_id" ]; then
  pane_id="$(tmux display-message -p '#{pane_id}' 2>/dev/null)" || true
fi
if [ -z "$pane_id" ]; then
  exit 0
fi

safe_pane_id="${pane_id//%/pct}"

# ファイルパスを記録
session_dir="/tmp/claude-sessions"
mkdir -p "$session_dir" 2>/dev/null || true
echo "$FILE_PATH" > "${session_dir}/${safe_pane_id}-last-md"

exit 0
