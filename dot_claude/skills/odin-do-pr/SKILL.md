---
name: odin-do-pr
description: ブランチ確認・フルレビュー・push・Draft PR作成まで一括実行する。odin-talk-review連携で5種レビュー（code-reviewer + security-reviewer + simplify + coderabbit + codex）を実施。「PRを作って」「プルリクを作って」「PR出して」などで起動。odinから自動起動される場合もある。
user-invocable: true
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, Skill, AskUserQuestion
---

# odin-do-pr

PR作成スキル。odin司令塔のdoフェーズで使用する。
ブランチの確認・作成からリモートへのpush、セルフレビュー、Draft PR作成まで一括で実行する。

## コンテキスト検出

### odinコンテキストがある場合（$ARGUMENTSにodin_contextが含まれる場合）
- odinから自動呼び出しされている
- ブランチ名・PR説明文はコンテキストから自動生成する
- セルフレビューの結果はコンテキストの成果物から参照する
- 未コミット変更がある場合はodin-do-commitスキルを自動的に呼び出してからPR作成に進む

### odinコンテキストがない場合（ユーザー直接呼び出し）
- git logとdiffから変更内容を分析してPR説明文を生成する
- セルフレビューを実行する
- 未コミット変更がある場合はAskUserQuestionで「未コミットの変更があります。先にコミットしますか？」と確認する

## ガードレール（安全制御）

このスキルは以下の安全制御を遵守する:

