---
name: odin-do-pr
description: ブランチ確認・push・セルフレビュー・Draft PR作成まで一括実行する。requesting-code-review連携でcode-reviewer + security-reviewerを並列実行。「PRを作って」「プルリクを作って」「PR出して」などで起動。odinから自動起動される場合もある。
user-invocable: true
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion
---

# odin-do-pr

PR作成スキル。odin司令塔のdoフェーズで使用する。
ブランチの確認・作成からリモートへのpush、セルフレビュー、Draft PR作成まで一括で実行する。

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

### ステップ1: ブランチの確認と作成

1. 現在のブランチを確認する:
   ```bash
   git branch --show-current
   git status
   ```

2. ブランチ名の形式を確認する:
   - 推奨形式: `{type}/{description}`
   - type: `feat`, `fix`, `refactor`, `docs`, `chore` など
   - description: 機能内容を英語で短縮（kebab-case）
   - 例: `feat/notification-badge`, `fix/login-redirect`

3. ブランチが適切でない場合（mainブランチ、または命名規則に合わない場合）:
   - AskUserQuestionでブランチ名を確認する
   - 新しいブランチを作成する:
     ```bash
     git checkout -b feat/機能名
     ```

4. コミットが存在することを確認する:
   ```bash
   git log --oneline main..HEAD
   ```
   - コミットがない場合はodin-do-commitスキルを先に実行するよう案内する

5. リモートにpushする:
   ```bash
   git push -u origin ブランチ名
   ```

#### 完了チェックポイント（ステップ1）

- ブランチが `{type}/{description}` 形式であること
- mainブランチでないこと
- コミットが1つ以上存在すること
- リモートへのpushが成功していること

### ステップ2: セルフレビューの実施

superpowers:requesting-code-review のパターンに従い、セルフレビューを実施する。

1. レビュー対象の差分を取得する:
   ```bash
   git diff $(git merge-base HEAD main)..HEAD
   git diff --name-only $(git merge-base HEAD main)..HEAD
   ```

2. code-reviewer と security-reviewer を並列で起動する:
   - Agentツールで code-reviewer サブエージェントを起動（品質・保守性の観点）
   - Agentツールで security-reviewer サブエージェントを起動（OWASP Top 10ベース）

3. レビュー結果を統合する:
   - 重大な問題（即座に修正が必要）
   - 改善提案（推奨）
   - 情報（参考）

4. 重大な問題がある場合:
   - AskUserQuestionで「PR作成前に修正しますか？」を確認する
   - 修正する場合はodin-do-refactorまたは直接修正してからodin-do-commitを実行する
   - 修正しない場合はPR本文に既知の問題として記載する

#### 完了チェックポイント（ステップ2）

- code-reviewer と security-reviewer のレビューが完了していること
- 重大な問題がない（または対応方針が決まっていること）

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

3. PRタイトルと本文を作成する:

   タイトルの基準:
   - 70文字以内
   - 日本語で変更の概要を記述
   - Conventional Commits形式のprefixを付ける（任意）
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
   ```

4. Draft PRを作成する:
   ```bash
   gh pr create --draft --title "PRタイトル" --body "$(cat <<'EOF'
   ## 概要
   ...
   EOF
   )"
   ```

5. PR URLをユーザーに提示する

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
  git push -u origin feat/notification-badge → 成功

ステップ2: セルフレビュー
  並列起動: code-reviewer + security-reviewer
  結果: 改善提案1件（関数の命名）、重大問題なし
  → PR本文にレビュー観点として記載

ステップ3: Draft PR作成
  タイトル: feat: 通知バッジコンポーネントを追加
  本文: 概要・変更内容・テスト確認事項を記載
  gh pr create --draft → https://github.com/.../pull/42

PR作成完了: https://github.com/.../pull/42
```
