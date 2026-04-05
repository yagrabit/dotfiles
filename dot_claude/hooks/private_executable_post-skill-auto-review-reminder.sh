#!/usr/bin/env bash
# PostToolUseフック: Skillツール完了後にauto系スキルの実行をリマインドする
# execution-loop.md § 5-3 のテキスト指示を機械的リマインドに昇格させる
#
# 背景: odinのexecution-loop § 5-3にはdo系/think系スキル完了後のauto系自動挿入ルールが
# 定義されているが、テキスト指示のみでは LLM が忘れてユーザーへの質問に移ることがある。
# このフックにより、スキル完了直後に会話にリマインドを注入し、auto系チェーンの実行を強制する。
#
# 保守: 新しいdo系/think系スキルを追加した場合は、下記のcase文にパターンを追加すること。
# 正本: execution-loop.md § 5-3
set -euo pipefail

# jqが未インストールの場合はスキップ
if ! command -v jq &>/dev/null; then
  exit 0
fi

# stdinからツール入力のJSONを読み取る
input="$(cat)"

# .tool_input.skill を抽出
skill_name="$(echo "$input" | jq -r '.tool_input.skill // empty')"

# スキル名が空ならスキップ
if [[ -z "$skill_name" ]]; then
  exit 0
fi

# リマインド不要なスキルを除外（auto系自身、外部プラグイン、汎用ツール等）
# do-prはtalk-review内包、do-mergeは終端操作のためスキップ
# auto-peer-review / talk-review はCodexレビューをトリガーするため除外しない
case "$skill_name" in
  odin-auto-peer-review|odin-talk-review)
    # 後続のcase文でCodexレビューをトリガーする
    ;;
  odin-auto-*|simplify|codex:*|coderabbit:*|superpowers:*|odin-do-pr|odin-do-merge)
    exit 0
    ;;
esac

# do系スキル完了後の必須チェーン（正本: execution-loop.md § 5-3）
case "$skill_name" in
  odin-do-implement|odin-do-refactor)
    echo "⚠️ [§5-3 必須チェーン] ${skill_name}完了。ユーザーへの報告・質問の前に以下を順番に実行すること（省略禁止）:"
    echo "  1. Skill(odin-auto-quality) — --fix付き"
    echo "  2. Skill(simplify) — AI生成コードの冗長性除去"
    echo "  3. Skill(odin-auto-verify) — タスク完了宣言前"
    echo "  ※ 全do系タスク完了後には Skill(odin-talk-review) を必ず実行すること（Codex含むクロスモデルレビュー）"
    exit 0
    ;;
  odin-do-test)
    echo "⚠️ [§5-3 必須チェーン] ${skill_name}完了。ユーザーへの報告・質問の前に以下を順番に実行すること（省略禁止）:"
    echo "  1. Skill(odin-auto-quality) — --fix付き"
    echo "  2. Skill(simplify) — AI生成コードの冗長性除去"
    echo "  3. Skill(odin-auto-verify) — タスク完了宣言前"
    exit 0
    ;;
  odin-do-commit|odin-do-qa-execute)
    echo "⚠️ [§5-3 必須チェーン] ${skill_name}完了。ユーザーへの報告・質問の前に以下を実行すること（省略禁止）:"
    echo "  1. Skill(odin-auto-quality) — --fix付き"
    echo "  2. Skill(odin-auto-verify) — タスク完了宣言前"
    exit 0
    ;;
esac

# think系スキル完了後の必須チェーン（正本: execution-loop.md § 5-3）
case "$skill_name" in
  odin-think-research|odin-think-requirements|odin-think-design|odin-think-plan|odin-think-investigate|odin-think-analyze)
    echo "⚠️ [§5-3 必須チェーン] ${skill_name}完了。ユーザーへの報告・質問の前に以下を実行すること（省略禁止）:"
    echo "  1. Skill(odin-auto-peer-review) — ドキュメントの独立ピアレビュー"
    echo "  2. codex:rescue — Codex（異なるモデル）による独立レビュー"
    exit 0
    ;;
esac

# Codexレビュートリガー（auto-peer-review / talk-review 完了後）
# 正本: execution-loop.md § 5-3
case "$skill_name" in
  odin-auto-peer-review)
    echo "⚠️ [§5-3 必須チェーン] auto-peer-review完了。Codex独立レビューを実行すること（省略禁止）:"
    echo "  1. codex:rescue — Codex（異なるモデル）による独立レビュー"
    exit 0
    ;;
  odin-talk-review)
    echo "⚠️ [§5-3 必須チェーン] talk-review完了。Codex独立レビューと最終検証を実行すること（省略禁止）:"
    echo "  1. codex:rescue — Codex（異なるモデル）による独立レビュー"
    echo "  2. Skill(odin-auto-verify) — 最終検証"
    exit 0
    ;;
esac

# その他のスキル → リマインド不要
exit 0
