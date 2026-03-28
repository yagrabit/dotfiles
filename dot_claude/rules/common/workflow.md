# 開発ワークフロールール

## セッション分離の原則

- 1フェーズ1セッションを原則とする
- フェーズとスキルの対応（全て `/odin` 経由で実行可能）:
  1. Research → `/odin-think-research`
  2. 要件明確化 → `/odin-talk-clarify` + `/odin-think-requirements`
  3. 設計 → `/odin-think-design`（ゲート1）
  4. テスト計画 → `/odin-do-test`
  5. タスク分解 → `/odin-think-plan`（ゲート2）
  6. TDD実装 → `/odin-do-implement`
  7. レビュー → `/odin-talk-review`, CodeRabbit
  8. PR → `/odin-do-pr`
- フェーズ間の情報伝達は `.claude/artifacts/` の成果物ファイル経由で行う
- セッションが長くなったら /compact で積極的にコンパクションする（FIC: Frequent Intentional Compaction）

## ゲート管理

設計とタスク分解の後に人間のレビューゲートを設ける。リスクレベルに応じてゲートの重さを調整する。

### リスクレベルの判定基準

- 高: 認証、決済、DB設計変更、セキュリティ関連、公開APIの変更
- 中: 新画面追加、API追加、状態管理の変更
- 低: UIテキスト変更、スタイル修正、バグ修正

### ゲート適用ルール

- 高リスク: 設計レビュー(ゲート1) + タスク計画レビュー(ゲート2)の両方を詳細に実施
- 中リスク: 設計の要点レビュー(ゲート1) + PRレビューで重点チェック
- 低リスク: 設計ゲート不要、PRレビューのみ

## パイプライン並列

- ゲート待ちの間に別機能の上流工程（Research/要件整理）を進めてよい
- 成果物ファイル名にfeature名を含めて機能間を区別する
- 例: `design-login-20260320-1430.md`, `research-dashboard-20260320-1500.md`

## チケット駆動並列開発ワークフロー

大きな機能開発（Story以上の粒度）では以下のフローを適用する。

### フロー概要

1. 調査: odin-think-research → research-*.md
2. 要件・設計: odin-talk-clarify → odin-think-design（ゲート1）
3. タスク分解・チケット作成: odin-think-plan → チケット作成（1チケット = 1PR相当、PRサイズガイドライン準拠）
4. 並列実装: worktreeベースの並列エージェント実行（Wave形式）
5. 並列レビュー対応: CodeRabbit + 人間レビューの指摘を各PR並列で対応
6. マージ: 依存順序に従ったマージ + odin-auto-verify最終検証

### 環境自動検出

チケット管理ツールはMCPツールの有無で自動判定する:
- mcp__plugin_atlassian が利用可能 → Jira/Confluence環境
- mcp__plugin_atlassian が利用不可 → GitHub Issues環境（デフォルト）

### Jira/Confluence環境

- チケット作成: mcp__plugin_atlassian_atlassian__createJiraIssue
- 調査レポート: Confluenceページに出力（artifactsにはURLを記録）
- ブランチ命名: `{type}/{JIRA-KEY}-{description}`
- PRタイトルにJiraキーを含める

### GitHub Issues環境

- チケット作成: `gh issue create`（Sub-issues機能で親Issueに紐づけ）
- 調査レポート: `.claude/artifacts/research-*.md` に出力
- ブランチ命名: `{type}/GH-{issue-number}-{description}`
- PR本文に `Closes #{issue-number}` を記載

### 並列実装の前提条件

- API境界・型定義が先行PRでマージ済みであること
- 同一ファイルを複数worktreeで編集しないこと
- タスクの独立性がodin-think-planで検証済みであること
- 同時並列数は最大4エージェントまで

### 並列レビュー対応

- CodeRabbitの指摘は表層的（完全性スコア1/5）であることを認識する
- AI生成コードは問題が1.7倍多いため、人間レビューを省略しない
- 各PRのレビュー指摘を独立して並列対応する
