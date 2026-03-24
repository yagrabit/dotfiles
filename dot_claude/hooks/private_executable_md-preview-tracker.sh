#!/bin/bash
# md-preview-tracker.sh — PostToolUse hook (Edit|Write matcher)
#
# ClaudeがMDファイルを編集した際にグローバル履歴に記録する。
# tmuxのPrefix+E（glow-preview.sh）のfzf候補として使用。

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

# グローバル履歴に追記（glow-preview.shのfzf候補用）
session_dir="/tmp/claude-sessions"
mkdir -p "$session_dir" 2>/dev/null || true
HISTORY_FILE="${session_dir}/md-history.log"
LAST_ENTRY=$(tail -1 "$HISTORY_FILE" 2>/dev/null | cut -f2)
if [ "$LAST_ENTRY" != "$FILE_PATH" ]; then
  printf '%s\t%s\n' "$(date +%s)" "$FILE_PATH" >> "$HISTORY_FILE"
  # 100行超過時は最新50行に刈り込み
  line_count=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
  if [ "$line_count" -gt 100 ]; then
    tail -50 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
  fi
fi

exit 0
