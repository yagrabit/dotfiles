#!/bin/bash
# memory-ingest.sh — Stopフック
# セッション終了時に会話ログをyb-memoryに自動取り込みする
set -euo pipefail

INPUT=$(cat)

# yb-memoryがインストールされていなければスキップ
if ! command -v yb-memory &>/dev/null; then
  exit 0
fi

# jqがなければスキップ
if ! command -v jq &>/dev/null; then
  exit 0
fi

# セッションIDの取得（3段階フォールバック）

# 1. stdinのJSONからsession_idを取得
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || true

# 2. PIDからsessions/*.jsonを参照
if [ -z "$SESSION_ID" ]; then
  CURRENT_PID=$(echo "$INPUT" | jq -r '.pid // empty' 2>/dev/null) || true
  if [ -n "$CURRENT_PID" ] && [ -f "$HOME/.claude/sessions/${CURRENT_PID}.json" ]; then
    SESSION_ID=$(jq -r '.sessionId // empty' "$HOME/.claude/sessions/${CURRENT_PID}.json" 2>/dev/null) || true
  fi
fi

# 3. sessionsディレクトリの最新ファイルから取得
if [ -z "$SESSION_ID" ]; then
  LATEST=$(ls -t "$HOME/.claude/sessions/"*.json 2>/dev/null | head -1) || true
  if [ -n "$LATEST" ]; then
    SESSION_ID=$(jq -r '.sessionId // empty' "$LATEST" 2>/dev/null) || true
  fi
fi

# セッションIDが取得できたらバックグラウンドで取り込み
if [ -n "$SESSION_ID" ]; then
  nohup yb-memory ingest --session-id "$SESSION_ID" \
    > /tmp/yb-memory-ingest.log 2>&1 &
fi

exit 0
