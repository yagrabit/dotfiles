---
name: pr-3-review
description: ベースブランチとの差分に対して複数観点のコードレビューを実施し、問題を検出・修正する
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, AskUserQuestion, Agent
---

# PR Flow Review

ベースブランチとの差分に対して、セキュリティ・品質・パフォーマンスなど複数観点のコードレビューを実施するスキル。
PR作成前のセルフレビューや、既存ブランチの品質チェックに使用する。

## Instructions

### ステップ1: ベースブランチの確認

1. `git branch --show-current` で現在のブランチを確認する
2. AskUserQuestionでベースブランチを確認する:
   - デフォルトは `main`
   - 「main でよいか、別のブランチを指定するか」を選択肢として提示する
3. ベースブランチとの差分が存在することを確認する:
   - `git log {base-branch}..HEAD --oneline` でコミット一覧を表示する
   - 差分がない場合はユーザーに報告して終了する

### ステップ2: 差分の取得

1. `git diff {base-branch}...HEAD` でベースブランチとの差分を取得する
2. `git diff {base-branch}...HEAD --stat` で変更ファイルの統計を取得する
3. 差分の規模（変更ファイル数・行数）をユーザーに報告する

### ステップ3: レビューの実施

以下の4種類のレビューを実施する（可能なものは並列実行）:

1. `/simplify`: コードの品質・再利用性・効率性をレビューし、問題があれば修正する
2. security-reviewer: Agentツールで security-reviewer エージェント（~/.claude/agents/security-reviewer.md）を起動する（結果は日本語で出力すること）
3. CodeRabbit: Agentツールで `coderabbit:code-reviewer` サブエージェントを実行し結果を収集する（プラグイン未インストールの場合はスキップ）
4. code-reviewer: Agentツールで code-reviewer エージェント（~/.claude/agents/code-reviewer.md）を起動する

code-reviewer エージェントがチェック項目に基づいてレビューを実施する（チェック項目はエージェント定義内に記載）。

### ステップ4: レビュー結果の報告と次のアクション

1. レビュー結果をまとめてユーザーに報告する:
   - 各レビュー種別ごとに指摘事項を一覧表示する
   - 指摘がない場合は「指摘なし」と明記する
2. AskUserQuestionで以下の選択肢を提示する:
   - 完了する: 問題なし、またはレビュー指摘を承知の上で完了する
   - 修正する: 指摘事項を修正してから再度レビューする（修正後はステップ2に戻る）
   - 中止する: レビューを中止する
3. 「完了する」が選択された場合、レビュー完了フラグを作成する:
   - ブランチ名を取得: `git branch --show-current`
   - ブランチ名の `/` を `-` に置換して安全なファイル名を作る
   - フラグファイル作成: `mkdir -p /tmp/claude-sessions && date +%s > /tmp/claude-sessions/review-passed-{safe-branch-name}`
   - このフラグがないと `git push` がブロックされる（pre-push-review-gate hook）

## Examples

### 基本的な使い方（mainブランチとの差分をレビュー）

ユーザー: 「PRを出す前にレビューして」

```
ステップ1: ベースブランチの確認
  現在のブランチ: feat/add-login-page
  ベースブランチ: main（デフォルト）
  コミット一覧:
    abc1234 feat: ログインフォームを追加
    def5678 feat: バリデーションを実装

ステップ2: 差分の取得
  変更ファイル: 5ファイル (+120, -15)

ステップ3: レビュー実施
  [/simplify] 指摘なし
  [security-review] 指摘1件: パスワード入力のautocomplete属性が未設定
  [CodeRabbit] 指摘なし
  [code-review] 指摘1件: console.log が残っている（src/login.ts:42）

ステップ4: 結果報告
  → 「修正する」を選択
  → 修正後、ステップ2に戻って再レビュー
  → 「完了する」を選択
```

### 別のベースブランチを指定する場合

ユーザー: 「developブランチとの差分をレビューして」

```
ステップ1: ベースブランチの確認
  現在のブランチ: feat/add-notification
  ベースブランチ: develop（ユーザー指定）
  コミット一覧:
    jkl3456 feat: 通知コンポーネントを追加
    mno7890 test: 通知コンポーネントのテストを追加

ステップ2: 差分の取得
  変更ファイル: 3ファイル (+85, -0)

ステップ3: レビュー実施
  [/simplify] 指摘なし
  [security-review] 指摘なし
  [CodeRabbit] スキップ（プラグイン未インストール）
  [code-review] 指摘なし

ステップ4: 結果報告
  → 「完了する」を選択
```
