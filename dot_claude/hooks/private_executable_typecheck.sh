#!/bin/bash
# typecheck.sh — PostToolUse hook (Edit|Write matcher)
#
# TypeScriptファイル(.ts, .tsx)の型チェックを実行する。
# tsconfig.jsonを上方向に探索し、tscでチェック後、
# 編集ファイルに関連するエラーのみ抽出して表示する。

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

# .ts, .tsx のみ対象（.d.ts は除外）
case "$FILE_PATH" in
  *.d.ts)
    exit 0
    ;;
  *.ts|*.tsx)
    ;;
  *)
    exit 0
    ;;
esac

# ファイル存在確認
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# tsconfig.json を上方向に探索
SEARCH_DIR=$(dirname "$FILE_PATH")
TSCONFIG_DIR=""
DEPTH=0

while [ "$DEPTH" -lt 20 ]; do
  if [ -f "${SEARCH_DIR}/tsconfig.json" ]; then
    TSCONFIG_DIR="$SEARCH_DIR"
    break
  fi
  # ルートに到達したら終了
  if [ "$SEARCH_DIR" = "/" ]; then
    break
  fi
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
  DEPTH=$((DEPTH + 1))
done

# tsconfig.json が見つからなければ終了
if [ -z "$TSCONFIG_DIR" ]; then
  exit 0
fi

# tscパス解決
if [ -x "${TSCONFIG_DIR}/node_modules/.bin/tsc" ]; then
  TSC_CMD="${TSCONFIG_DIR}/node_modules/.bin/tsc"
else
  TSC_CMD="npx tsc"
fi

# 型チェック実行（30秒タイムアウト）
TSC_OUTPUT=$(cd "$TSCONFIG_DIR" && timeout 30 $TSC_CMD --noEmit --pretty false 2>&1) || true

if [ -z "$TSC_OUTPUT" ]; then
  exit 0
fi

# 編集ファイルに関連する行のみ抽出
# 絶対パスと相対パス（tsconfig.jsonディレクトリ基準）の両方でマッチ
ABS_PATH="$FILE_PATH"
# macOS互換: realpath --relative-to は coreutils 版が必要なため python3 でフォールバック
REL_PATH=$(realpath --relative-to="$TSCONFIG_DIR" "$FILE_PATH" 2>/dev/null \
  || python3 -c "import os; print(os.path.relpath('$ABS_PATH', '$TSCONFIG_DIR'))" 2>/dev/null \
  || echo "$FILE_PATH")

# grepのパターンとしてパス区切り文字等をエスケープ
ESCAPED_ABS=$(printf '%s' "$ABS_PATH" | sed 's/[.[\*^$()+?{}|]/\\&/g')
ESCAPED_REL=$(printf '%s' "$REL_PATH" | sed 's/[.[\*^$()+?{}|]/\\&/g')
FILTERED=$(echo "$TSC_OUTPUT" | grep -E "(${ESCAPED_ABS}|${ESCAPED_REL})" 2>/dev/null || true)

if [ -z "$FILTERED" ]; then
  exit 0
fi

# 最大10行に制限
FILTERED=$(echo "$FILTERED" | head -n 10)

# additionalContext JSON を出力
CONTEXT=$(printf "型エラー:\n%s" "$FILTERED")
jq -Rn --arg ctx "$CONTEXT" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'

exit 0
