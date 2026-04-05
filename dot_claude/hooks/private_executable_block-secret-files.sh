#!/bin/bash
# block-secret-files.sh — PreToolUse hook for Claude Code
#
# Readツールで秘密情報ファイルの読み込みをブロックする。
# セキュリティルールの「.envをコミットしない」等を実行時に強制する。
#
# ブロック対象:
#   .env, .env.* (.env.local, .env.production 等)
#   *.pem, *.key, *.p12, *.pfx (秘密鍵・証明書)
#   *.secret, *.secrets
#   id_rsa, id_ed25519, id_ecdsa, id_dsa (SSH秘密鍵)
#   credentials, credentials.json, .netrc
#   *.token

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# ブロック対象パターンに一致するか確認
BLOCKED=false

# .env および .env.*
if [[ "$BASENAME" == ".env" ]] || [[ "$BASENAME" == .env.* ]]; then
  BLOCKED=true
fi

# 秘密鍵・証明書
if [[ "$BASENAME" == *.pem ]] || [[ "$BASENAME" == *.key ]] || \
   [[ "$BASENAME" == *.p12 ]] || [[ "$BASENAME" == *.pfx ]]; then
  BLOCKED=true
fi

# シークレットファイル
if [[ "$BASENAME" == *.secret ]] || [[ "$BASENAME" == *.secrets ]]; then
  BLOCKED=true
fi

# SSH秘密鍵
if [[ "$BASENAME" == "id_rsa" ]] || [[ "$BASENAME" == "id_ed25519" ]] || \
   [[ "$BASENAME" == "id_ecdsa" ]] || [[ "$BASENAME" == "id_dsa" ]]; then
  BLOCKED=true
fi

# 認証情報ファイル
if [[ "$BASENAME" == "credentials" ]] || [[ "$BASENAME" == "credentials.json" ]] || \
   [[ "$BASENAME" == ".netrc" ]]; then
  BLOCKED=true
fi

# トークンファイル
if [[ "$BASENAME" == *.token ]]; then
  BLOCKED=true
fi

if [[ "$BLOCKED" == "true" ]]; then
  echo "BLOCKED: 秘密情報ファイルの読み込みをブロックしました: $FILE_PATH"
  echo "内容を共有する必要がある場合は、必要な値だけを直接会話に貼り付けてください。"
  exit 2
fi

exit 0
