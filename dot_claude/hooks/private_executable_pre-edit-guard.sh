#!/usr/bin/env bash
# PreToolUseフック: lint設定・hooks・CI設定の改竄をブロックする
# Write/Edit操作がガード対象のファイルに向けられた場合にブロックし、
# 設定ファイルの意図しない変更を防止する
set -euo pipefail

# jqが未インストールの場合はスキップ（安全側に倒す）
if ! command -v jq &>/dev/null; then
  exit 0
fi

# stdinからツール入力のJSONを読み取る
input="$(cat)"

# .tool_input.file_path を抽出
file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty')"

# ファイルパスが空ならスキップ
if [[ -z "$file_path" ]]; then
  exit 0
fi

# dotfilesリポジトリ内のchezmoi管理ファイル（dot_claude/）は除外
# chezmoiのソースファイルは直接デプロイされるファイルとは異なるため、編集を許可する
case "$file_path" in
  */dot_claude/*)
    exit 0
    ;;
esac

# ガード対象パターンのチェック（case文でパターンマッチング）
case "$file_path" in
  # Claude Code hooks/設定
  */.claude/hooks/*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */.claude/settings.json*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */.claude/settings.local.json*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  # lint/format設定
  */biome.json)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */.eslintrc*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */eslint.config.*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */.prettierrc*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */prettier.config.*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */.stylelintrc*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  # CI/CD設定
  */.github/workflows/*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */.gitlab-ci.yml)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  # git hooks
  */.hooks/*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */.husky/*)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */.lefthook.yml)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
  */lefthook.yml)
    echo "ブロック: ${file_path} はガード対象ファイルです。この変更が本当に必要な場合はユーザーに確認してください。" >&2
    exit 2
    ;;
esac

# ガード対象外のファイルは通過
exit 0
