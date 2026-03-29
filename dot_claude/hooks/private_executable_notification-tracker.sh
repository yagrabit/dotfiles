#!/bin/bash
# Claude Code Notification フック
# 許可待ち(waiting)・入力待ち(idle)状態を検知し、
# /tmp/claude-sessions/{safe_pane_id}.json の state フィールドを更新する。
# statusline-command.py が書く既存JSONを保持し、state と timestamp のみ上書きする。
# bash 3.2互換（macOS標準）。

# --- stdinからJSON読み取り ---
input="$(cat)"

# jqが利用可能か確認
if ! command -v jq &>/dev/null; then
    exit 0
fi

# --- JSON解析（jq 1回で notification_type を抽出） ---
notification_type="$(echo "$input" | jq -r '.notification_type // empty' 2>/dev/null)" || exit 0

# notification_typeが空なら何もしない
if [ -z "$notification_type" ]; then
    exit 0
fi

# --- notification_type に応じて state を決定 ---
case "$notification_type" in
    permission_prompt|elicitation_dialog)
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
if [ -z "$pane_id" ]; then
    pane_id="$(tmux display-message -p '#{pane_id}' 2>/dev/null)" || true
fi

# それでも取得できなければ終了
if [ -z "$pane_id" ]; then
    exit 0
fi

# --- safe_pane_id: % を pct に置換 ---
safe_pane_id="${pane_id//%/pct}"

# --- ファイルパス ---
session_dir="/tmp/claude-sessions"
target_file="${session_dir}/${safe_pane_id}.json"

mkdir -p "$session_dir" 2>/dev/null

# --- タイムスタンプ ---
timestamp="$(date +%s)"

# --- 既存JSONを読み込み、state, notification_type, timestamp を上書き ---
# statusline-command.py が書いた model, context_pct, rl_5h 等を保持する
tmp_file="${session_dir}/${safe_pane_id}.tmp.$$"

if [ -s "$target_file" ]; then
    # 既存ファイルがある場合: state, notification_type, timestamp を上書き
    jq \
        --arg state "$state" \
        --arg notification_type "$notification_type" \
        --argjson timestamp "$timestamp" \
        '.state = $state | .notification_type = $notification_type | .timestamp = $timestamp' \
        "$target_file" > "$tmp_file" 2>/dev/null
else
    # 既存ファイルがない場合: tmux情報を取得して最低限のJSONを新規作成
    tmux_info="$(tmux display-message -t "$pane_id" -p "#{window_name}\t#{window_index}\t#{session_name}\t#{pane_current_path}" 2>/dev/null)" || true

    if [ -z "$tmux_info" ]; then
        rm -f "$tmp_file" 2>/dev/null
        exit 0
    fi

    # タブ区切りでパース（bash 3.2互換: readの-dオプション不使用）
    window_name="$(echo "$tmux_info" | cut -f1)"
    window_index="$(echo "$tmux_info" | cut -f2)"
    session_name="$(echo "$tmux_info" | cut -f3)"
    pane_path="$(echo "$tmux_info" | cut -f4)"

    jq -n \
        --arg pane_id "$pane_id" \
        --arg state "$state" \
        --arg notification_type "$notification_type" \
        --arg window_name "$window_name" \
        --arg window_index "$window_index" \
        --arg session_name "$session_name" \
        --arg pane_path "$pane_path" \
        --argjson timestamp "$timestamp" \
        '{
            pane_id: $pane_id,
            state: $state,
            notification_type: $notification_type,
            window_name: $window_name,
            window_index: $window_index,
            session_name: $session_name,
            pane_path: $pane_path,
            timestamp: $timestamp
        }' > "$tmp_file" 2>/dev/null
fi

# 一時ファイルが正常に作成された場合のみmvする
if [ -s "$tmp_file" ]; then
    mv "$tmp_file" "$target_file" 2>/dev/null
else
    rm -f "$tmp_file" 2>/dev/null
fi

exit 0
