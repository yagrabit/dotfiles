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

### プロジェクト管理設定（CLAUDE.local.md）

チケット管理ツール・ドキュメント出力先はプロジェクトごとに異なる。
各プロジェクトの `CLAUDE.local.md`（.gitignore対象）に以下の形式で設定する。

```
## プロジェクト管理

- ツール: jira | github-issues
- プロジェクトキー: VIV（Jira環境のみ）
- 親チケット: VIV-100（現在のEpic/Story。スプリントごとに更新）
- ドキュメント: confluence | artifacts
- Confluenceスペース: VIV（Confluence使用時のみ）
```

検出の優先順:
1. CLAUDE.local.md に「プロジェクト管理」セクションがあればその設定を使う
2. CLAUDE.local.md がない、または設定がない場合はデフォルト（github-issues + artifacts）を適用

Atlassianプラグインはユーザーレベルで有効化されているため全プロジェクトで利用可能だが、
Jira/Confluenceを使うかどうかはプロジェクト単位で判断する。個人プロジェクトではgithub-issuesを使う。

### Jira/Confluence環境（ツール: jira）

チケット管理:
- チケット作成: mcp__plugin_atlassian_atlassian__createJiraIssue
- 親チケットへのリンク: mcp__plugin_atlassian_atlassian__createIssueLink（親チケットIDはCLAUDE.local.mdから取得）
- ステータス遷移: mcp__plugin_atlassian_atlassian__transitionJiraIssue

ドキュメント（ドキュメント: confluence の場合）:
- 調査レポート: Confluenceページに出力（mcp__plugin_atlassian_atlassian__createConfluencePage）
- スペースキー: CLAUDE.local.md の Confluenceスペース設定を使用
- artifactsにはConfluenceページURLを記録（ローカルにもコピーは残す）

ブランチ・PR:
- ブランチ命名: `{type}/{JIRA-KEY}-{description}`（例: `feat/VIV-123-notification-list`）
- PRタイトルにJiraキーを含める

### GitHub Issues環境（ツール: github-issues）

チケット管理:
- チケット作成: `gh issue create`
- 親Issueへのリンク: Sub-issues機能（`gh issue develop` または本文にリンク記載）
- 親Issue番号はCLAUDE.local.mdの親チケットから取得（例: `- 親チケット: #42`）

ドキュメント:
- 調査レポート: `.claude/artifacts/research-*.md` に出力
- 設計ドキュメント: `.claude/artifacts/design-*.md` に出力

ブランチ・PR:
- ブランチ命名: `{type}/GH-{issue-number}-{description}`（例: `feat/GH-42-notification-list`）
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
