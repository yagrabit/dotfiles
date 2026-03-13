#!/bin/bash
# Claude Code Notification hook スクリプト
# 許可待ち・入力待ち状態を /tmp/claude-sessions/{safe_pane_id}.json に書き出し、
# tmuxステータスバーから参照できるようにする。

# --- stdinからJSON読み取り ---
input="$(cat)" || true

# jqが利用可能か確認
if ! command -v jq &>/dev/null; then
    exit 0
fi

# --- JSONフィールド抽出 ---
notification_type="$(echo "$input" | jq -r '.notification_type // empty' 2>/dev/null)" || true
message="$(echo "$input" | jq -r '.message // empty' 2>/dev/null)" || true

# notification_typeが空なら何もしない
if [[ -z "$notification_type" ]]; then
    exit 0
fi

# --- notification_type に応じて state を決定 ---
case "$notification_type" in
    permission_prompt)
        state="waiting"
        ;;
    elicitation_dialog)
        state="waiting"
        ;;
    idle_prompt)
        state="idle"
        ;;
    *)
        # auth_success等、対象外のnotification_typeは即終了
        exit 0
        ;;
esac

# --- tmuxペインID取得 ---
pane_id="${TMUX_PANE:-}"

# $TMUX_PANE が空の場合、tmuxコマンドでフォールバック取得
if [[ -z "$pane_id" ]]; then
    pane_id="$(tmux display-message -p '#{pane_id}' 2>/dev/null)" || true
fi

# それでも取得できなければ終了
if [[ -z "$pane_id" ]]; then
    exit 0
fi

# --- tmux情報取得 ---
tmux_info="$(tmux display-message -t "$pane_id" -p '#{window_name}||#{window_index}||#{session_name}||#{pane_current_path}' 2>/dev/null)" || true

if [[ -z "$tmux_info" ]]; then
    exit 0
fi

# tmux情報をパース（区切り文字: ||）
IFS='||' read -r window_name _ window_index _ session_name _ pane_path <<< "$tmux_info"

# --- safe_pane_id: % を pct に置換 ---
safe_pane_id="${pane_id//%/pct}"

# --- 出力ディレクトリ作成 ---
session_dir="/tmp/claude-sessions"
mkdir -p "$session_dir" 2>/dev/null || true

# --- タイムスタンプ取得 ---
timestamp="$(date +%s)" || true

# --- 一時ファイルに書き込み、mvでアトミック書き込み ---
tmp_file="${session_dir}/${safe_pane_id}.tmp.$$"
target_file="${session_dir}/${safe_pane_id}.json"

jq -n \
    --arg pane_id "$pane_id" \
    --arg state "$state" \
    --arg notification_type "$notification_type" \
    --arg message "$message" \
    --arg window_name "$window_name" \
    --arg window_index "$window_index" \
    --arg session_name "$session_name" \
    --arg pane_path "$pane_path" \
    --argjson timestamp "${timestamp:-0}" \
    '{
        pane_id: $pane_id,
        state: $state,
        notification_type: $notification_type,
        message: $message,
        window_name: $window_name,
        window_index: $window_index,
        session_name: $session_name,
        pane_path: $pane_path,
        timestamp: $timestamp
    }' > "$tmp_file" 2>/dev/null || true

# 一時ファイルが正常に作成された場合のみmvする
if [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$target_file" 2>/dev/null || true
else
    rm -f "$tmp_file" 2>/dev/null || true
fi

# --- デバッグログ出力 ---
log_file="${session_dir}/debug.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') notification_type=${notification_type} state=${state} pane_id=${pane_id} message=${message}" >> "$log_file" 2>/dev/null || true

exit 0
