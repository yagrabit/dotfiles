#!/bin/bash
# Claude Codeインスタンス監視・移動スクリプト
# tmuxポップアップから呼び出され、fzfで一覧表示・選択移動する
# 全ペインをスキャンしてClaude Codeインスタンスを検出し、JSONがあればstate情報をマージする

SCRIPT_PATH="$(realpath "$0")"
SESSION_DIR="/tmp/claude-sessions"

generate_list() {
  # セッションディレクトリがなければ作成（orphan cleanupやJSON参照に必要）
  mkdir -p "$SESSION_DIR"

  # --- orphan cleanup: ペインが消滅済みのJSONを削除 ---
  # 現存する全ペインIDを取得
  local existing_panes
  existing_panes=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)

  for json_file in "$SESSION_DIR"/*.json; do
    [[ -e "$json_file" ]] || continue

    local json_pane_id
    json_pane_id=$(jq -r '.pane_id // empty' "$json_file" 2>/dev/null)
    [[ -z "$json_pane_id" ]] && continue

    # このpane_idが現存ペインに含まれなければ削除
    if ! echo "$existing_panes" | grep -qxF "$json_pane_id"; then
      rm -f "$json_file"
    fi
  done

  # --- 全ペインをスキャンしてClaude Codeインスタンスを検出 ---
  local now
  now=$(date +%s)
  local found=0

  while IFS='|' read -r pane_id _ pane_cmd _ window_name _ window_index _ session_name _ pane_path; do
    # Claude CodeのNode.jsバイナリはSemVer名（例: 1.0.33）で実行されるため、
    # pane_current_commandがSemVerパターンでなければスキップ
    if ! [[ "$pane_cmd" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      continue
    fi

    # safe_pane_id: %をpctに置換
    local safe_pane_id="${pane_id//%/pct}"
    local json_file="$SESSION_DIR/${safe_pane_id}.json"

    local state="active"
    local notification_type=""

    if [[ -f "$json_file" ]]; then
      # JSONからstate, notification_type, timestampを読み取り
      local json_state json_notification_type json_timestamp
      read -r json_state json_notification_type json_timestamp < <(
        jq -r '[(.state // ""), (.notification_type // ""), ((.timestamp // 0) | tostring)] | @tsv' "$json_file" 2>/dev/null
      )

      if [[ -n "$json_timestamp" && "$json_timestamp" != "0" ]]; then
        local age=$(( now - json_timestamp ))
        if (( age <= 300 )); then
          # 5分以内: JSONのstate/notification_typeをそのまま使用
          state="${json_state:-active}"
          notification_type="${json_notification_type:-}"
        else
          # 5分超過: notification未発火 = 実行中と推定（JSONは削除しない）
          state="active"
        fi
      else
        # タイムスタンプなし: activeと推定
        state="active"
      fi
    fi

    # stateに応じたアイコン・ステータステキスト・優先度を決定
    local icon status_text priority
    case "$state" in
      waiting)
        priority=1
        if [[ "$notification_type" == "permission_prompt" ]]; then
          icon="🔴"
          status_text="許可待ち"
        elif [[ "$notification_type" == "elicitation_dialog" ]]; then
          icon="🔴"
          status_text="質問中"
        else
          icon="🔴"
          status_text="待機中"
        fi
        ;;
      idle)
        priority=2
        icon="🟡"
        status_text="入力待ち"
        ;;
      active)
        priority=3
        icon="🟢"
        status_text="実行中"
        ;;
      *)
        priority=9
        icon="⚪"
        status_text="不明"
        ;;
    esac

    # ディレクトリのベースネームを取得
    local dir_basename
    dir_basename=$(basename "$pane_path" 2>/dev/null)
    [[ -z "$dir_basename" ]] && dir_basename="-"

    # 表示行を出力（先頭にソート用優先度、末尾にタブ+pane_id）
    printf '%s %s %s │ %s │ %s │ %s:%s\t%s\n' \
      "$priority" "$icon" "$status_text" "$window_name" "$dir_basename" "$session_name" "$window_index" "$pane_id"

    found=1
  done < <(tmux list-panes -a -F '#{pane_id}||#{pane_current_command}||#{window_name}||#{window_index}||#{session_name}||#{pane_current_path}' 2>/dev/null)

  if (( found == 0 )); then
    echo "Claude Codeが見つかりません"
    return
  fi
}

# jqが使えるか確認
if ! command -v jq &>/dev/null; then
  echo "エラー: jqが見つかりません。インストールしてください。"
  exit 1
fi

# --list サブコマンド: リスト生成のみ行い終了（fzfのreloadから呼ばれる）
if [[ "${1:-}" == "--list" ]]; then
  generate_list | sort -t ' ' -k1,1n | sed 's/^[0-9]* //'
  exit 0
fi

# fzfが使えるか確認
if ! command -v fzf &>/dev/null; then
  echo "エラー: fzfが見つかりません。インストールしてください。"
  exit 1
fi

# リストを生成し、ソート・整形してfzfに渡す
selected=$(
  generate_list \
    | sort -t ' ' -k1,1n \
    | sed 's/^[0-9]* //' \
    | fzf \
        --ansi \
        --header="Claude Code 監視 - Enter で移動 / Shift+R でリフレッシュ" \
        --no-sort \
        --reverse \
        --delimiter=$'\t' \
        --with-nth=1 \
        --preview "tmux capture-pane -t {2} -p -e | tail -n \$FZF_PREVIEW_LINES" \
        --preview-window "right:50%:wrap" \
        --bind "R:reload($SCRIPT_PATH --list)"
)

# fzfでキャンセルされた場合
[[ -z "$selected" ]] && exit 0

# 選択行の末尾（タブ区切り）からpane_idを取得
pane_id=$(echo "$selected" | awk -F'\t' '{print $NF}')

# 選択したペインに移動（別セッションの場合はセッション切り替えも行う）
tmux switch-client -t "$pane_id" 2>/dev/null
tmux select-window -t "$pane_id"
tmux select-pane -t "$pane_id"
