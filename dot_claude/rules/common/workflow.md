# 開発ワークフロールール

## 基本フロー

開発作業は `/odin` 経由で実行する。odinが要望を分析し、配下スキルをオーケストレーションする。

フェーズ順序: Research → 要件明確化 → 設計（ゲート1） → タスク分解（ゲート2） → 実装 → レビュー → PR

## セッション管理

- フェーズ間の情報伝達は `.claude/artifacts/` の成果物ファイル経由で行う
- セッションが長くなったら /compact で積極的にコンパクションする（FIC: Frequent Intentional Compaction）

## プロジェクト管理設定（CLAUDE.local.md）

チケット管理ツールはプロジェクトごとに異なる。各プロジェクトの `CLAUDE.local.md`（.gitignore対象）に設定する。

```
## プロジェクト管理

- ツール: jira | github-issues | local
- プロジェクトキー: VIV（Jira環境のみ）
- 親チケット: VIV-100（現在のEpic/Story）
- ドキュメント: confluence | artifacts
- Confluenceスペース: VIV（Confluence使用時のみ）
```

検出の優先順:
1. CLAUDE.local.md に「プロジェクト管理」セクションがあればその設定を使う
2. 設定がない場合はlocalモード（外部サービスアクセスなし、`.claude/artifacts/` のみ）

### ブランチ・PR命名規則

- local: `{type}/{description}`（例: `feat/notification-list`）
- jira: `{type}/{JIRA-KEY}-{description}`（例: `feat/VIV-123-notification-list`）
- github-issues: `{type}/GH-{issue-number}-{description}`（例: `feat/GH-42-notification-list`）
