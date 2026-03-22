#!/bin/bash
# glow-preview.sh — 同じtmuxウィンドウ内のClaude Codeが最後に編集したMDファイルをglowで表示

SESSION_DIR="/tmp/claude-sessions"

# 現在のウィンドウ内の全ペインIDを取得
PANE_IDS=$(tmux list-panes -F '#{pane_id}' 2>/dev/null)

LATEST_FILE=""
LATEST_TIME=0

for pane_id in $PANE_IDS; do
  safe_id="${pane_id//%/pct}"
  md_file="${SESSION_DIR}/${safe_id}-last-md"

  if [ -f "$md_file" ]; then
    file_path=$(cat "$md_file")
    if [ -f "$file_path" ]; then
      # ファイルの更新時刻を比較（macOS: stat -f %m, Linux: stat -c %Y）
      mod_time=$(stat -f %m "$md_file" 2>/dev/null || stat -c %Y "$md_file" 2>/dev/null || echo 0)
      if [ "$mod_time" -gt "$LATEST_TIME" ]; then
        LATEST_TIME=$mod_time
        LATEST_FILE=$file_path
      fi
    fi
  fi
done

if [ -n "$LATEST_FILE" ]; then
  glow -p "$LATEST_FILE"
else
  echo "プレビュー対象のMDファイルがありません"
  read -n 1
fi
