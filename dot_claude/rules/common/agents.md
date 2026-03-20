# サブエージェント委譲ルール

## 委譲の判断基準

- タスクが独立して完結可能か（他のタスクの結果に依存しないか）
- 専門知識が必要か（セキュリティ、パフォーマンス等）
- メインコンテキストを消費すべき内容か（消費すべきでなければ委譲する）

## 利用可能なエージェント

- code-reviewer: コード品質・保守性のレビュー。model: sonnet。修正はしない、指摘のみ
- security-reviewer: OWASP Top 10ベースのセキュリティレビュー。model: sonnet。修正はしない、指摘のみ
- tdd-guide: TDD開発ガイド。Red → Green → Refactor サイクルを支援。テスト作成・実行が可能
- requirements-analyst: 要件の曖昧点・不足項目・矛盾の検出。model: sonnet。修正はしない、分析結果のみ返す
- architecture-analyst: コードベースの構造・パターン・依存関係の分析。model: sonnet。修正はしない、分析結果のみ返す

## 使い分け

- コード変更後のレビュー → code-reviewer と security-reviewer を並列起動する
- 新機能開発（テスト重要）→ tdd-guide を起動する
- 簡単なリファクタ → エージェント不要、直接実行する
- 要件の明確化 → requirements-analyst を起動する
- コードベース調査・設計前の分析 → architecture-analyst を起動する

## 並列実行の原則

- 独立したエージェントは1回のメッセージで同時に起動する
- 結果が後続の判断に必要なエージェントは foreground で待つ
- 結果が参考程度のエージェントは background で起動する
