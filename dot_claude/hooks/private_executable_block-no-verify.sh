#!/usr/bin/env bash
# PreToolUseフック: git commit --no-verify をブロックする
# プリコミットフックのバイパスを防止し、コード品質を保つ
set -euo pipefail

# jqが未インストールの場合はスキップ（安全側に倒す）
if ! command -v jq &>/dev/null; then
  exit 0
fi

# stdinからツール入力のJSONを読み取る
input="$(cat)"

# .tool_input.command を抽出
command="$(echo "$input" | jq -r '.tool_input.command // empty')"

# コマンドが空ならスキップ
if [[ -z "$command" ]]; then
  exit 0
fi

# git commit に --no-verify または -n（短縮形）が含まれるか検出
# パターン:
#   - git commit --no-verify
#   - git commit -n
#   - 他のフラグと混在するケース（例: git commit -m "msg" --no-verify）
if echo "$command" | grep -qE '^\s*git\s+commit\b' && \
   echo "$command" | grep -qE '(^|\s)--no-verify(\s|$)|(^|\s)-[a-mo-zA-Z]*n[a-zA-Z]*(\s|$)'; then
  echo "ブロック: --no-verify はプリコミットフックをバイパスするため禁止されています。コードを修正してフックを通してください。" >&2
  exit 2
fi

# ブロック対象外のコマンドは通過
exit 0
