# 成果物管理ルール

## 配置場所

- 全ての中間成果物は対象プロジェクトの `.claude/artifacts/` ディレクトリに出力する
- `.claude/artifacts/` はコミット対象外（プロジェクトの .gitignore に追加すること）
- PRマージ後は削除してよい

## ファイル名規約

- 基本形式: `{type}-{yyyyMMdd-HHmm}.md`
- 複数機能を並列で進める場合: `{type}-{feature-name}-{yyyyMMdd-HHmm}.md`
- type一覧:
  - `research`: コードベース調査レポート
  - `clarified-requirements`: 明確化された要件
  - `design`: 設計ドキュメント
  - `adr-{NNN}`: Architecture Decision Record
  - `test-plan`: テスト計画
  - `tasks`: タスク一覧

## 成果物の参照ルール

- スキル間の連携は成果物ファイルの読み込みで行う（直接的なスキル間依存は作らない）
- 入力の探索順序:
  1. $ARGUMENTSにファイルパスが明示指定されていればそれを使う
  2. なければ `.claude/artifacts/` 内の該当typeの最新ファイルを使う
  3. 該当ファイルが見つからない場合はAskUserQuestionでユーザーに確認する

## セッション分離

- 成果物はファイルに永続化されるため、セッションをまたいでも情報を失わない
- コンパクション後も成果物ファイルのパスだけ覚えていれば復元可能
