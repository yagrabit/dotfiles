## 配下スキル一覧（全32スキル）

### think系（考える）-- 7スキル

| スキル名 | 役割 | 主な入力 | 主な出力 |
|----------|------|---------|---------|
| odin-think-research | コードベース・技術調査 | 調査目的 | research-*.md |
| odin-think-requirements | 要件分析・構造化 | Confluence/テキスト/口頭要件 | requirements-*.md |
| odin-think-design | 設計ドキュメント・ADR作成 | requirements-*.md + research-*.md | design-*.md + adr-*.md |
| odin-think-plan | タスク分解・見積もり・実装計画 | design-*.md + requirements-*.md | plan-*.md |
| odin-think-investigate | 不具合原因調査 | バグ報告・エラーログ | 調査レポート（企画向け+開発者向け） |
| odin-think-analyze | 品質・パフォーマンス分析 | 対象コード・メトリクス | 分析レポート+改善提案 |
| odin-think-qa-design | QA試験項目の自動生成 | Confluence URL + Epicブランチ差分 | qa-test-items-*.md |

### do系（実行する）-- 7スキル

| スキル名 | 役割 | 主な入力 | 主な出力 |
|----------|------|---------|---------|
| odin-do-implement | TDDサイクルでの実装 | plan-*.md | 実装コード+テスト |
| odin-do-test | テスト計画・実装・実行 | 対象コード・設計 | テストコード+結果レポート |
| odin-do-refactor | TDDで安全にリファクタリング | 対象コード | リファクタ済みコード |
| odin-do-commit | Conventional Commitsコミット | 変更差分 | gitコミット |
| odin-do-pr | PR作成（セルフレビュー付き） | コミット済みブランチ | Draft PR |
| odin-do-merge | PRマージ・クリーンアップ | マージ可能なPR | マージ済みPR |
| odin-do-qa-execute | QA試験の実行とエビデンス収集 | qa-test-items-*.md + テスト対象URL | qa-report-*.md + screenshots/ |

### talk系（伝える）-- 4スキル

| スキル名 | 役割 | 主な入力 | 主な出力 |
|----------|------|---------|---------|
| odin-talk-clarify | 要件の曖昧点を対話で解消 | 要件テキスト | clarified-*.md |
| odin-talk-propose | 複数アプローチの比較提案 | 課題・要件 | 比較表+推奨パターン |
| odin-talk-review | 多角的コードレビュー（code-reviewer + security-reviewer + simplify + coderabbit + codex並列） | 変更差分 | レビュー結果（3段階分類） |
| odin-talk-explain | 対象者レベル別の説明 | コードベース・成果物 | 説明レポート（4スタイル対応） |
| odin-talk-triage | 雑な入力の解析・タスク分類・odin-board登録 | ユーザーの自由形式テキスト | odin-boardにタスク登録、investigate分類は即時実行 |

### auto系（自動補助）-- 8スキル

| スキル名 | 役割 | 発動タイミング |
|----------|------|--------------|
| odin-auto-coherence | 成果物間の整合性追跡（依存グラフ構築・信頼度スコア算出・影響分析） | Phase 5進入前のゲートチェック（scan/validate/impact） |
| odin-auto-quality | 品質チェック一括実行（lint/型/テスト/セキュリティ） | do系スキル完了後（フック自動リマインド） |
| odin-auto-review | 軽量セルフレビュー（code-reviewer + security-reviewer + simplify + coderabbit + codex並列） | 全実装完了時（フック自動リマインド。次Waveにdo-prがあればスキップ） |
| odin-auto-peer-review | ドキュメント向けピアレビュー（バイアスなし独立レビューア→修正→再評価の反復ループ） | think系(design/requirements/plan)完了後（フック自動リマインド） |
| odin-auto-verify | 完了前検証（証拠付き） | タスク完了宣言前（フック自動リマインド） |
| odin-auto-evolve | 自己進化（不足スキルの生成） | タスク分解でマッピング不可時 |
| odin-auto-improve | WebSearch+メタ認知による自己改善 | インサイト蓄積後、手動起動 |
| odin-auto-record | 開発中に気づいた改善点・学びをinsightsファイルに記録する | 各タスク完了時の振り返り |

### codex系（Codex連携）-- 1スキル

| スキル名 | 役割 | 主な入力 | 主な出力 |
|----------|------|---------|---------|
| odin-codex-search | Codex経由Web検索（未対応環境はWebSearchフォールバック） | 検索クエリ・調査目的 | 構造化された調査結果 |

### learn系（学ぶ）-- 2スキル

| スキル名 | 役割 | 主な入力 | 主な出力 |
|----------|------|---------|---------|
| odin-learn | 独立学習セッション・スキルマップ管理 | 学習トピック/スキルマップ | skillmap-latest.md + flashcards-latest.md |
| odin-learn-review | PRレビュー時の教育モード | レビュー対象PR/差分 | 教育対話 + フラッシュカード + スキルマップ更新 |

### design系（デザイン分析・生成）-- 3スキル

| スキル名 | 役割 | 主な入力 | 主な出力 |
|----------|------|---------|---------|
| odin-design-dissect | WebサイトURLからデザインシステムを抽出・分析（learn/auditモード） | WebサイトURL | dissect-*.md / audit-*.md |
| odin-design-generate | 分析結果からDS生成（HTMLビジュアルガイド + tokens.json + design.md）、対話的改善 | dissect-*.md / audit-*.md | design-system/ ディレクトリ一式 |
| odin-design-knowledge | デザイン分析ナレッジの検索・比較・統計・学習進捗管理 | 検索クエリ/比較対象 | 検索結果 / 比較表 / 統計 / 進捗レポート |
