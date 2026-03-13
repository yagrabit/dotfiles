#!/bin/bash
# Claude Codeインスタンス監視・移動スクリプト
# tmuxポップアップ（Prefix+m）から呼び出され、fzfで一覧表示・選択移動する

SESSION_DIR="/tmp/claude-sessions"

# fzfが使えるか確認
if ! command -v fzf &>/dev/null; then
  echo "エラー: fzfが見つかりません。インストールしてください。"
  exit 1
fi

# jqが使えるか確認
if ! command -v jq &>/dev/null; then
  echo "エラー: jqが見つかりません。インストールしてください。"
  exit 1
fi

# セッションディレクトリが存在しない場合
if [[ ! -d "$SESSION_DIR" ]]; then
  echo "Claude Codeが見つかりません"
  exit 0
fi

# 現在時刻（エポック秒）
now=$(date +%s)

# fzf表示用リストを構築（ソート用優先度付き）
lines=()

for json_file in "$SESSION_DIR"/*.json; do
  # globがマッチしなかった場合（ファイルが存在しない）
  [[ -e "$json_file" ]] || continue

  # JSONから全フィールドを一括読み取り（jq呼び出しを1回に抑える）
  read -r pane_id state notification_type window_name window_index session_name pane_path timestamp < <(
    jq -r '[.pane_id, .state, .notification_type, .window_name, .window_index, .session_name, .pane_path, (.timestamp | tostring)] | @tsv' "$json_file" 2>/dev/null
  )

  # pane_idが空ならスキップ
  [[ -z "$pane_id" ]] && continue

  # ペインがまだ存在するか確認
  if ! tmux display-message -t "$pane_id" -p '' 2>/dev/null; then
    rm -f "$json_file"
    continue
  fi

  # タイムスタンプが5分以上古いファイルは削除
  if [[ -n "$timestamp" ]]; then
    age=$(( now - timestamp ))
    if (( age > 300 )); then
      rm -f "$json_file"
      continue
    fi
  fi

  # stateに応じたアイコンとステータステキスト、ソート優先度を決定
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
  dir_basename=$(basename "$pane_path" 2>/dev/null)
  [[ -z "$dir_basename" ]] && dir_basename="-"

  # 表示行を構築（先頭にソート用優先度、末尾にタブ+pane_id）
  display_line="${priority} ${icon} ${status_text} │ ${window_name} │ ${dir_basename} │ ${session_name}:${window_index}"
  # ソート用優先度付きの行（優先度 + 表示内容 + タブ + pane_id）
  lines+=("${display_line}	${pane_id}")
done

# 一覧が空の場合
if [[ ${#lines[@]} -eq 0 ]]; then
  echo "Claude Codeが見つかりません"
  exit 0
fi

# 優先度でソートし、先頭の優先度番号を除去してfzfに渡す
selected=$(
  printf '%s\n' "${lines[@]}" \
    | sort -t ' ' -k1,1n \
    | sed 's/^[0-9]* //' \
    | fzf \
        --ansi \
        --header="Claude Code 監視 - Enter で移動" \
        --no-sort \
        --reverse \
        --delimiter=$'\t' \
        --with-nth=1
)

# fzfでキャンセルされた場合
[[ -z "$selected" ]] && exit 0

# 選択行の末尾（タブ区切り）からpane_idを取得
pane_id=$(echo "$selected" | awk -F'\t' '{print $NF}')

# 選択したペインのウィンドウ・ペインに移動
tmux select-window -t "$pane_id"
tmux select-pane -t "$pane_id"
