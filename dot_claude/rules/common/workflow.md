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