- 保護ブランチ（main, develop, epic/*）への直接pushを禁止する。push前に必ず `git branch --show-current` で確認し、該当する場合は即座に中断する
- `git push --force` / `git push --force-with-lease` を全ブランチで禁止する。通常の `git push -u origin ブランチ名` のみ使用する
- PRは必ず `--draft` フラグ付きで作成する。`--draft` なしの `gh pr create` を実行しない
- `git reset --hard` / `git checkout .` / `git clean -f` 等の破壊的操作を実行しない

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

### ステップ1: ブランチの確認と作成

1. 現在のブランチと未コミット変更を確認する:
   ```bash
   git branch --show-current
   git status --short
   ```

2. 未コミット変更がある場合:
   - odinコンテキストがある場合: odin-do-commitスキルを自動的に呼び出してコミットしてからPR作成に進む
   - ユーザー直接呼び出しの場合: AskUserQuestionで「未コミットの変更があります。先にコミットしますか？」と確認する
   - コミットが完了したら次の手順に進む

3. ブランチ名の形式を確認する:
   - 推奨形式: `{type}/{description}`
   - type: `feat`, `fix`, `refactor`, `docs`, `chore` など
   - description: 機能内容を英語で短縮（kebab-case）
   - 例: `feat/notification-badge`, `fix/login-redirect`

4. ブランチが適切でない場合（保護ブランチ（main, develop, epic/*）、または命名規則に合わない場合）:
   - AskUserQuestionでブランチ名を確認する
   - 新しいブランチを作成する:
     ```bash
     git checkout -b feat/機能名
     ```

5. コミットが存在することを確認する:
   ```bash
   git log --oneline main..HEAD
   ```
   - コミットがない場合はodin-do-commitスキルを先に実行するよう案内する

#### 完了チェックポイント（ステップ1）

- ブランチが `{type}/{description}` 形式であること
- 保護ブランチでないこと（ガードチェック通過済み）
- コミットが1つ以上存在すること

### ステップ1.5: PRサイズチェック

1. 変更行数を取得する:
   ```bash
   git diff --stat $(git merge-base HEAD main)..HEAD | tail -1
   ```

2. 例外ファイルを除外した実質行数を算出する:
   - *.lock, *.generated.*, prisma/migrations/*, *.snap 等は除外
   - git diff --numstat で行単位集計し、除外パターンをフィルタ

3. PRサイズガイドラインに基づき判定する:
   - 400行以下: 続行
   - 401-600行（ソフトリミット超過）:
     - 例外ケース該当: 続行（PR本文に例外理由を記載）
     - 非該当: AskUserQuestionで分割を提案
       「PRが{N}行あり、ソフトリミット(400行)を超えています。
        1. 分割案を提示して分割する
        2. このまま続行する（警告付き）」
   - 601行以上（ハードリミット超過）:
     - 例外ケース該当: 続行（PR本文に例外理由を記載）
     - 非該当: 分割を強く推奨。AskUserQuestionで確認
       「PRが{N}行あり、ハードリミット(600行)を超えています。
        このサイズではレビュー品質が大幅に低下します（欠陥検出率42%以下）。
        1. 分割案を提示して分割する
        2. 例外として続行する（理由を入力）」

4. 分割する場合:
   - Stacked PRsの戦略を提案
   - 最初のPRに含める変更を選別
   - 残りの変更は次のPRとして保留

#### 完了チェックポイント（ステップ1.5）

- PRサイズが確認されていること
- ソフトリミット超過時にユーザー確認が取れていること
- ハードリミット超過時に分割または例外承認が得られていること

### ステップ2: フルレビューの実施

Skillツールで `odin-talk-review` を実行し、多角的なフルレビューを実施する。

1. Skillツールで `odin-talk-review` を実行する:
   - odin-talk-reviewは以下の5つのレビューを並列実行する:
     - code-reviewer（品質・保守性）
     - security-reviewer（OWASP Top 10ベース）
     - simplify（再利用性・効率性）
     - coderabbit:code-reviewer（プラグイン未インストール時はスキップ）
     - codex:review（プラグイン未インストール時はスキップ）
   - odinコンテキストがある場合はそのまま渡す

2. odin-talk-reviewの結果を確認する:
   - 重大な問題がある場合:
     - AskUserQuestionで「PR作成前に修正しますか？」を確認する
     - 修正する場合はodin-do-refactorまたは直接修正してからodin-do-commitを実行する
     - 修正しない場合はPR本文に既知の問題として記載する

3. リモートにpushする:
   ```bash
   # ガードチェック: 保護ブランチでないことを確認
   CURRENT_BRANCH=$(git branch --show-current)
   if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ] || [ "$CURRENT_BRANCH" = "develop" ] || [[ "$CURRENT_BRANCH" == epic/* ]]; then
     echo "ERROR: 保護ブランチ（main, develop, epic/*）への直接pushは禁止されています" && exit 1
   fi
   git push -u origin "$CURRENT_BRANCH"
   ```
   - レビュー完了フラグはodin-talk-review（ステップ4.5）が自動作成するため、ここでは作成しない

#### 完了チェックポイント（ステップ2）

- odin-talk-reviewによるフルレビューが完了していること（5レビュー。プラグイン未インストール分はスキップ可）
- 重大な問題がない（または対応方針が決まっていること）
- リモートへのpushが成功していること（--forceフラグなし）

### ステップ3: Draft PRの作成

1. PRテンプレートを確認する:
   ```bash
   ls .github/pull_request_template.md 2>/dev/null || echo "テンプレートなし"
   ```

2. コミット履歴とdiffからPR本文を作成する:
   ```bash
   git log --oneline main..HEAD
   git diff $(git merge-base HEAD main)..HEAD --stat
   ```

3. 既存PRのタイトルパターンを取得する:
   ```bash
   gh pr list --state all --limit 10 --json title --jq '.[].title'
   ```
   取得したタイトルから命名パターン（prefix形式、言語、長さ、区切り文字等）を分析する。

4. PRタイトルと本文を作成する:

   タイトルの基準:
   - 手順3で分析した既存パターンに合わせる（最優先）
   - 70文字以内
   - パターンが検出できない場合のデフォルト: Conventional Commits形式prefix + 日本語
   - 例: `feat: 通知バッジコンポーネントを追加`

   本文の構成（テンプレートがない場合）:
   ```markdown
   ## 概要

   - {変更の目的・背景を1〜3行で}

   ## 変更内容

   - {主な変更点を箇条書きで}
   - {ファイル: 何を変更したか}

   ## テスト

   - [ ] ユニットテストが全て通過していること（`pnpm vitest run`）
   - [ ] 型チェックが通過していること
   - [ ] lintエラーがないこと
   - [ ] 手動確認: {確認した動作}

   ## レビュー観点

   - {特に見てほしい箇所・懸念点}

   ## 既知の問題（あれば）

   - {レビューで指摘された問題と対応方針}

   ## PRサイズ

   - 変更行数: {N}行（除外ファイル: {M}行）
   - PRサイズ区分: {理想/良好/許容/警告/超過}
   - 関連チケット: {チケットURL}
   ```

5. Draft PRを作成する:
   ```bash
   gh pr create --draft --title "PRタイトル" --body "$(cat <<'EOF'
   ## 概要
   ...
   EOF
   )"
   ```

6. PR URLをユーザーに提示する

#### 完了チェックポイント（ステップ3）

- PRタイトルが70文字以内であること
- PR本文に概要・変更内容・テスト確認事項が記載されていること
- Draft PRが作成されていること（`gh pr view` で確認）
- PR URLがユーザーに提示されていること

## Examples

### 通知機能のPRを作成する

ユーザー: 「PRを作って」

```
ステップ1: ブランチ確認
  現在: feat/notification-badge ✓
  コミット: 3件確認

ステップ2: フルレビュー（odin-talk-review委譲）
  5種並列: code-reviewer + security-reviewer + simplify + coderabbit + codex
  結果: 改善提案1件（関数の命名）、重大問題なし
  → PR本文にレビュー観点として記載
  レビュー完了フラグ（talk-review作成済み） + git push -u origin feat/notification-badge → 成功

ステップ3: Draft PR作成
  タイトル: feat: 通知バッジコンポーネントを追加
  本文: 概要・変更内容・テスト確認事項を記載
  gh pr create --draft → https://github.com/.../pull/42

PR作成完了: https://github.com/.../pull/42
```
