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
case "$skill_name" in
  odin-auto-*|simplify|codex:*|coderabbit:*|superpowers:*|odin-do-pr|odin-do-merge)
    exit 0
    ;;
esac

# do系スキル完了後のリマインド
case "$skill_name" in
  odin-do-implement|odin-do-refactor)
    echo "⚠️ [§5-3 auto-insert] ${skill_name}完了。ユーザーへの報告・質問の前に以下を順番に実行すること:"
    echo "  1. Skill(odin-auto-quality) — --fix付き"
    echo "  2. Skill(simplify) — AI生成コードの冗長性除去"
    echo "  3. Skill(odin-auto-review) — 全実装完了時のみ（次WaveにDo-PRがあればスキップ）"
    echo "  4. Skill(odin-auto-verify) — タスク完了宣言前"
    exit 0
    ;;
  odin-do-test)
    echo "⚠️ [§5-3 auto-insert] ${skill_name}完了。ユーザーへの報告・質問の前に以下を順番に実行すること:"
    echo "  1. Skill(odin-auto-quality) — --fix付き"
    echo "  2. Skill(odin-auto-review) — 全実装完了時のみ（次WaveにDo-PRがあればスキップ）"
    echo "  3. Skill(odin-auto-verify) — タスク完了宣言前"
    exit 0
    ;;
  odin-do-commit|odin-do-qa-execute)
    echo "⚠️ [§5-3 auto-insert] ${skill_name}完了。ユーザーへの報告・質問の前に以下を実行すること:"
    echo "  1. Skill(odin-auto-quality) — --fix付き"
    echo "  2. Skill(odin-auto-verify) — タスク完了宣言前"
    exit 0
    ;;
esac

# think系スキル（design/requirements/plan）完了後のリマインド
case "$skill_name" in
  odin-think-design|odin-think-requirements|odin-think-plan)
    echo "⚠️ [§5-3 auto-insert] ${skill_name}完了。ユーザーへの報告・質問の前に以下を実行すること:"
    echo "  1. Skill(odin-auto-peer-review) — ドキュメントの独立ピアレビュー"
    exit 0
    ;;
esac

# その他のスキル → リマインド不要
exit 0
