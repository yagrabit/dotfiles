---
name: odin-do-merge
description: PR状態確認・マージ方法選択・マージ実行・ローカルクリーンアップまで一括実行する。CI/レビュー承認状態を確認してから安全にマージする。「マージして」「PRをマージして」などで起動。odinから自動起動される場合もある。
user-invocable: true
allowed-tools: Bash, Read, Grep, AskUserQuestion
---

# odin-do-merge

PRマージ・クリーンアップスキル。odin司令塔のdoフェーズで使用する。
PRのCI状態・レビュー承認状態を確認し、適切なマージ方法を選択してマージを実行する。
マージ後はローカルブランチの削除とmainの最新化を行う。

## コンテキスト検出

### odinコンテキストがある場合（$ARGUMENTSにodin_contextが含まれる場合）
- odinから自動呼び出しされている
- PR番号はodinコンテキストから取得する
- マージ方法の選択はodinの判断に委ねる（デフォルト: Squash merge）
- ただしCI/レビュー承認の確認（ステップ1）は必ず実行する

### odinコンテキストがない場合（ユーザー直接呼び出し）
- ステップ1からユーザーにPR番号を確認して開始する
- マージ方法はユーザーに選択してもらう

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

### ステップ1: PRの状態確認

1. 現在のブランチとPR情報を確認する:
   ```bash
   git branch --show-current
   gh pr view
   ```

2. PR番号が特定できない場合:
   - AskUserQuestionでPR番号またはURLを確認する

3. CI（継続的インテグレーション）の状態を確認する:
   ```bash
   gh pr checks
   ```

   CIの状態判定:
   - 全チェックが通過（success）→ マージ可能
   - 実行中（pending）→ 完了を待つか、AskUserQuestionで確認する
   - 失敗（failure）→ 原因を確認し、AskUserQuestionで対応を確認する

4. レビュー承認状態を確認する:
   ```bash
   gh pr view --json reviews
   ```

   レビュー状態の判定:
   - 承認済み（APPROVED）→ マージ可能
   - 変更要求あり（CHANGES_REQUESTED）→ AskUserQuestionで対応を確認する
   - 未レビュー → AskUserQuestionで「レビューなしでマージしてよいか」を確認する

5. コンフリクトの確認:
   ```bash
   gh pr view --json mergeable
   ```

   コンフリクトがある場合:
   - ローカルで解決するか確認する
   - `git fetch origin && git rebase origin/main` を案内する

#### 完了チェックポイント（ステップ1）

- PRのCI状態が確認できていること
- レビュー承認状態が確認できていること
- コンフリクトがないこと
- CIが失敗・コンフリクトありの場合はユーザーに確認済みであること

### ステップ2: マージ方法の選択

リポジトリの設定とコミット履歴からマージ方法を決定する。

マージ方法の選択肢:

| 方法 | 概要 | 推奨シーン |
|------|------|----------|
| Squash merge | PRの全コミットを1つに圧縮 | コミット履歴をきれいに保ちたい場合（推奨） |
| Merge commit | マージコミットを作成（全コミット保持） | コミット履歴を完全に残したい場合 |
| Rebase merge | ベースブランチに直線的に追加 | 線形な履歴が必要な場合 |

デフォルトの推奨: Squash merge
- 理由: mainブランチの履歴が1PR=1コミットになり、変更追跡が容易になる

リポジトリの設定を確認する:
```bash
gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed
```

AskUserQuestionでマージ方法を確認する:
- Squash merge（推奨・コミット履歴がシンプルになる）
- Merge commit（全コミット履歴を保持する）
- Rebase merge（線形な履歴になる）

#### 完了チェックポイント（ステップ2）

- マージ方法が選択されていること
- ユーザーの確認が得られていること（推奨方法をデフォルトとして提示する）

### ステップ3: マージの実行

選択したマージ方法でマージを実行する:

Squash merge の場合:
```bash
gh pr merge --squash --delete-branch
```

Merge commit の場合:
```bash
gh pr merge --merge --delete-branch
```

Rebase merge の場合:
```bash
gh pr merge --rebase --delete-branch
```

- `--delete-branch` フラグでリモートブランチを自動削除する

マージ後に確認する:
```bash
gh pr view --json state
```

#### 完了チェックポイント（ステップ3）

- PRがマージされていること（state: MERGED）
- リモートブランチが削除されていること

### ステップ4: クリーンアップ

1. mainブランチに切り替える:
   ```bash
   git checkout main
   ```

2. リモートの変更を取り込む:
   ```bash
   git pull origin main
   ```

3. ローカルのフィーチャーブランチを削除する:
   ```bash
   git branch -d フィーチャーブランチ名
   ```
   - `-d` フラグはマージ済みブランチのみ削除（安全）
   - 削除できない場合は `-D` を使う前にAskUserQuestionで確認する

4. 不要になったリモートトラッキングブランチを削除する:
   ```bash
   git remote prune origin
   ```

5. 完了報告をユーザーに提示する:
   - マージ済みPR番号とタイトル
   - mainブランチが最新であること
   - `.claude/artifacts/` の成果物を削除してよいか確認する（任意）

#### 完了チェックポイント（ステップ4）

- mainブランチに切り替わっていること
- `git pull` でmainが最新化されていること
- ローカルのフィーチャーブランチが削除されていること
- 完了報告がユーザーに提示されていること

## Examples

### PR #42 をマージする

ユーザー: 「マージして」

```
ステップ1: PR状態確認
  PR #42: feat: 通知バッジコンポーネントを追加
  CI: 全チェック通過 ✓
  レビュー: 承認済み（yamada-san） ✓
  コンフリクト: なし ✓

ステップ2: マージ方法選択
  「Squash mergeでマージしてよいですか？（推奨: コミット履歴がシンプルになります）」
  → ユーザー承認

ステップ3: マージ実行
  gh pr merge --squash --delete-branch
  PR #42: MERGED ✓

ステップ4: クリーンアップ
  git checkout main
  git pull origin main
  git branch -d feat/notification-badge
  git remote prune origin

  完了: PR #42 をSquash mergeしました。
  mainブランチを最新化し、フィーチャーブランチを削除しました。
```

### CI失敗でマージできない場合

```
ステップ1: PR状態確認
  CI: unit-tests が失敗 ✗

「CIが失敗しています（unit-tests）。
 マージ前にCI失敗を修正しますか？（推奨）
 それとも状況を確認しますか？」
→ 修正する → odin-do-implementまたは直接修正を案内する
```
