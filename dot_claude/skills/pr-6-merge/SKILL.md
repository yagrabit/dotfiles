---
name: pr-6-merge
description: PRをマージし、mainブランチを最新化、作業ブランチを削除、フラグファイルをクリーンアップする
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash, Read, Grep, AskUserQuestion
---

# Merge Cleanup

PRマージからローカルクリーンアップまでを一括処理するスキル。
マージ方法の選択、ブランチ削除、フラグファイル・成果物の整理を一連の流れで実行する。

## Instructions

### ステップ1: PR特定と状態確認

1. $ARGUMENTSにPR番号またはURLが指定されていればそれを使用する
2. 指定がなければ現在のブランチからPRを検索する:
   - `git branch --show-current` で現在のブランチ名を取得する
   - `gh pr list --head {branch} --json number,title,url,state,reviewDecision,statusCheckRollup` でPRを検索する
   - PRが見つからない場合はユーザーに報告して終了する
3. PRの状態を確認する:
   - CI: `statusCheckRollup` で全チェックが通過しているか
   - レビュー: `reviewDecision` が `APPROVED` か
   - マージ可能性: `gh pr view {number} --json mergeable --jq '.mergeable'` で確認する
4. 問題がある場合はユーザーに具体的な問題点を報告し、AskUserQuestionで続行方法を確認する:
   - 「問題を修正する」: スキルを中断し、ユーザーが問題を修正する
   - 「強制的にマージする」: 問題を無視してマージに進む
   - 「中止する」: スキルを終了する

### ステップ2: マージ実行

1. AskUserQuestionでマージ方法を確認する:
   - 「Squash merge」: コミット履歴を1つにまとめる
   - 「Merge commit」: マージコミットを作成する
   - 「Rebase merge」: リベースしてマージする
2. 選択に応じてマージを実行する:
   - Squash merge: `gh pr merge {number} --squash --delete-branch`
   - Merge commit: `gh pr merge {number} --merge --delete-branch`
   - Rebase merge: `gh pr merge {number} --rebase --delete-branch`
3. マージが失敗した場合はエラー内容をユーザーに報告して終了する

### ステップ3: ローカルクリーンアップ

1. デフォルトブランチ名を取得する:
   - まず `main` ブランチの存在を確認する
   - 存在しなければ `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` で取得する
2. デフォルトブランチに切り替える: `git checkout {default-branch}`
3. 最新を取得する: `git pull origin {default-branch}`
4. マージ済みの作業ブランチをローカルから削除する: `git branch -d {branch-name}`
   - 既に削除済み（checkout時にブランチが存在しない等）の場合はスキップする
5. リモートトラッキングブランチをプルーニングする: `git fetch --prune`

### ステップ4: フラグ・成果物クリーンアップ

1. レビューフラグファイルを削除する:
   - ブランチ名の `/` を `-` に置換して安全なファイル名を作る
   - `rm -f /tmp/claude-sessions/review-passed-{safe-branch-name}`
2. `.claude/artifacts/` 配下に関連する成果物ファイルがあるか確認する:
   - ファイルが存在する場合、一覧を表示してAskUserQuestionで削除するか確認する:
     - 「全て削除する」: 成果物ファイルを全て削除する
     - 「選択して削除する」: 個別に削除対象を選ぶ
     - 「残す」: 成果物ファイルをそのまま残す
   - ファイルが存在しない場合はスキップする

### ステップ5: 結果報告

以下の内容をまとめて報告する:

- マージされたPR: 番号、タイトル、URL
- マージ方法: Squash / Merge commit / Rebase
- 削除されたブランチ: リモートブランチ名 + ローカルブランチ名
- 現在のブランチ: デフォルトブランチ名と最新コミットハッシュ
- クリーンアップ結果: フラグファイル・成果物の削除状況

## Examples

### 基本的な使い方（現在のブランチのPRをマージ）

ユーザー: 「/pr-6-merge」

```
ステップ1: PR特定と状態確認
  現在のブランチ: feat/add-login-page
  PR #42: ログインページを追加 (https://github.com/org/repo/pull/42)
  CI: 全チェック通過
  レビュー: APPROVED
  マージ可能: YES

ステップ2: マージ実行
  → AskUserQuestion: マージ方法を選択
  → 「Squash merge」を選択
  → gh pr merge 42 --squash --delete-branch 実行
  → マージ成功

ステップ3: ローカルクリーンアップ
  → git checkout main
  → git pull origin main
  → git branch -d feat/add-login-page
  → git fetch --prune

ステップ4: フラグ・成果物クリーンアップ
  → /tmp/claude-sessions/review-passed-feat-add-login-page を削除
  → .claude/artifacts/ に関連ファイルなし、スキップ

ステップ5: 結果報告
  PR: #42 ログインページを追加
  マージ方法: Squash merge
  削除ブランチ: feat/add-login-page（リモート + ローカル）
  現在: main (abc1234)
```

### PRに問題がある場合

ユーザー: 「/pr-6-merge 58」

```
ステップ1: PR特定と状態確認
  PR #58: 通知機能を実装 (https://github.com/org/repo/pull/58)
  CI: 1件失敗（lint-check）
  レビュー: REVIEW_REQUIRED
  マージ可能: YES

  → 問題を報告:
    - CI: lint-check が失敗しています
    - レビュー: まだ承認されていません
  → AskUserQuestion: 続行方法を選択
    - 「問題を修正する」
    - 「強制的にマージする」
    - 「中止する」

  → 「問題を修正する」を選択
  → スキルを中断、ユーザーが問題を修正

（修正後、再度 /pr-6-merge 58 を実行）

ステップ1: PR特定と状態確認
  PR #58: 通知機能を実装 (https://github.com/org/repo/pull/58)
  CI: 全チェック通過
  レビュー: APPROVED
  マージ可能: YES

ステップ2: マージ実行
  → 「Rebase merge」を選択
  → gh pr merge 58 --rebase --delete-branch 実行
  → マージ成功

ステップ3: ローカルクリーンアップ
  → git checkout main
  → git pull origin main
  → git branch -d feat/notification
  → git fetch --prune

ステップ4: フラグ・成果物クリーンアップ
  → /tmp/claude-sessions/review-passed-feat-notification を削除
  → .claude/artifacts/ に design-notification-20260320-1430.md を発見
  → AskUserQuestion: 成果物ファイルを削除するか確認
  → 「全て削除する」を選択
  → design-notification-20260320-1430.md を削除

ステップ5: 結果報告
  PR: #58 通知機能を実装
  マージ方法: Rebase merge
  削除ブランチ: feat/notification（リモート + ローカル）
  現在: main (def5678)
  成果物: 1ファイル削除済み
```
