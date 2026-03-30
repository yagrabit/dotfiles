#!/bin/bash
# glow-preview.sh — fzf + fd + glow によるMarkdownプレビューア
# tmuxポップアップから呼び出し。fzfプレビューペイン内でスクロール閲覧まで完結
# お気に入り機能: Ctrl-Fでトグル、★付きでリスト上部にピン留め

set -euo pipefail

HISTORY_FILE="/tmp/claude-sessions/md-history.log"
FAVORITES_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/md-favorites.txt"

# お気に入りファイルの初期化
mkdir -p "$(dirname "$FAVORITES_FILE")"
[[ -f "$FAVORITES_FILE" ]] || touch "$FAVORITES_FILE"

# --- サブコマンド: お気に入りトグル ---
if [[ "${1:-}" == "--toggle" ]]; then
  TARGET="${2:-}"
  [[ -z "$TARGET" ]] && exit 1
  if grep -qxF "$TARGET" "$FAVORITES_FILE" 2>/dev/null; then
    { grep -vxF "$TARGET" "$FAVORITES_FILE" || true; } > "${FAVORITES_FILE}.tmp"
    mv "${FAVORITES_FILE}.tmp" "$FAVORITES_FILE"
  else
    echo "$TARGET" >> "$FAVORITES_FILE"
  fi
  exit 0
fi

# --- ファイルリスト生成 ---
generate_list() {
  local search_dir="$1"

  # (0) お気に入り（★プレフィックス付き、リスト最上部に表示）
  if [[ -s "$FAVORITES_FILE" ]]; then
    while IFS= read -r fp; do
      [[ -n "$fp" && -f "$fp" ]] && echo "★ $fp" || true
    done < "$FAVORITES_FILE"
  fi

  # (1) Claude編集履歴を新しい順に出力（存在するファイルのみ）
  if [[ -f "$HISTORY_FILE" ]]; then
    tail -r "$HISTORY_FILE" | cut -f2 | while IFS= read -r fp; do
      [[ -n "$fp" && -f "$fp" ]] && echo "[Claude] $fp" || true
    done
  fi

  # (2) カレントディレクトリ以下のMDファイル（.gitignore無視）
  (fd --type f --extension md --no-ignore --hidden \
    --exclude node_modules --exclude .git \
    . "$search_dir" 2>/dev/null || true) | while IFS= read -r fp; do
    realpath "$fp" 2>/dev/null || echo "$fp"
  done
}

# 重複排除（お気に入り → Claude履歴 → fdスキャンの順で優先）
dedup_list() {
  awk '{
    path = $0
    sub(/^★ /, "", path)
    sub(/^\[Claude\] /, "", path)
    if (!seen[path]++) print $0
  }'
}

# --- リスト出力モード（fzfのreloadから呼ばれる） ---
if [[ "${1:-}" == "--list" ]]; then
  generate_list "${2:-.}" | dedup_list
  exit 0
fi

# --- メイン ---
SEARCH_DIR="${1:-.}"

FILE_LIST=$(generate_list "$SEARCH_DIR" | dedup_list)

if [[ -z "$FILE_LIST" ]]; then
  echo "プレビュー対象のMDファイルがありません"
  read -n 1 -r -s 2>/dev/null || true
  exit 0
fi

# スクリプト自身のパス（reloadとtoggleで使用）
SELF="$(realpath "$0")"

echo "$FILE_LIST" | fzf \
  --ansi \
  --header="Enter: プレビュー(q→戻る) / Ctrl-F: ★お気に入り / Ctrl-Y: パスコピー / ESC: 閉じる" \
  --reverse \
  --preview 'bash -c '\''f="{}"; f="${f#★ }"; f="${f#\[Claude\] }"; glow -s dark -w $FZF_PREVIEW_COLUMNS "$f"'\''' \
  --preview-window "right:60%:wrap" \
  --bind "enter:execute(bash -c 'f=\"{}\"; f=\"\${f#★ }\"; f=\"\${f#\\[Claude\\] }\"; glow -p -w 0 \"\$f\"')" \
  --bind "ctrl-f:execute-silent(bash -c 'f=\"{}\"; f=\"\${f#★ }\"; f=\"\${f#\\[Claude\\] }\"; \"$SELF\" --toggle \"\$f\"')+reload(\"$SELF\" --list \"$SEARCH_DIR\")+first" \
  --bind "ctrl-y:execute-silent(bash -c 'f=\"{}\"; f=\"\${f#★ }\"; f=\"\${f#\\[Claude\\] }\"; printf \"%s\" \"\$f\" | pbcopy')+abort" \
  || exit 0
