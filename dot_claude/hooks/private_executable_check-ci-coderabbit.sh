#!/bin/bash
# check-ci-coderabbit.sh — CronCreateから呼び出されるCI/CodeRabbit状態確認スクリプト
#
# 引数: $1=owner $2=repo $3=pr_number
# PRのCI check runsとCodeRabbitコメントの状態を確認し、
# 結果をJSON形式でstdoutに出力する。

set -euo pipefail

# 引数チェック（3つ必要）
if [ $# -ne 3 ]; then
  echo '{"status":"error","summary":"引数が不足しています。使用法: check-ci-coderabbit.sh <owner> <repo> <pr_number>"}' 2>/dev/null
  exit 0
fi

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# gh未インストール時は何もしない
if ! command -v gh &>/dev/null; then
  echo '{"status":"error","summary":"ghコマンドが見つかりません"}' 2>/dev/null
  exit 0
fi

# jq未インストール時は何もしない
if ! command -v jq &>/dev/null; then
  echo '{"status":"error","summary":"jqコマンドが見つかりません"}' 2>/dev/null
  exit 0
fi

# PRのHEADコミットSHA取得
HEAD_SHA=$(gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}" --jq '.head.sha' 2>/dev/null) || {
  echo '{"status":"error","summary":"PR情報の取得に失敗しました"}' 2>/dev/null
  exit 0
}

if [ -z "$HEAD_SHA" ]; then
  echo '{"status":"error","summary":"HEADコミットSHAを取得できませんでした"}' 2>/dev/null
  exit 0
fi

# CI check runs取得
CHECK_RUNS_JSON=$(gh api "repos/${OWNER}/${REPO}/commits/${HEAD_SHA}/check-runs" --jq '.check_runs' 2>/dev/null) || {
  echo '{"status":"error","summary":"CI check runsの取得に失敗しました"}' 2>/dev/null
  exit 0
}

# CI状態集計
CI_TOTAL=$(echo "$CHECK_RUNS_JSON" | jq 'length' 2>/dev/null) || CI_TOTAL=0
CI_PASSED=$(echo "$CHECK_RUNS_JSON" | jq '[.[] | select(.status == "completed" and (.conclusion == "success" or .conclusion == "neutral" or .conclusion == "skipped"))] | length' 2>/dev/null) || CI_PASSED=0
CI_FAILED=$(echo "$CHECK_RUNS_JSON" | jq '[.[] | select(.status == "completed" and (.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out"))] | length' 2>/dev/null) || CI_FAILED=0
CI_PENDING=$(echo "$CHECK_RUNS_JSON" | jq '[.[] | select(.status == "queued" or .status == "in_progress")] | length' 2>/dev/null) || CI_PENDING=0

# CI全体ステータス判定
CI_STATUS="pending"
if [ "$CI_TOTAL" -eq 0 ]; then
  CI_STATUS="pending"
elif [ "$CI_FAILED" -gt 0 ]; then
  CI_STATUS="failed"
elif [ "$CI_PENDING" -gt 0 ]; then
  CI_STATUS="pending"
elif [ "$CI_PASSED" -eq "$CI_TOTAL" ]; then
  CI_STATUS="completed"
fi

# CodeRabbitコメント取得
CODERABBIT_COMMENTS=$(gh api "repos/${OWNER}/${REPO}/issues/${PR_NUMBER}/comments" --jq '[.[] | select(.user.login == "coderabbitai[bot]")]' 2>/dev/null) || {
  CODERABBIT_COMMENTS="[]"
}

CODERABBIT_COUNT=$(echo "$CODERABBIT_COMMENTS" | jq 'length' 2>/dev/null) || CODERABBIT_COUNT=0
HAS_CODERABBIT=false
if [ "$CODERABBIT_COUNT" -gt 0 ]; then
  HAS_CODERABBIT=true
fi

# CodeRabbitがリポジトリに設定されているか判定
# check runsにCodeRabbitのものがあるか、または過去にCodeRabbitコメントがあるかで判定
CODERABBIT_INSTALLED=false
CODERABBIT_CHECK=$(echo "$CHECK_RUNS_JSON" | jq '[.[] | select(.app.slug == "coderabbitai" or (.name | test("coderabbit"; "i")))] | length' 2>/dev/null) || CODERABBIT_CHECK=0
if [ "$CODERABBIT_CHECK" -gt 0 ] || [ "$CODERABBIT_COUNT" -gt 0 ]; then
  CODERABBIT_INSTALLED=true
fi

# 全体ステータス判定
OVERALL_STATUS="pending"
if [ "$CI_STATUS" = "failed" ]; then
  OVERALL_STATUS="failed"
elif [ "$CI_STATUS" = "completed" ] && [ "$CODERABBIT_INSTALLED" = "false" ]; then
  # CodeRabbit未導入: CI通過だけで完了
  OVERALL_STATUS="completed"
elif [ "$CI_STATUS" = "completed" ] && [ "$HAS_CODERABBIT" = "true" ]; then
  # CodeRabbit導入済み + コメントあり: 完了
  OVERALL_STATUS="completed"
elif [ "$CI_STATUS" = "completed" ] && [ "$CODERABBIT_INSTALLED" = "true" ] && [ "$HAS_CODERABBIT" = "false" ]; then
  # CodeRabbit導入済み + まだコメントなし: 待機中
  OVERALL_STATUS="pending"
fi

# サマリー文字列生成
CI_SUMMARY=""
if [ "$CI_STATUS" = "completed" ]; then
  CI_SUMMARY="CI: 全通過 (${CI_PASSED}/${CI_TOTAL})"
elif [ "$CI_STATUS" = "failed" ]; then
  CI_SUMMARY="CI: 失敗あり (通過${CI_PASSED}/失敗${CI_FAILED}/進行中${CI_PENDING}, 合計${CI_TOTAL})"
else
  CI_SUMMARY="CI: 進行中 (通過${CI_PASSED}/進行中${CI_PENDING}, 合計${CI_TOTAL})"
fi

CODERABBIT_SUMMARY=""
if [ "$CODERABBIT_INSTALLED" = "false" ]; then
  CODERABBIT_SUMMARY="CodeRabbit: 未導入"
elif [ "$HAS_CODERABBIT" = "true" ]; then
  CODERABBIT_SUMMARY="CodeRabbit: レビュー済み (コメント${CODERABBIT_COUNT}件)"
else
  CODERABBIT_SUMMARY="CodeRabbit: レビュー待ち"
fi

SUMMARY="${CI_SUMMARY}, ${CODERABBIT_SUMMARY}"

# 結果をJSON形式で出力
jq -n \
  --arg status "$OVERALL_STATUS" \
  --argjson ci_total "$CI_TOTAL" \
  --argjson ci_passed "$CI_PASSED" \
  --argjson ci_failed "$CI_FAILED" \
  --argjson ci_pending "$CI_PENDING" \
  --argjson has_coderabbit "$HAS_CODERABBIT" \
  --argjson coderabbit_count "$CODERABBIT_COUNT" \
  --arg summary "$SUMMARY" \
  '{
    "status": $status,
    "ci": {
      "total": $ci_total,
      "passed": $ci_passed,
      "failed": $ci_failed,
      "pending": $ci_pending
    },
    "coderabbit": {
      "hasComments": $has_coderabbit,
      "commentCount": $coderabbit_count
    },
    "summary": $summary
  }'

exit 0
