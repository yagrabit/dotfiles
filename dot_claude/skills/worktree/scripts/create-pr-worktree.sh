#!/usr/bin/env bash
# PRのURLまたはPR番号を受け取り、そのPRのブランチでgit worktreeを作成する
set -euo pipefail

# ログ出力（標準エラー出力）
log() {
  echo "[create-pr-worktree] $*" >&2
}

# エラー出力して終了
die() {
  echo "[create-pr-worktree] エラー: $*" >&2
  exit 1
}

# --- 引数チェック ---
if [[ $# -lt 1 ]]; then
  die "引数が必要です。PR URLまたはPR番号を指定してください。
使い方: $0 <PR_URL または PR番号>
例: $0 https://github.com/owner/repo/pull/123
例: $0 123"
fi

# --- ghコマンドの存在チェック ---
if ! command -v gh &>/dev/null; then
  die "ghコマンドが見つかりません。GitHub CLIをインストールしてください。"
fi

# --- PR番号の抽出 ---
input="$1"
if [[ "$input" =~ /pull/([0-9]+) ]]; then
  # URLからPR番号を抽出
  pr_number="${BASH_REMATCH[1]}"
  log "URLからPR番号を抽出しました: #${pr_number}"
elif [[ "$input" =~ ^[0-9]+$ ]]; then
  # 数値のみの場合はそのままPR番号として使用
  pr_number="$input"
else
  die "無効な入力です。PR URLまたはPR番号を指定してください: $input"
fi

# --- リポジトリルートの取得 ---
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "gitリポジトリ内で実行してください。"
log "リポジトリルート: ${repo_root}"

# --- PRのブランチ名を取得 ---
log "PR #${pr_number} の情報を取得中..."
branch_name="$(gh pr view "$pr_number" --json headRefName --jq '.headRefName' 2>&1)" || die "PR #${pr_number} の情報取得に失敗しました:\n${branch_name}"
if [[ -z "$branch_name" ]]; then
  die "PR #${pr_number} のブランチ名が取得できませんでした。"
fi
log "ブランチ名: ${branch_name}"

# --- worktreeの作成先パスを決定 ---
worktree_path="${repo_root}/.claude/worktrees/pr-${pr_number}"

# --- 既にworktreeが存在する場合は既存パスを返す ---
if [[ -d "$worktree_path" ]]; then
  log "worktreeは既に存在します: ${worktree_path}"
  echo "$worktree_path"
  exit 0
fi

# --- リモートからブランチをfetch ---
log "リモートからブランチをfetch中: origin/${branch_name}"
git fetch origin "$branch_name" 2>&1 | while IFS= read -r line; do log "$line"; done || die "ブランチのfetchに失敗しました: origin/${branch_name}"

# --- worktreeを作成 ---
log "worktreeを作成中: ${worktree_path}"
git worktree add "$worktree_path" -b "pr-${pr_number}" "origin/${branch_name}" 2>&1 | while IFS= read -r line; do log "$line"; done || die "worktreeの作成に失敗しました。"

log "worktreeの作成が完了しました。"

# --- 標準出力にworktreeパスのみを出力 ---
echo "$worktree_path"
