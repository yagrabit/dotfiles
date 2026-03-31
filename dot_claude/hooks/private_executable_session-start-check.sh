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

# yb-memoryの自動インストール・自動更新
if command -v uv &>/dev/null && [ -d "$HOME/.claude/tools/yb-memory" ]; then
  YBM_STAMP="$HOME/.local/share/yb-memory/installed-version.txt"
  YBM_SRC_VER=$(grep '^version' "$HOME/.claude/tools/yb-memory/pyproject.toml" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || echo "")
  YBM_INST_VER=$(cat "$YBM_STAMP" 2>/dev/null || echo "")

  if ! command -v yb-memory &>/dev/null; then
    # 未インストール: 新規インストール
    uv tool install --from "$HOME/.claude/tools/yb-memory" yb-memory 2>/dev/null || true
    mkdir -p "$(dirname "$YBM_STAMP")"
    echo "$YBM_SRC_VER" > "$YBM_STAMP"
    MSG="${MSG}"$'\n'"✓ yb-memory: 自動インストール実行 (v${YBM_SRC_VER})"
  elif [ -n "$YBM_SRC_VER" ] && [ "$YBM_SRC_VER" != "$YBM_INST_VER" ]; then
    # バージョン不一致: 自動更新
    uv tool install --reinstall --force --from "$HOME/.claude/tools/yb-memory" yb-memory 2>/dev/null || true
    mkdir -p "$(dirname "$YBM_STAMP")"
    echo "$YBM_SRC_VER" > "$YBM_STAMP"
    MSG="${MSG}"$'\n'"✓ yb-memory: 自動更新 v${YBM_INST_VER} → v${YBM_SRC_VER}"
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
# 5. 成果物の鮮度チェック
# ---------------------------------------------------------------------------
ARTIFACTS_DIR=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  ARTIFACTS_DIR="${GIT_ROOT}/.claude/artifacts"
fi

if [ -n "$ARTIFACTS_DIR" ] && [ -d "$ARTIFACTS_DIR" ]; then
  STALE_COUNT=$(find "$ARTIFACTS_DIR" -maxdepth 1 -type f -mtime +14 2>/dev/null | wc -l | tr -d ' ') || STALE_COUNT=0
  if [ "$STALE_COUNT" -gt 0 ]; then
    MSG="${MSG}"$'\n'"---"$'\n'"ガーデニング提案: ${STALE_COUNT}個の成果物が14日以上更新されていません。不要な成果物の整理を検討してください。"
  fi
fi

# ---------------------------------------------------------------------------
# 6. additionalContext形式のJSON出力
# ---------------------------------------------------------------------------
jq -Rn --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$msg}}'

exit 0
