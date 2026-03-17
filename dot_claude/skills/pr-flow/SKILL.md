---
name: pr-flow
description: ブランチ作成からコミット、レビュー、Draft PR作成までの一貫ワークフローを実行する
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, AskUserQuestion, Agent
---

# PR Flow

ブランチ作成 → コミット → レビュー → Draft PR作成の一貫ワークフロースキル。
各ステップでユーザー承認を得ながら進める。

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。
条件を満たしていない場合は、そのステップ内で問題を解決してから再度チェックポイントを確認すること。

### ステップ1: ブランチ作成

1. 現在の作業状態を確認する:
   - `git status` で未コミットの変更がないか確認する
   - `git branch --show-current` で現在のブランチを確認する
   - 既にmain以外のブランチにいる場合は、AskUserQuestionで「現在のブランチを使うか、新しいブランチを作成するか」を確認する
   - 現在のブランチを使う場合はステップ2に進む
2. AskUserQuestionで関連チケットの有無を確認する:
   - チケットがある場合: チケットIDを入力してもらい、`feature/{チケットID}` 形式でブランチ名を決定する（例: feature/PROJ-123, feature/ENG-456）
   - チケットがない場合: 従来通りブランチの種別と説明を確認し、`{type}/{description}` 形式でブランチ名を決定する（例: feat/add-news-page, fix/header-responsive）
     - type は Conventional Commits 準拠: feat, fix, docs, refactor, chore, test 等
     - description はケバブケースで簡潔に記述する
3. 親ブランチ（ベースブランチ）を確認する:
   - デフォルトの親ブランチは `main` とする
   - 親ブランチとリモートの最新状態をユーザーに表示する:
     - `git log origin/{base-branch} -3 --oneline` で最新3件のコミットを表示する
     - ローカルの `{base-branch}` と `origin/{base-branch}` に差分がある場合はその旨を表示する
   - AskUserQuestionで以下の選択肢を提示する:
     - このまま進む（`origin/{base-branch}` から分岐）
     - 別のブランチを親にする（ブランチ名を入力）
   - 別のブランチが選択された場合は、そのブランチを `{base-branch}` として以降の手順で使用する
4. 親ブランチの最新を取得する:
   - `git fetch origin {base-branch}`
5. 新しいブランチを作成する:
   - `git checkout -b {branch-name} origin/{base-branch}`
6. リモートにプッシュしてトラッキングを設定する:
   - `git push -u origin {branch-name}`
7. 結果を報告し、AskUserQuestionで次のステップに進むか確認する

#### 完了チェックポイント（ステップ1）

以下の全条件を満たしたらステップ2に進む:

- ブランチが作成されていること（`git branch --show-current` で期待するブランチ名が返る）
- リモートトラッキングが設定されていること（`git config branch.{branch-name}.remote` が origin を返る）

### ステップ2: コミット作成

commit スキル（~/.claude/skills/commit/SKILL.md）の全手順に従う。

#### 完了チェックポイント（ステップ2）

以下の全条件を満たしたらステップ3に進む:

- `git log {base-branch}..HEAD --oneline` で新しいコミットが存在すること
- `git status` でコミット漏れの変更がないこと
- コミット数を記録すること（ステップ3で使用する）

### ステップ3: レビュー

コミット完了後、PR作成前にレビューを実施する。

1. `git diff HEAD~{コミット数}..HEAD` でコミットした変更の差分を取得する（コミット数はステップ2で記録したコミット数）
2. 以下の4種類のレビューを並列で起動する。全てのレビューが完了するまで次に進んではならない:

   レビュー実行チェックリスト:
   - [ ] simplify: Skillツールで `/simplify` を実行する
   - [ ] security-review: Skillツールで `/security-review` を実行する（結果は日本語で出力すること）
   - [ ] CodeRabbit: Agentツールで `coderabbit:code-reviewer` サブエージェントを起動する（プラグイン未インストールの場合はスキップし、チェック済みとする）
   - [ ] 汎用コードレビュー: Agentツールで汎用レビューサブエージェントを起動する

   並列実行の手順:
   a. 上記4つのレビューを1回のレスポンスで同時に起動する
   b. 各レビューの完了通知を受け取るたびに、チェックリストを更新する
   c. 全4項目がチェック済みになるまで、結果報告やユーザーへの確認に進まない

   全レビュー完了の確認:
   - 4つ全てのレビュー結果が手元に揃っていることを確認する
   - 揃っていない場合は、未完了のレビューの完了を待つ

   汎用コードレビューは以下のチェック項目に沿って実施する:

#### 必須チェック項目

- 型安全性: `any` 型や型アサーション（`as any`）の不適切な使用がないか
- デバッグコード: `console.log`、`debugger`、`TODO/FIXME`（意図的でないもの）が残っていないか
- エラーハンドリング: エラーが握りつぶされていないか、適切にハンドリングされているか
- テスト: 新しい関数・コンポーネントに対応するテストがあるか（テストフレームワークがある場合）

