#!/bin/bash
# tmuxステータスバー用 Claude Code監視状態集計スクリプト
# status-rightから呼ばれ、セッションの状態を短い文字列で返す

SESSION_DIR="/tmp/claude-sessions"

# Nerd Font / Powerline アイコン（UTF-8バイトシーケンス、bash 3.2互換）
PL_LEFT=$'\xee\x82\xb2'    # Powerline左矢印 (U+E0B2)
PL_RIGHT=$'\xee\x82\xb0'   # Powerline右矢印 (U+E0B0)
ICON_TERM=$'\xef\x84\xa0'   # ターミナルアイコン (U+F120)
ICON_BELL=$'\xef\x83\xb3'   # ベルアイコン (U+F0F3)

# セッションディレクトリが無ければ何も出力せず終了
[[ -d "$SESSION_DIR" ]] || exit 0

total=0
attention=0
now=$(date +%s)

for f in "$SESSION_DIR"/*.json; do
  # globがマッチしなかった場合（ファイルが1つも無い）
  [[ -e "$f" ]] || break

  # JSONからフィールドを一括読み取り（jq呼び出しを1回に抑える）
  read -r pane_id timestamp state < <(jq -r '[.pane_id, .timestamp, .state] | @tsv' "$f" 2>/dev/null)

  # jq失敗時はファイルを削除してスキップ
  if [[ -z "$pane_id" ]]; then
    rm -f "$f"
    continue
  fi

  # ペインが存在しなければファイル削除
  if ! tmux display-message -t "$pane_id" -p '' 2>/dev/null; then
    rm -f "$f"
    continue
  fi

  # タイムスタンプが5分以上前ならファイル削除
  if [[ -n "$timestamp" ]] && (( now - timestamp > 300 )); then
    rm -f "$f"
    continue
  fi

  # 集計
  total=$((total + 1))
  if [[ "$state" == "waiting" || "$state" == "idle" ]]; then
    attention=$((attention + 1))
  fi
done

# 出力
if (( total == 0 )); then
  # Claudeが1つも無い場合は空文字列
  exit 0
elif (( attention > 0 )); then
  # 青セグメント(total) → 赤セグメント(attention)
  printf '#[fg=colour31,bg=colour235]%s#[fg=colour255,bg=colour31] %s %d #[fg=colour31,bg=colour196]%s#[fg=colour255,bg=colour196,bold] %s %d #[fg=colour196,bg=colour235]%s#[default] ' \
    "$PL_LEFT" "$ICON_TERM" "$total" "$PL_RIGHT" "$ICON_BELL" "$attention" "$PL_RIGHT"
else
  # 青セグメントのみ
  printf '#[fg=colour31,bg=colour235]%s#[fg=colour255,bg=colour31,bold] %s %d #[fg=colour31,bg=colour235]%s#[default] ' \
    "$PL_LEFT" "$ICON_TERM" "$total" "$PL_RIGHT"
fi
