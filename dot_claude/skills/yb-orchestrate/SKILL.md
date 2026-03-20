---
name: yb-orchestrate
description: マルチエージェント連携ワークフロー。計画→実装→code-reviewer→security-reviewerのチェーンを管理する
user-invocable: true
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion
---

マルチエージェント連携ワークフロー。タスクの分析・計画から実装、レビュー、修正までを一貫して管理する。

## 1. タスク分析と計画

1. ユーザーの要求を分析し、実装計画を策定する
2. タスクの規模を判定する:
   - 小規模（1-3ファイル変更）: 直接実装
   - 中規模（4-10ファイル変更）: サブエージェントに委譲
   - 大規模（10+ファイル変更、またはブランチが必要）: yb-worktreeスキルを活用
3. AskUserQuestionで計画を提示し承認を得る

## 2. 実装

- 計画に従って実装を進める
- TDDが適切な場合: tdd-guide エージェント（~/.claude/agents/tdd-guide.md）を起動する
- 大規模変更: Agent(isolation: "worktree") を活用する
- 実装の進捗を適宜報告する

## 3. レビュー

以下のレビューを並列で起動し、全ての結果が揃うまで待つ:

1. code-reviewer エージェント（~/.claude/agents/code-reviewer.md）を Agentツールで起動する
2. security-reviewer エージェント（~/.claude/agents/security-reviewer.md）を Agentツールで起動する

## 4. 修正

- レビュー指摘のうちCritical/Majorを修正する
- 修正後、ステップ3に戻って再レビューする
- 全指摘がMinor以下になったら完了とする

## 5. 完了報告

以下の内容をユーザーに報告する:

- 実装内容の概要
- レビュー結果の要約（Critical/Major指摘の修正内容）
- 残存するMinor指摘の一覧
