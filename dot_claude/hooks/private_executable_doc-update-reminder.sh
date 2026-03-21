#!/bin/bash
# doc-update-reminder.sh — PostToolUse hook (Bash matcher)
#
# git commit後にソースコード変更がありながらドキュメント更新がない場合、
# additionalContextでリマインドする。

set -euo pipefail

INPUT=$(cat)

# jq未インストール時は何もしない
if ! command -v jq &>/dev/null; then
  exit 0
fi

# コマンド抽出
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0

if [ -z "$COMMAND" ]; then
  exit 0
fi

# git commitコマンドでなければスキップ
# チェインコマンド（git add . && git commit）にも対応するため行頭アンカーなし
if ! echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

# コミット成功判定
# 1. tool_resultのexitCodeが0か確認（利用可能な場合）
# 2. フォールバック: HEADコミットが60秒以内か確認
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exitCode // empty' 2>/dev/null)
if [ -n "$EXIT_CODE" ] && [ "$EXIT_CODE" != "0" ]; then
  exit 0
fi

if [ -z "$EXIT_CODE" ]; then
  COMMIT_EPOCH=$(git log -1 --format='%ct' HEAD 2>/dev/null) || exit 0
  NOW_EPOCH=$(date +%s)
  ELAPSED=$(( NOW_EPOCH - COMMIT_EPOCH ))
  if [ "$ELAPSED" -gt 60 ]; then
    exit 0
  fi
fi

# 変更ファイル一覧取得
# 注: マージコミットでは最初の親との差分のみ返すため、変更が空になることがある（安全側）
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null) || exit 0

if [ -z "$CHANGED_FILES" ]; then
  exit 0
fi

# ソースコードディレクトリ配下のファイルを抽出
# 除外: ロックファイル、テストファイル、自動生成ファイル
SOURCE_FILES=""
while IFS= read -r file; do
  # ソースコードディレクトリ配下か判定
  case "$file" in
    src/*|lib/*|app/*|pages/*|components/*|modules/*|packages/*)
      ;;
    *)
      continue
      ;;
  esac

  # ロックファイルを除外
  case "$file" in
    *lock*|*.lock)
      continue
      ;;
  esac

  # テストファイル・テストディレクトリを除外
  case "$file" in
    *.test.*|*.spec.*|*__tests__/*|*test/*|*tests/*)
      continue
      ;;
  esac

  # 自動生成ファイルを除外
  case "$file" in
    *.generated.*|*.min.*)
      continue
      ;;
  esac

  # ソースコード変更として記録
  if [ -z "$SOURCE_FILES" ]; then
    SOURCE_FILES="$file"
  else
    SOURCE_FILES="$SOURCE_FILES"$'\n'"$file"
  fi
done <<< "$CHANGED_FILES"

# ソースコード変更がなければスキップ
if [ -z "$SOURCE_FILES" ]; then
  exit 0
fi

# ドキュメント同時更新チェック
# README*, CLAUDE.md, docs/ 配下が含まれていれば更新済みとみなす
while IFS= read -r file; do
  case "$file" in
    README*|CHANGELOG*|CLAUDE.md|*/CLAUDE.md|docs/*)
      # ドキュメントが同時に更新されている
      exit 0
      ;;
  esac
done <<< "$CHANGED_FILES"

# プロジェクトルート取得
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# リマインド対象のドキュメント候補を収集
DOC_SUGGESTIONS=""

if [ -f "${PROJECT_ROOT}/README.md" ]; then
  DOC_SUGGESTIONS="${DOC_SUGGESTIONS}"$'\n'"- README.mdの更新（/update-readme で実行可能）"
fi

if [ -f "${PROJECT_ROOT}/CLAUDE.md" ]; then
  DOC_SUGGESTIONS="${DOC_SUGGESTIONS}"$'\n'"- CLAUDE.mdの更新"
fi

if [ -d "${PROJECT_ROOT}/docs" ]; then
  DOC_SUGGESTIONS="${DOC_SUGGESTIONS}"$'\n'"- docs/ 配下のドキュメント更新"
fi

# いずれのドキュメントも存在しなければリマインド不要
if [ -z "$DOC_SUGGESTIONS" ]; then
  exit 0
fi

# ソースコード変更ファイル一覧（上位10件）
FILE_LIST=$(echo "$SOURCE_FILES" | head -10 | sed 's/^/- /')
TOTAL_COUNT=$(echo "$SOURCE_FILES" | wc -l | tr -d ' ')

if [ "$TOTAL_COUNT" -gt 10 ]; then
  FILE_LIST="${FILE_LIST}"$'\n'"  ...他 $(( TOTAL_COUNT - 10 )) ファイル"
fi

# リマインドメッセージ生成
MSG="ドキュメント更新リマインド:
このコミットにソースコード変更が含まれていますが、ドキュメントの更新がありません。

変更ファイル:
${FILE_LIST}

必要に応じて以下を検討してください:${DOC_SUGGESTIONS}
不要であればそのまま続行してください。"

# additionalContext形式のJSON出力
jq -Rn --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}'

exit 0