#### 推奨チェック項目

- 命名: 変数名・関数名・ファイル名がプロジェクトの規約に沿っているか
- コード重複: 既存のユーティリティやヘルパーで代替できるコードがないか
- パフォーマンス: 明らかな N+1 問題や不要な再レンダリングがないか

3. レビュー結果をユーザーに報告し、AskUserQuestionで以下の選択肢を提示する:
   - PR作成に進む: 問題なし、またはレビュー指摘を承知の上でPR作成に進む
   - 修正する: 指摘事項を修正してから再度レビューする（修正後はステップ3の最初に戻る）
   - 中止する: ワークフローを中止する

#### 完了チェックポイント（ステップ3）

以下の全条件を満たしたらステップ4に進む:

- 4種類全てのレビュー結果が揃っていること
- ユーザーがレビュー結果を確認し、「PR作成に進む」「修正する」「中止する」のいずれかを選択したこと
- 「修正する」が選択された場合は、修正後にステップ3の最初に戻ること
- 「PR作成に進む」が選択された場合にのみステップ4に進む

### ステップ4: Draft PR作成

1. 前提条件を確認する:
   - 現在のブランチが `{base-branch}` 以外であること
   - リモートにプッシュ済みであること（未プッシュのコミットがある場合は `git push` を実行）
2. 変更内容を分析する:
   - `git log {base-branch}..HEAD --oneline` でコミット一覧を取得する
   - `git diff {base-branch}...HEAD --stat` で変更ファイルの統計を取得する
3. PRテンプレートを読み込む:
   - `.github/pull_request_template.md` が存在する場合はそれを使用する
   - 存在しない場合は以下のデフォルトフォーマットを使用する:
     ```
     ## 概要
     （変更の目的と背景）

     ## 変更内容
     （主な変更点を箇条書き）

     ## テスト計画
     （テスト項目のチェックリスト）
     ```
4. 変更内容に基づいてPRタイトルと本文を生成する:
   - PRタイトル: Conventional Commits形式のPrefixを使用し、日本語で簡潔に記述する（70文字以内）
   - PR本文: テンプレートの各セクションを変更内容に基づいて埋める
5. AskUserQuestionでPRタイトルと本文を提示し、承認を得る
6. 承認後、`gh pr create --draft --title "{title}" --body "{body}"` でDraft PRを作成する

#### 完了チェックポイント（ステップ4）

以下の全条件を満たしたらステップ5に進む:

- `gh pr view --json url` でPR URLが取得できること

### ステップ5: 最終結果の報告

以下の情報をまとめて報告する:
- ブランチ名
- コミット一覧（`git log {base-branch}..HEAD --oneline`）
- レビュー結果の要約
- PR URL

## Examples

### 機能追加の一貫フロー

ユーザー: 「ログインページを作ったのでPRまでやって」

```
ステップ1: ブランチ作成
  ブランチ名: feat/add-login-page
  親ブランチ確認:
    origin/main の最新コミット:
      abc1234 feat: ユーザー管理機能を追加
      def5678 fix: ヘッダーのレスポンシブ対応
      ghi9012 docs: READMEを更新
    → 「このまま進む（origin/main から分岐）」
  ベース: origin/main (abc1234)

ステップ2: コミット作成
  コミット1: feat: ログインページを追加

ステップ3: レビュー
  [CodeRabbit] 指摘なし
  [汎用レビュー] 指摘なし
  → 「PR作成に進む」

ステップ4: Draft PR作成
  タイトル: feat: ログインページを追加
  URL: https://github.com/org/repo/pull/42

最終結果:
  ブランチ: feat/add-login-page
  コミット: 1件
  PR: https://github.com/org/repo/pull/42 (Draft)
```

### 既存ブランチでのフロー

ユーザー: 「コミットしてPRまで作って」（feat/update-header ブランチで作業中）

```
ステップ1: ブランチ確認
  現在のブランチ: feat/update-header
  → 「現在のブランチを使う」

ステップ2〜5: 通常通り実行
```

### 別の親ブランチを使うフロー

ユーザー: 「developブランチから切って作業したい」

```
ステップ1: ブランチ作成
  ブランチ名: feat/add-notification
  親ブランチ確認:
    origin/main の最新コミット:
      abc1234 feat: v2リリース準備
      def5678 fix: CI設定を修正
      ghi9012 chore: 依存パッケージを更新
    → 「別のブランチを親にする」→ develop を入力
    origin/develop の最新コミット:
      jkl3456 feat: 通知基盤を追加
      mno7890 refactor: API層をリファクタ
      pqr1234 fix: バリデーションを修正
    → 「このまま進む（origin/develop から分岐）」
  ベース: origin/develop (jkl3456)

ステップ2〜5: 通常通り実行（{base-branch} = develop）
```
