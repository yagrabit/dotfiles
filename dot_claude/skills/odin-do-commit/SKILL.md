---
name: odin-do-commit
description: 変更分析・セキュリティチェック・グループ化・コミットをConventional Commits形式で実行する。「コミットして」「変更をコミットして」「git commitして」などで起動。odinから自動起動される場合もある。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# odin-do-commit

Conventional Commitsコミットスキル。odin司令塔のdoフェーズで使用する。
変更内容を分析し、セキュリティチェックを行い、適切なグループに分けてコミットする。
コミットメッセージは「なぜ」を重視した日本語で記述する。

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

### ステップ1: 変更の確認

1. 変更状況を確認する:
   ```bash
   git status
   ```

2. 変更の詳細を確認する:
   ```bash
   git diff
   git diff --cached
   ```

3. 変更ファイルを一覧する:
   ```bash
   git diff --name-status
   git diff --cached --name-status
   ```

4. 最近のコミット履歴を確認する（メッセージスタイルの参考）:
   ```bash
   git log --oneline -10
   ```

#### 完了チェックポイント（ステップ1）

- 変更ファイルの一覧が把握できていること
- 各ファイルの変更内容（追加・変更・削除）が確認できていること
- コミット対象の変更量が把握できていること

### ステップ2: セキュリティチェック

変更内容にセキュリティリスクがないか確認する:

1. APIキー・トークン・シークレットの混入確認:
   ```bash
   git diff --cached | grep -iE "(api_key|secret|token|password|credential)" || true
   ```

2. .envファイル・設定ファイルの混入確認:
   ```bash
   git diff --cached --name-only | grep -E "^\.env|credentials\.json|\.pem$|\.key$" || true
   ```

3. 以下が混入していないことを確認する:
   - APIキー、アクセストークン、シークレット
   - `.env` ファイル・`.env.local` ファイル
   - 認証情報ファイル（credentials.json等）
   - 秘密鍵（*.pem, *.key）

4. 問題が見つかった場合:
   - AskUserQuestionで「このファイルをコミットしてよいか」を確認する
   - ユーザーの明示的な承認がない限りコミットしない
   - `.gitignore` への追加を提案する

#### 完了チェックポイント（ステップ2）

- セキュリティリスクのあるファイルが含まれていないこと
- 問題が見つかった場合はユーザーに確認済みであること

### ステップ3: コミット計画の作成

変更の内容と目的を分析し、コミットのグループ分けを計画する:

コミット分割の基準:
- 異なる目的の変更は別コミットに分ける（機能追加 + バグ修正 → 2コミット）
- 同じ目的の変更はまとめる（関連ファイルを一括コミット）
- 独立して意味をなす単位でコミットする

Conventional Commits フォーマット:
```
{type}({scope}): {概要（日本語、なぜを重視）
```

type の選択:
- `feat`: 新機能の追加
- `fix`: バグの修正
- `refactor`: 動作を変えないリファクタリング
- `test`: テストの追加・修正
- `docs`: ドキュメントの更新
- `style`: フォーマット・命名等のスタイル修正
- `chore`: ビルド・依存関係・設定の変更
- `perf`: パフォーマンス改善
- `ci`: CI/CD設定の変更

scope の指定（任意）:
- ファイル名・モジュール名・機能名を短縮形で記載
- 例: `notifications`, `auth`, `api`

コミットメッセージの原則:
- 「なぜ」変更したかを中心に記述する
- 「何を」変更したかはコードを見ればわかるので最小限に
- 簡潔に（概要は50文字以内を目安）
- 良い例: `feat(notifications): 未読数バッジを追加（ユーザーが見落としを防ぐため）`
- 悪い例: `update notifications`

コミット計画を提示する形式:
```
コミット1: feat(notifications): 通知作成APIを追加
  対象ファイル: src/app/api/notifications/route.ts, src/lib/notifications.ts

コミット2: test(notifications): 通知APIのユニットテストを追加
  対象ファイル: src/__tests__/notifications.test.ts
```

#### 完了チェックポイント（ステップ3）

- コミットのグループ分けが適切に行われていること
- 各コミットメッセージが Conventional Commits 形式であること
- コミットメッセージが「なぜ」を表現した日本語であること

### ステップ4: ユーザー承認

1. コミット計画をユーザーに提示する
2. AskUserQuestionで確認する:
   - 「このコミット計画で問題ありませんか？」
   - コミット数・メッセージ・対象ファイルを提示する
3. 修正要求があればコミット計画を更新する
4. 承認が得られたらステップ5へ進む

#### 完了チェックポイント（ステップ4）

- コミット計画がユーザーに提示されていること
- ユーザーの承認が明示的に得られていること

### ステップ5: コミットの実行

承認済みのコミット計画に従い、コミットを実行する:

1. 各コミットについて以下を実行する:

   a. 対象ファイルをステージングに追加する（具体的なファイル名で指定）:
      ```bash
      git add src/app/api/notifications/route.ts src/lib/notifications.ts
      ```
      - `git add -A` や `git add .` は使わない
      - ステージング対象を明示的に指定する

   b. コミットを作成する:
      ```bash
      git commit -m "$(cat <<'EOF'
      feat(notifications): 通知作成APIを追加

      ユーザーが通知を受け取れるようにするため、通知の作成・一覧取得・既読機能を実装。
      EOF
      )"
      ```

2. 複数コミットの場合は順番に実行する

3. コミット後に確認する:
   ```bash
   git log --oneline -5
   ```

#### 完了チェックポイント（ステップ5）

- 全コミットが実行されていること
- `git log` で各コミットメッセージが確認できること
- ステージングに残ったファイルがないこと（計画外のファイルが混入していないこと）

## Examples

### 機能実装後のコミット

ユーザー: 「コミットして」

```
ステップ1: 変更確認
  変更ファイル:
    M src/app/api/notifications/route.ts（新APIルート）
    M src/lib/notifications.ts（ビジネスロジック）
    M src/__tests__/notifications.test.ts（テスト追加）
    M src/components/NotificationBadge.tsx（UIコンポーネント）

ステップ2: セキュリティチェック
  APIキー・シークレットなし → OK

ステップ3: コミット計画
  コミット1: feat(notifications): 通知作成API・ビジネスロジックを追加
    → route.ts, notifications.ts
  コミット2: test(notifications): 通知APIのユニットテストを追加
    → notifications.test.ts
  コミット3: feat(notifications): 未読数バッジコンポーネントを追加
    → NotificationBadge.tsx

ステップ4: ユーザー承認
  「3コミットに分けますが問題ありませんか？」→ 承認

ステップ5: 実行
  git add src/app/api/notifications/route.ts src/lib/notifications.ts
  git commit -m "feat(notifications): ..."
  （以降同様）
```
