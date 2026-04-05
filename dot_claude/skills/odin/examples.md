## Examples

### 例1: 新規機能開発の全工程

ユーザー: 「ユーザーに通知を送れるようにしたい。ベルアイコンとドロップダウンで。」

```
Phase 1: 初期入力分析
  目的: ベルアイコン+ドロップダウンによるユーザー通知機能の追加
  制約: なし（明示されていない）
  既知情報: UI形式（ベルアイコン+ドロップダウン）
  暗黙の前提: Next.jsプロジェクト（package.json から判定）
  不足情報: 通知の種類、リアルタイム性、永続化方法

  コンテキスト自動補完:
    プロジェクト: Next.js 14 App Router, pnpm, TypeScript
    既存成果物: なし
    git: main ブランチ、クリーン

Phase 2: 深掘りヒアリング
  Q1: 「通知の種類はどれですか？
    1. アプリ内通知のみ（ベルアイコンで表示）
    2. アプリ内通知 + メール通知
    3. アプリ内通知 + メール + Slack連携
    4. おまかせ（まずアプリ内通知のみで始める）」
  A1: 4（おまかせ）

  Q2: 「通知のリアルタイム性はどの程度必要ですか？
    1. ページリロード時に更新されれば十分
    2. リアルタイムで即座に表示したい（WebSocket/SSE）
    3. おまかせ（まずリロード更新で始める）」
  A2: 1

Phase 3: 理解要約（自動進行）
  「こう理解しました:
    [目的] アプリ内通知機能（ベルアイコン+ドロップダウン）を追加する
    [成果物] 通知API、通知UIコンポーネント、テスト
    [制約] リロード更新で十分、メール/Slack連携は対象外
    [アプローチ概要]
      1. コードベース調査
      2. 要件整理・設計
      3. TDDで実装
      4. 品質チェック・レビュー（Codex含む）
      5. コミット・PR作成
    [使用するodinスキル]
      research, requirements, design, plan, implement, test, talk-review, commit, pr」
  → 承認不要、自動的にPhase 4へ

Phase 4: タスク分解・計画（自動進行）
  Wave 1: T-01 [research] コードベース調査
  Wave 2: T-02 [requirements] 通知機能の要件整理
          T-03 [design] 設計ドキュメント作成
          （各成果物にauto-peer-review → codex:rescue必須）
  Wave 3: T-04 [plan] タスク分解・実装計画
          （auto-peer-review → codex:rescue必須）
  Wave 4: T-05 [implement] 通知API実装(TDD)
          T-06 [implement] 通知UIコンポーネント実装(TDD)
          （各タスクにauto-quality + simplify + auto-verify必須）
  Wave 5: T-07 [talk-review] 品質・セキュリティレビュー
          T-08 [codex:rescue] Codex独立レビュー
  Wave 6: T-09 [commit] コミット
          T-10 [pr] PR作成
  → 承認不要、自動的にPhase 5へ

Phase 5: 実行ループ（自律実行）
  Wave 1: research実行 → research-20260320-1430.md → auto-peer-review(PASS) → codex:rescue(PASS)
  Wave 2: requirements + design 実行 → 成果物出力 → auto-peer-review(PASS) → codex:rescue(PASS)
  Wave 3: plan実行 → plan-20260320-1500.md → auto-peer-review(PASS) → codex:rescue(PASS)
  Wave 4: implement(API) + implement(UI) 並列実行 → auto-quality(PASS) + simplify + auto-verify(PASS)
  Wave 5: talk-review → codex:rescue(独立レビュー) → auto-verify(最終検証PASS)
  Wave 6: commit + pr 実行 → PR #45 作成

Phase 6: 完了報告
  成果物: PR #45, 実装ファイル8個, テスト4個
  検証: テスト 24/24 passed, ビルド pass, lint pass
  次のアクション: PRレビュー依頼、E2Eテスト追加検討
```

### 例2: 不具合修正

ユーザー: 「ログインページで "Cannot read properties of undefined" って出てる」

