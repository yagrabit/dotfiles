#!/bin/bash
# git-push-reminder.sh — PreToolUse hook (Bash matcher)
#
# git pushコマンドを検出してstderrに警告を表示する。
# force pushの場合は特に強い警告を出す。
# ブロックはしない（permissionDecisionは出力しない）。

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

# git push を含むか判定
if ! echo "$COMMAND" | grep -q 'git push'; then
  exit 0
fi

# force push の検出（-f, --force, --force-with-lease）
if echo "$COMMAND" | grep -qE '(^|[[:space:]])(--force-with-lease|--force|-f)([[:space:]]|$)'; then
  echo "============================================" >&2
  echo "  [警告] force push が検出されました！" >&2
  echo "  リモートの履歴が上書きされる可能性があります。" >&2
  echo "  共有ブランチへのforce pushは特に注意してください。" >&2
  echo "============================================" >&2
else
  echo "[注意] git push を実行します。プッシュ先のブランチを確認してください。" >&2
fi

exit 0
