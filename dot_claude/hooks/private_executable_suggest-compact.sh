#!/bin/bash
# suggest-compact.sh — UserPromptSubmitフック
#
# セッション内のプロンプト回数をカウントし、15回ごとに /compact の実行を提案する。
# カウンターファイルは /tmp に保存され、OSの自動クリーンアップに任せる。

set -euo pipefail

# stdinを消費（UserPromptSubmitの入力を読み捨て）
cat > /dev/null

# jq未インストール時は何もしない
if ! command -v jq &>/dev/null; then
  exit 0
fi

# セッションIDの決定（環境変数 → ppidフォールバック）
SID="${CLAUDE_SESSION_ID:-daily-$(date +%Y%m%d)}"
COUNTER_FILE="/tmp/claude-compact-counter-${SID}.txt"

# カウンター読み込み（ファイルがなければ0から開始）
COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null) || COUNT=0
fi

# インクリメントして保存
COUNT=$(( COUNT + 1 ))
echo "$COUNT" > "$COUNTER_FILE"

# 15回ごとにコンパクション提案を出力
if [ $(( COUNT % 15 )) -eq 0 ]; then
  MSG="FIC: ${COUNT}回目のプロンプトです。コンテキストが大きくなっています。/compact の実行を検討してください。"
  jq -Rn --arg msg "$MSG" \
    '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$msg}}'
fi

exit 0