```
Phase 1: 初期入力分析
  目的: ログインページのundefinedエラーの修正
  既知情報: エラーメッセージ、発生箇所（ログインページ）
  不足情報: なし（エラーメッセージと発生箇所が特定できている）

Phase 2: スキップ（不足情報なし）

Phase 3: 理解要約（自動進行）
  「こう理解しました:
    [目的] ログインページの "Cannot read properties of undefined" エラーを修正する
    [成果物] バグ修正コミット
    [アプローチ] 原因調査 → 再現テスト作成 → 修正 → レビュー → コミット」
  → 承認不要、自動的にPhase 4へ

Phase 4: 計画（自動進行）
  Wave 1: T-01 [investigate] エラー原因調査
  Wave 2: T-02 [implement] 再現テスト + 修正（TDD）
          （auto-quality + talk-review + auto-verify 必須チェーン）
  Wave 3: T-03 [commit] コミット
  → 承認不要、自動的にPhase 5へ

Phase 5-6: 実行・完了
```

### 例3: 簡単な作業（質問ゼロで完了）

ユーザー: 「品質チェックして」

```
Phase 1: 初期入力分析
  目的: プロジェクトの品質チェック実行
  不足情報: なし

Phase 2: スキップ

Phase 3: スキップ（単一スキル、Phase 3スキップ条件充足）

Phase 4: スキップ（単一スキルのため計画不要）

Phase 5: 実行
  auto-quality実行 → 結果表示

Phase 6: 完了報告
```

### 例4: 音声入力（曖昧な要望）

ユーザー: 「えーとね、あの、ダッシュボードにグラフを、あ、チャートね、チャートを追加したいんだよね。売上の推移が見えるやつ。あとできればCSVダウンロードも」

```
Phase 1: 初期入力分析（音声正規化後）
  目的: ダッシュボードに売上推移チャートを追加し、CSVダウンロード機能も付ける
  既知情報: ダッシュボード画面が既存、売上データが存在する前提
  不足情報: チャートライブラリの指定、期間（日次/月次/年次）

Phase 2: 深掘りヒアリング
  Q1: 「売上推移の期間はどれですか？
    1. 日次（直近30日）
    2. 月次（直近12ヶ月）
    3. 切り替え可能にする（日次/月次/年次）
    4. おまかせ」
  ...以降省略
```

---

## アンチパターン: 委譲違反の例

odinが鉄則1に違反するパターンと正しい実行例の対比。

### 違反例1: Agentツール直接使用

```
❌ 違反: odinがPhase 5でExploreエージェントを直接起動
  Agent({
    prompt: "コードベースを調査して設計書を評価してください",
    subagent_type: "Explore"
  })

✅ 正しい: Skillツールでodin-think-researchに委譲
  Skill({
    skill: "odin-think-research",
    args: '{"odin_context": {"task": "コードベース調査", ...}}'
  })
```

### 違反例2: odin自身が分析を実行

```
❌ 違反: odinがRead/Grepで直接ファイルを読み、自分で分析して結論を出す
  Read → Grep → 「分析結果: この設計は問題ありません」

✅ 正しい: Skillツールでodin-think-analyzeに委譲
  Skill({
    skill: "odin-think-analyze",
    args: '{"odin_context": {"task": "設計書の品質分析", ...}}'
  })
```

### 違反例3: 「簡単だから」スキルを省略

```
❌ 違反: 「レビューは短いドキュメントだから自分でやろう」
  → odinが直接ドキュメントを読んで評価コメントを書く

✅ 正しい: 複雑さに関係なくSkillツールで委譲
  Skill({
    skill: "odin-auto-peer-review",
    args: '{"odin_context": {"task": "設計書レビュー", "artifacts": {"design": "..."}}}'
  })
```

判断基準: Phase 5のタスク実行では、「情報収集」以外の全ての作業をSkillツールで委譲する。
「簡単だから」「短いから」「1つだけだから」は委譲省略の正当な理由にならない。
