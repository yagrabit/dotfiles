#!/bin/bash
# prompt-recall-memory.sh — UserPromptSubmitフック
# ユーザーのプロンプトで過去の会話を検索し、関連記憶をコンテキストに注入する
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

# ユーザーのプロンプトテキストを抽出
# UserPromptSubmitのstdinは {"user_prompt": "テキスト"} 形式
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // empty' 2>/dev/null) || true

# プロンプトが空または3文字未満ならスキップ（trigram最低要件）
if [ -z "$PROMPT" ] || [ "${#PROMPT}" -lt 3 ]; then
  exit 0
fi

# yb-memoryで検索（JSON出力、最大3件、全プロジェクト横断）
RESULTS=$(yb-memory search "$PROMPT" --all-projects --limit 3 --json 2>/dev/null) || true

# 結果が空配列 "[]" またはエラーならスキップ
if [ -z "$RESULTS" ] || [ "$RESULTS" = "[]" ]; then
  exit 0
fi

# 結果を人間が読みやすいテキストに変換
CONTEXT="[yb-memory] 関連する過去の会話:"
CONTEXT="$CONTEXT"$'\n'

# jqで各結果を整形
FORMATTED=$(echo "$RESULTS" | jq -r '.[] | "---\nQ: \(.question[0:300])\nA: \(.answer[0:500])\n(project: \(.project_path), date: \(.created_at[0:10]))"' 2>/dev/null) || true

if [ -z "$FORMATTED" ]; then
  exit 0
fi

CONTEXT="$CONTEXT$FORMATTED"

# additionalContextとして出力
jq -Rn --arg msg "$CONTEXT" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$msg}}'

exit 0
