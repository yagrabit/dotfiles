#!/bin/bash
# quality-gate.sh — PostToolUse hook (Edit|Write matcher)
#
# 編集されたファイルに対して3つの品質チェックを実行する。
# 1. console.log/error/warn の検出（.ts/.tsx/.js/.jsx、テストファイル除外）
# 2. ハードコードされたシークレットパターンの検出（全ファイル）
# 3. 大規模ファイル警告（500行超過）

set -euo pipefail

INPUT=$(cat)

# jq未インストール時は何もしない
if ! command -v jq &>/dev/null; then
  exit 0
fi

# ファイルパス抽出
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# ファイル存在確認
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

WARNINGS=""

# --- チェック1: console.log/error/warn の検出 ---
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx)
    # テストファイルはスキップ
    case "$FILE_PATH" in
      *.test.*|*.spec.*)
        ;;
      *)
        CONSOLE_HITS=$(grep -nE '\bconsole\.(log|error|warn)\b' "$FILE_PATH" 2>/dev/null || true)
        if [ -n "$CONSOLE_HITS" ]; then
          HIT_COUNT=$(echo "$CONSOLE_HITS" | wc -l | tr -d ' ')
          WARNINGS="${WARNINGS}⚠ console文が${HIT_COUNT}箇所検出されました（デバッグコードの消し忘れ注意）\n"
        fi
        ;;
    esac
    ;;
esac

# --- チェック2: ハードコードされたシークレットパターンの検出 ---
SECRET_HITS=$(grep -nEi \
  '(API_KEY|API_SECRET|SECRET_KEY|PRIVATE_KEY|PASSWORD|PASSWD)\s*=\s*["\x27][^"\x27]+["\x27]' \
  "$FILE_PATH" 2>/dev/null || true)

# トークンパターン（sk-*, ghp_*, gho_*, github_pat_*, xoxb-*, xoxp-*）
TOKEN_HITS=$(grep -noE \
  '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36,}|gho_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{20,}|xox[bp]-[A-Za-z0-9\-]{20,})' \
  "$FILE_PATH" 2>/dev/null || true)

if [ -n "$SECRET_HITS" ] || [ -n "$TOKEN_HITS" ]; then
  WARNINGS="${WARNINGS}🔑 シークレットらしき値がハードコードされています。環境変数への移行を検討してください\n"
fi

# --- チェック3: 大規模ファイル警告 ---
LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null | tr -d ' ') || LINE_COUNT=0

if [ "$LINE_COUNT" -gt 500 ] 2>/dev/null; then
  WARNINGS="${WARNINGS}📏 ファイルが${LINE_COUNT}行あります（500行超過）。分割を検討してください\n"
fi

# --- 警告がある場合のみJSON出力 ---
if [ -n "$WARNINGS" ]; then
  # 末尾の改行を除去
  MSG=$(printf "%b" "$WARNINGS" | sed '$ s/\\n$//' | tr '\n' ' ' | sed 's/ $//')

  jq -Rn --arg msg "$MSG" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}'
fi

exit 0
