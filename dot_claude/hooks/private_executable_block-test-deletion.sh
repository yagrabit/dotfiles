#!/usr/bin/env bash
# PreToolUseフック: AIによるテストファイル・テストコードの削除をブロック
# 根拠: CodeScene調査でAIがテストを削除してテストを通す傾向が確認されている
set -euo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // empty')"

# テストファイルパターン
test_file_pattern='(\.(test|spec)\.[a-zA-Z]+|__tests__/|/tests?/)'

# --- Bashツール: rm / git rm によるテストファイル削除をブロック ---
if [[ "$tool_name" == "Bash" ]]; then
  command="$(echo "$input" | jq -r '.tool_input.command // empty')"
  [[ -z "$command" ]] && exit 0

  if echo "$command" | grep -qE '(^|\s|;|&&|\|\|)\s*(rm|git\s+rm)\s' && \
     echo "$command" | grep -qE "$test_file_pattern"; then
    echo "ブロック: テストファイルの削除は禁止されています。テストが失敗する場合はテストコードを修正してください。" >&2
    exit 2
  fi
  exit 0
fi

# --- Editツール: テストコード（アサーション）の削除をブロック ---
if [[ "$tool_name" == "Edit" ]]; then
  file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty')"
  [[ -z "$file_path" ]] && exit 0

  # テストファイルでなければスキップ
  echo "$file_path" | grep -qE "$test_file_pattern" || exit 0

  old_string="$(echo "$input" | jq -r '.tool_input.old_string // empty')"
  new_string="$(echo "$input" | jq -r '.tool_input.new_string // empty')"
  [[ -z "$old_string" ]] && exit 0

  # テスト・アサーション関連パターン
  assertion_pattern='\b(it|test|describe|expect|assert|cy)\s*[\.(]|\.(should|toBe|toEqual|toHaveBeenCalled|toThrow|toMatch|toContain)\s*\('

  # old_stringにアサーションがなければスキップ
  echo "$old_string" | grep -qE "$assertion_pattern" || exit 0

  # new_stringが空 = テストコードの純粋な削除
  if [[ -z "$new_string" ]]; then
    echo "ブロック: テストコード（アサーション文）の削除は禁止されています。テストが失敗する場合はテストコードを修正してください。" >&2
    exit 2
  fi

  # new_stringにもアサーションがあれば書き換え（リファクタリング）として許可
  echo "$new_string" | grep -qE "$assertion_pattern" && exit 0

  # old_stringにアサーションがあるのにnew_stringにない = テストの削除
  echo "ブロック: テストコード（アサーション文）を非テストコードに置き換えることは禁止されています。テストが失敗する場合はテストコードを修正してください。" >&2
  exit 2
fi

exit 0
