#!/bin/bash
# session-start-check.sh — SessionStart hook
#
# セッション開始時に環境チェックを実行し、additionalContextで結果を返す。
# ブロックしない（常に exit 0）。情報提供のみ。

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

MSG=""

# ---------------------------------------------------------------------------
# 1. 必須ツール確認（バージョン取得）
# ---------------------------------------------------------------------------
TOOLS_MSG="環境チェック結果:"

# git
if command -v git &>/dev/null; then
  GIT_VER=$(git --version 2>/dev/null | sed 's/git version //' || echo "取得失敗")
  TOOLS_MSG="${TOOLS_MSG}"$'\n'"✓ git: ${GIT_VER}"
else
  TOOLS_MSG="${TOOLS_MSG}"$'\n'"⚠ git: 未インストール"
fi

# gh
if command -v gh &>/dev/null; then
  GH_VER=$(gh --version 2>/dev/null | head -1 | sed 's/gh version //' | sed 's/ .*//' || echo "取得失敗")
else
  GH_VER=""
fi

# jq（ここに到達している時点でインストール済み）
JQ_VER=$(jq --version 2>/dev/null || echo "取得失敗")
TOOLS_MSG="${TOOLS_MSG}"$'\n'"✓ jq: ${JQ_VER}"

# ---------------------------------------------------------------------------
# 2. gh認証状態確認
# ---------------------------------------------------------------------------
if [ -n "$GH_VER" ]; then
  _timeout 5 gh auth status &>/dev/null && GH_AUTH_RC=0 || GH_AUTH_RC=$?

  if [ "$GH_AUTH_RC" -eq 0 ]; then
    TOOLS_MSG="${TOOLS_MSG}"$'\n'"✓ gh: ${GH_VER} (認証済み)"
  elif [ "$GH_AUTH_RC" -eq 124 ]; then
    # timeout によるタイムアウト
    TOOLS_MSG="${TOOLS_MSG}"$'\n'"⚠ gh: ${GH_VER} (認証確認タイムアウト)"
  else
    TOOLS_MSG="${TOOLS_MSG}"$'\n'"⚠ gh: ${GH_VER} (未認証)"
  fi
else
  TOOLS_MSG="${TOOLS_MSG}"$'\n'"⚠ gh: 未インストール"
fi

MSG="${TOOLS_MSG}"

# yb-memoryの自動インストール
if command -v uv &>/dev/null && ! command -v yb-memory &>/dev/null; then
  if [ -d "$HOME/.claude/tools/yb-memory" ]; then
    uv tool install --from "$HOME/.claude/tools/yb-memory" yb-memory 2>/dev/null || true
    MSG="${MSG}"$'\n'"✓ yb-memory: 自動インストール実行"
  fi
fi

# yb-memory daemonの自動起動
if command -v yb-memory &>/dev/null; then
  if ! yb-memory ping &>/dev/null; then
    yb-memory serve --daemon 2>/dev/null || true
    MSG="${MSG}"$'\n'"✓ yb-memory: daemon起動"
  fi
fi

# ---------------------------------------------------------------------------
# 3. gitリポジトリ内の場合のみリポジトリ情報を収集
# ---------------------------------------------------------------------------
if git rev-parse --is-inside-work-tree &>/dev/null; then
  REPO_MSG=""

  # 現在のブランチ
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "不明")
  BRANCH_INFO="ブランチ: ${CURRENT_BRANCH}"

  # リモートとの差分
  UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || UPSTREAM=""
  if [ -n "$UPSTREAM" ]; then
    COUNTS=$(git rev-list --left-right --count "${UPSTREAM}...HEAD" 2>/dev/null) || COUNTS=""
    if [ -n "$COUNTS" ]; then
      BEHIND=$(echo "$COUNTS" | awk '{print $1}' 2>/dev/null) || BEHIND="?"
      AHEAD=$(echo "$COUNTS" | awk '{print $2}' 2>/dev/null) || AHEAD="?"
      BRANCH_INFO="${BRANCH_INFO} (${AHEAD} ahead, ${BEHIND} behind)"
    fi
  else
    BRANCH_INFO="${BRANCH_INFO} (upstreamなし)"
  fi

  REPO_MSG="${BRANCH_INFO}"

  # 未コミット変更
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null) || UNCOMMITTED="?"
  if [ "$UNCOMMITTED" -gt 0 ]; then
    REPO_MSG="${REPO_MSG}"$'\n'"未コミット変更: ${UNCOMMITTED}ファイル"
  else
    REPO_MSG="${REPO_MSG}"$'\n'"未コミット変更: なし"
  fi

  MSG="${MSG}"$'\n'"---"$'\n'"${REPO_MSG}"
fi

# ---------------------------------------------------------------------------
# 4. フラグファイルクリーンアップ
# ---------------------------------------------------------------------------
CLEANUP_COUNT=0
if [ -d "/tmp/claude-sessions" ]; then
  # 削除対象のファイル数を事前カウント
  CLEANUP_COUNT=$(find /tmp/claude-sessions/ -name "review-passed-*" -mtime +0 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null) || CLEANUP_COUNT=0
  # 24時間以上前のフラグファイルを削除
  find /tmp/claude-sessions/ -name "review-passed-*" -mtime +0 -delete 2>/dev/null || true
fi

if [ "$CLEANUP_COUNT" -gt 0 ]; then
  MSG="${MSG}"$'\n'"---"$'\n'"クリーンアップ: 古いフラグファイル ${CLEANUP_COUNT}件削除"
fi

# ---------------------------------------------------------------------------
# 5. additionalContext形式のJSON出力
# ---------------------------------------------------------------------------
jq -Rn --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$msg}}'

exit 0
