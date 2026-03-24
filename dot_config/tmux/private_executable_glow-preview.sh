#!/bin/bash
# glow-preview.sh — fzf + fd + glow によるMarkdownプレビューア
# tmuxポップアップから呼び出し。ファイル選択→プレビュー→全画面表示を1画面で完結

set -euo pipefail

# カレントディレクトリ（tmuxのpane_current_pathから渡される）
SEARCH_DIR="${1:-.}"
HISTORY_FILE="/tmp/claude-sessions/md-history.log"

# --- ファイルリスト生成 ---
generate_list() {
  # (1) Claude編集履歴を新しい順に出力（存在するファイルのみ）
  if [[ -f "$HISTORY_FILE" ]]; then
    tail -r "$HISTORY_FILE" | cut -f2 | while read -r fp; do
      [[ -f "$fp" ]] && echo "[Claude] $fp" || true
    done
  fi

  # (2) カレントディレクトリ以下のMDファイル（.gitignore無視）
  (fd --type f --extension md --no-ignore --hidden \
    --exclude node_modules --exclude .git \
    . "$SEARCH_DIR" 2>/dev/null || true) | while read -r fp; do
    realpath "$fp" 2>/dev/null || echo "$fp"
  done
}

# --- メイン ---
# 重複排除（Claude履歴側を優先）してfzfに渡す
FILE_LIST=$(generate_list | awk '{
  path = $0
  sub(/^\[Claude\] /, "", path)
  if (!seen[path]++) print $0
}')

if [[ -z "$FILE_LIST" ]]; then
  echo "プレビュー対象のMDファイルがありません"
  read -n 1 -r -s 2>/dev/null || true
  exit 0
fi

selected=$(echo "$FILE_LIST" | fzf \
  --ansi \
  --header="Enter: 全画面表示 / Ctrl-Y: パスコピー / ESC: 閉じる" \
  --reverse \
  --preview 'bash -c '\''f="{}"; f="${f#\[Claude\] }"; glow -s dark -w $FZF_PREVIEW_COLUMNS "$f"'\''' \
  --preview-window "right:60%:wrap" \
  --bind "ctrl-y:execute-silent(bash -c 'f=\"{}\"; f=\"\${f#\\[Claude\\] }\"; printf \"%s\" \"\$f\" | pbcopy')+abort" \
) || exit 0

[[ -z "$selected" ]] && exit 0

# [Claude]プレフィックスを除去して実パスを取得
file_path="${selected#\[Claude\] }"

# 全画面glowプレビュー（ページャモード）
glow -p "$file_path"
