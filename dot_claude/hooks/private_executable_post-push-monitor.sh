#!/bin/bash
# post-push-monitor.sh — PostToolUse hook (Bash matcher)
#
# git push成功後にCI/CodeRabbit監視の指示をadditionalContextで返す。
# PRが存在する場合はCronCreate実行の指示を含め、
# PRがない場合はその旨を通知する。

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

# git pushコマンドでなければスキップ
if ! echo "$COMMAND" | grep -qE '\bgit\s+push\b'; then
  exit 0
fi

# push成功判定（exitCodeが0でなければスキップ）
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exitCode // empty' 2>/dev/null)
if [ -n "$EXIT_CODE" ] && [ "$EXIT_CODE" != "0" ]; then
  exit 0
fi

# exitCodeが空の場合もスキップ（push失敗時はスキップ）
if [ -z "$EXIT_CODE" ]; then
  exit 0
fi

# 現在のブランチ取得
BRANCH=$(git branch --show-current 2>/dev/null) || exit 0

if [ -z "$BRANCH" ]; then
  exit 0
fi

# gh未インストール時は基本メッセージのみ
if ! command -v gh &>/dev/null; then
  MSG="push完了。ghコマンドが見つからないため、PR確認をスキップしました。"
  jq -Rn --arg msg "$MSG" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}'
  exit 0
fi

# PR検索
PR_JSON=$(gh pr list --head "$BRANCH" --json number,url --limit 1 2>/dev/null) || exit 0

PR_NUMBER=$(echo "$PR_JSON" | jq -r '.[0].number // empty' 2>/dev/null)

if [ -z "$PR_NUMBER" ]; then
  # PRなし
  MSG="push完了。PRはまだ作成されていません。"
  jq -Rn --arg msg "$MSG" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}'
  exit 0
fi

# owner/repoをリモートURLから抽出
REMOTE_URL=$(git remote get-url origin 2>/dev/null) || exit 0

OWNER=""
REPO=""

# HTTPS形式: https://github.com/{owner}/{repo}.git
if echo "$REMOTE_URL" | grep -qE '^https://'; then
  OWNER=$(echo "$REMOTE_URL" | sed -E 's|^https://github\.com/([^/]+)/([^/.]+)(\.git)?$|\1|')
  REPO=$(echo "$REMOTE_URL" | sed -E 's|^https://github\.com/([^/]+)/([^/.]+)(\.git)?$|\2|')
fi

# SSH形式: git@github.com:{owner}/{repo}.git
if echo "$REMOTE_URL" | grep -qE '^git@'; then
  OWNER=$(echo "$REMOTE_URL" | sed -E 's|^git@github\.com:([^/]+)/([^/.]+)(\.git)?$|\1|')
  REPO=$(echo "$REMOTE_URL" | sed -E 's|^git@github\.com:([^/]+)/([^/.]+)(\.git)?$|\2|')
fi

if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  MSG="push完了。PR #${PR_NUMBER} が存在しますが、リモートURLからowner/repoを抽出できませんでした。"
  jq -Rn --arg msg "$MSG" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}'
  exit 0
fi

# ホームディレクトリ取得
HOME_DIR="${HOME}"

# CI/CodeRabbit監視指示メッセージ生成
MSG="push完了。PR #${PR_NUMBER} のCI/CodeRabbitを監視するため、以下のCronCreateを実行してください:
コマンド: ${HOME_DIR}/.claude/hooks/check-ci-coderabbit.sh ${OWNER} ${REPO} ${PR_NUMBER}
間隔: */1 * * * * (1分間隔)
タイムアウト: 10分後に停止"

# additionalContext形式のJSON出力
jq -Rn --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}'

exit 0
