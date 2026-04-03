#!/bin/bash
# tmuxステータスバー用 Claude Code監視状態集計スクリプト
# status-rightから呼ばれ、セッションの状態を短い文字列で返す
#
# 検出方式: プロセスベース（pane_current_commandがSemVerパターンにマッチ）
# ポップアップスクリプト（claude-monitor-popup.sh）と同一のロジック

SESSION_DIR="/tmp/claude-sessions"

# Nerd Font / Powerline アイコン（UTF-8バイトシーケンス、bash 3.2互換）
PL_LEFT=$'\xee\x82\xb2'    # Powerline左矢印 (U+E0B2)
PL_RIGHT=$'\xee\x82\xb0'   # Powerline右矢印 (U+E0B0)
ICON_TERM=$'\xef\x84\xa0'   # ターミナルアイコン (U+F120)
ICON_BELL=$'\xef\x83\xb3'   # ベルアイコン (U+F0F3)

total=0
attention=0

# プロセス検出で見つかったペインIDを記録（孤児JSON削除用）
active_pane_ids=""

# 全ペインをスキャンしてClaude Codeインスタンスを検出
# Claude CodeのNode.jsバイナリはSemVer名（例: 1.0.33）で実行される
while IFS='|' read -r pane_id _ pane_cmd; do
  # pane_current_commandがSemVerパターンでなければスキップ
  if ! [[ "$pane_cmd" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    continue
  fi

  total=$((total + 1))

  # safe_pane_id: %をpctに置換（statusline-command.pyと同じ規則）
  safe_pane_id="${pane_id//%/pct}"
  active_pane_ids="${active_pane_ids} ${safe_pane_id}"
  json_file="$SESSION_DIR/${safe_pane_id}.json"

  # JSONがあればstateを読み取り、なければactiveとみなす
  state="active"
  if [[ -f "$json_file" ]]; then
    json_state=$(jq -r '.state // "active"' "$json_file" 2>/dev/null)
    if [[ -n "$json_state" ]]; then
      state="$json_state"
    fi
  fi

  if [[ "$state" == "waiting" || "$state" == "idle" ]]; then
    attention=$((attention + 1))
  fi
done < <(tmux list-panes -a -F '#{pane_id}||#{pane_current_command}' 2>/dev/null)

# 孤児JSONファイルの削除: プロセス検出で見つからなかったセッションファイルを削除
# review-passed-* 等の非セッションファイルは除外
if [[ -d "$SESSION_DIR" ]]; then
  for f in "$SESSION_DIR"/pct*.json; do
    [[ -e "$f" ]] || break
    fname=$(basename "$f" .json)
    # active_pane_idsに含まれなければ孤児として削除
    case " $active_pane_ids " in
      *" $fname "*) ;;  # 検出済み: 何もしない
      *) rm -f "$f" ;;  # 孤児: 削除
    esac
  done
fi

# odin-boardサマリーの取得（TTL 10秒キャッシュ、status-intervalと同期）
BOARD_SCRIPT="${HOME}/.config/tmux/odin-board.sh"
BOARD_CACHE="/tmp/odin-board-status-cache"
BOARD_CACHE_TTL=10
board_summary=""
cache_hit=false
if [[ -x "$BOARD_SCRIPT" ]]; then
  if [[ -f "$BOARD_CACHE" ]]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$BOARD_CACHE" 2>/dev/null || stat -c %Y "$BOARD_CACHE" 2>/dev/null || echo 0) ))
    if (( cache_age < BOARD_CACHE_TTL )); then
      board_summary=$(cat "$BOARD_CACHE")
      cache_hit=true
    fi
  fi
  if [[ "$cache_hit" == false ]]; then
    board_summary=$("$BOARD_SCRIPT" status 2>/dev/null || true)
    echo -n "$board_summary" > "$BOARD_CACHE" 2>/dev/null || true
  fi
fi

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

# odin-boardサマリーの出力（タスクがある場合のみ）
if [[ -n "$board_summary" ]]; then
  ICON_BOARD=$'\xef\x81\x88'   # クリップボードアイコン (U+F048)
  printf '#[fg=colour136,bg=colour235]%s#[fg=colour235,bg=colour136] %s %s #[fg=colour136,bg=colour235]%s#[default] ' \
    "$PL_LEFT" "$ICON_BOARD" "$board_summary" "$PL_RIGHT"
fi
