#!/bin/bash
# auto-format.sh — PostToolUse hook (Edit|Write matcher)
#
# 編集されたファイルを自動フォーマットする。
# 対応拡張子: .ts, .tsx, .js, .jsx, .css, .scss, .json
# 対応フォーマッター: Biome, Prettier（プロジェクト内の設定を自動検出）

set -euo pipefail

INPUT=$(cat)

# jq未インストール時は何もしない
if ! command -v jq &>/dev/null; then
  exit 0
fi

# macOS互換のtimeout関数
_timeout() {
  local duration="$1"
  shift
  if command -v timeout &>/dev/null; then
    timeout "$duration" "$@"
  elif command -v gtimeout &>/dev/null; then
    gtimeout "$duration" "$@"
  else
    # timeout/gtimeoutがない場合はそのまま実行（タイムアウトなし）
    "$@"
  fi
}

# ファイルパス抽出
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 拡張子チェック（対象: .ts, .tsx, .js, .jsx, .css, .scss, .json）
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.css|*.scss|*.json)
    ;;
  *)
    exit 0
    ;;
esac

# ファイル存在確認
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# gitルート検出
GIT_ROOT=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null) || exit 0

# フォーマッター検出（gitルート基準）
FORMATTER=""
FORMATTER_CMD=""

if [ -f "${GIT_ROOT}/biome.json" ] || [ -f "${GIT_ROOT}/biome.jsonc" ]; then
  # Biome検出
  FORMATTER="biome"
  if [ -x "${GIT_ROOT}/node_modules/.bin/biome" ]; then
    FORMATTER_CMD="${GIT_ROOT}/node_modules/.bin/biome check --write"
  else
    FORMATTER_CMD="npx biome check --write"
  fi
elif [ -f "${GIT_ROOT}/.prettierrc" ] || \
     [ -f "${GIT_ROOT}/.prettierrc.json" ] || \
     [ -f "${GIT_ROOT}/.prettierrc.yml" ] || \
     [ -f "${GIT_ROOT}/.prettierrc.yaml" ] || \
     [ -f "${GIT_ROOT}/prettier.config.js" ] || \
     [ -f "${GIT_ROOT}/prettier.config.mjs" ] || \
     [ -f "${GIT_ROOT}/prettier.config.cjs" ]; then
  # Prettier検出
  FORMATTER="prettier"
  if [ -x "${GIT_ROOT}/node_modules/.bin/prettier" ]; then
    FORMATTER_CMD="${GIT_ROOT}/node_modules/.bin/prettier --write"
  else
    FORMATTER_CMD="npx prettier --write"
  fi
else
  # フォーマッター設定なし
  exit 0
fi

# フォーマット前のハッシュを記録（変更検出用）
HASH_BEFORE=$(md5 -q "$FILE_PATH" 2>/dev/null || md5sum "$FILE_PATH" 2>/dev/null | cut -d' ' -f1 || true)

# フォーマット実行（15秒タイムアウト）
_timeout 15 ${FORMATTER_CMD} "$FILE_PATH" 2>/dev/null || true

# フォーマット後のハッシュを取得
HASH_AFTER=$(md5 -q "$FILE_PATH" 2>/dev/null || md5sum "$FILE_PATH" 2>/dev/null | cut -d' ' -f1 || true)

# 変更があった場合のみ additionalContext JSON を出力
if [ -n "$HASH_BEFORE" ] && [ -n "$HASH_AFTER" ] && [ "$HASH_BEFORE" != "$HASH_AFTER" ]; then
  # macOS互換: realpath --relative-to は coreutils 版が必要なため python3 でフォールバック
  REL_PATH=$(realpath --relative-to="$GIT_ROOT" "$FILE_PATH" 2>/dev/null \
    || python3 -c "import os; print(os.path.relpath('$FILE_PATH', '$GIT_ROOT'))" 2>/dev/null \
    || echo "$FILE_PATH")

  MSG="自動フォーマット適用済み: ${REL_PATH} (${FORMATTER})"

  # jqで安全にJSONエスケープして出力
  jq -Rn --arg msg "$MSG" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}'
fi

exit 0
