---
name: odin-do-pr-verify
description: PR URLを受け取り、関連情報収集→ターミナルチェック→Playwright MCPによる動作検証→レポート出力を一気通貫で実行する。PRの変更内容とチケット情報から検証項目を自動生成し、人間がQAするように動作確認する。「PRを動作確認して」「PR検証して」「PRの動作チェックして」などで起動。odinから自動起動される場合もある。
user-invocable: true
allowed-tools: Bash, Read, Write, Grep, Glob, Agent, Skill, AskUserQuestion, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_type, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_select_option, mcp__plugin_playwright_playwright__browser_file_upload, mcp__plugin_playwright_playwright__browser_hover, mcp__plugin_playwright_playwright__browser_press_key, mcp__plugin_playwright_playwright__browser_wait_for, mcp__plugin_playwright_playwright__browser_resize, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_network_requests, mcp__plugin_playwright_playwright__browser_console_messages, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_navigate_back, mcp__plugin_playwright_playwright__browser_tabs, mcp__plugin_playwright_playwright__browser_close, mcp__plugin_playwright_playwright__browser_handle_dialog, mcp__plugin_playwright_playwright__browser_drag, mcp__plugin_playwright_playwright__browser_run_code, mcp__plugin_atlassian_atlassian__getJiraIssue, mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql
---

# odin-do-pr-verify

PR動作検証スキル。PRのURLを受け取り、情報収集・ターミナルチェック・ブラウザ動作検証を一気通貫で実行し、エビデンス付きレポートを生成する。

人間のQAチームがPRを検証するプロセスを再現する:
1. PRの変更内容を理解する（何が変わったか）
2. チケットやPR説明から期待動作を把握する（どうあるべきか）
3. ビルド・lint・テストが通ることを確認する（壊れていないか）
4. ブラウザで実際に動かして確認する（正しく動くか）
5. 結果を報告する

Playwrightは手動テストの代替ツールとして使用する。E2Eテストフレームワークとしてではなく、QAチームが手動で行うブラウザ操作をPlaywright MCP経由で自動化し、エビデンスを収集する。

## ガードレール（安全制御）

- 許可するgit操作: `git branch --show-current`, `git checkout`, `git diff`, `git log` のみ。git push / git commit / 破壊的git操作（reset --hard, checkout ., clean -f）を実行しない（レポートのコミットはodin-do-commitの責務）
- テスト対象アプリケーションのデータを破壊的に変更しない（テスト用データのみ操作）
- Playwright MCPのbrowser_evaluateで本番データを変更するスクリプトを実行しない。テスト対象URLがlocalhostまたはdev/staging以外のパブリックURLの場合、browser_evaluate/browser_run_code実行前にAskUserQuestionで確認する
- テスト対象URLは `http://` または `https://` スキームのみ許可する。`file://`, `javascript:`, `data:` スキームは拒否する
- 認証情報はJSON平文に含めず、環境変数またはAskUserQuestionで実行時に取得する。レポートに認証情報の値を記録しない
- スクリーンショット撮影前に、認証トークン・個人情報等のセンシティブ情報が画面に表示されている場合は、可能な限りbrowser_evaluateで当該要素をマスクしてから撮影する
- browser_network_requestsの結果をレポートに記録する際、Authorization/Cookie/Set-Cookieヘッダーは除外する
- 検証失敗時も全検証項目を最後まで実行する（途中中断しない）

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

### コンテキスト検出

$ARGUMENTS を確認し、odinコンテキストJSONが含まれているか判定する。

odinコンテキストJSONの例:
```json
{
  "odin_context": {
    "task": "PR動作検証",
    "target_area": "PR #42",
    "focus": ["UI変更の動作確認", "API応答の検証"],
    "constraints": ["本番データ変更禁止"],
    "artifacts": {},
    "pr_params": {
      "pr_url": "https://github.com/owner/repo/pull/42",
      "test_url": "http://localhost:3000"
    }
  }
}
```

- odinコンテキストがある場合: pr_paramsからPR URL・テスト対象URLを取得する
- odinコンテキストがない場合: $ARGUMENTSからPR URLを抽出する。見つからなければAskUserQuestionで確認する

### 成果物管理

出力ファイル:
- `.claude/artifacts/pr-verify-{yyyyMMdd-HHmm}.md`
- `.claude/artifacts/screenshots/{項目ID}-{状態}-{yyyyMMdd-HHmm}.png`

エビデンス命名規則:
- 「状態」: テスト結果を示す `pass` / `fail` または操作段階を示す `before` / `after` / `step-{N}`
- 例: `V-001-pass-20260406-1530.png`, `V-003-fail-20260406-1535.png`

---

### ステップ1: PR情報収集

1. PR URLを検証する:
   - `https://github.com/{owner}/{repo}/pull/{number}` パターンに一致することを確認する
   - 一致しない場合はAskUserQuestionで正しいURLを再入力してもらう
   - PR番号のみの指定（`#42` 等）の場合は、カレントリポジトリのPRとして `gh pr view 42` で取得する

2. gh CLIでPR情報を取得する:
   ```bash
   gh pr view {PR_URL} --json number,title,body,labels,headRefName,baseRefName,files,additions,deletions,reviewDecision,statusCheckRollup
   ```

3. PR差分を取得する:
   ```bash
   gh pr diff {PR_URL}
   ```

4. リンクされたチケットを探索する:
   - PR本文からチケットIDを正規表現で抽出する
     - Jira: `[A-Z]+-\d+`（例: VIV-123）
     - GitHub Issues: `#\d+`, `GH-\d+`, `closes #\d+`, `fixes #\d+`
   - CLAUDE.local.mdのプロジェクト管理設定を確認する
   - Jira: `mcp__plugin_atlassian_atlassian__getJiraIssue` でチケット詳細を取得する
   - GitHub Issues: `gh issue view {number}` で詳細を取得する
   - チケットがない場合もエラーにせず、PR本文のみで進行する

5. CI状態を確認する:
   - statusCheckRollupからCI結果を把握する
   - 失敗しているチェックがあれば記録する

#### 完了チェックポイント（ステップ1）

- PR情報（タイトル・説明・変更ファイル一覧・差分）が取得できていること
- リンクチケットの探索が完了していること（チケットなしも可）
- CI状態が把握できていること

---

### ステップ2: 変更分析・検証項目生成

PR差分・PR説明・チケット情報を総合して検証項目を生成する。

#### 2-1. 変更内容の分類

変更ファイルを以下のカテゴリに分類する:

| カテゴリ | ファイルパターン例 | 検証方法 |
|---------|------------------|---------|
| UI/フロントエンド | *.tsx, *.jsx, *.vue, *.svelte, *.css, *.scss | ブラウザ検証 |
| API/バックエンド | */api/*, */routes/*, */controllers/* | ターミナル + ブラウザ（APIレスポンス） |
| ビジネスロジック | */services/*, */utils/*, */lib/* | ターミナル（テスト実行） |
| 設定/インフラ | *.config.*, Dockerfile, *.yml | ターミナル（ビルド確認） |
| テスト | *.test.*, *.spec.* | ターミナル（テスト実行） |
| ドキュメント | *.md, *.txt | 目視確認（手動） |

#### 2-2. 期待動作の推論

以下の情報源から「どうあるべきか」を推論する（優先順）:

1. チケットの受入条件（Acceptance Criteria）・説明
2. PR本文の説明・変更理由
3. PR差分に含まれるテストの期待値（expect/assert文）
4. 変更前のコードから推測される既存動作への影響

推論できない場合はAskUserQuestionで確認する。以下のケースでは必ず質問する:

- UI変更があるがモックアップ・スクリーンショットがPR/チケットにない
- 新規機能だがチケット/PR説明に具体的な動作記述がない
- 複数の解釈が可能な仕様変更

質問の形式:
```
PR #{number} の検証項目を作成中です。以下の点が不明です:

1. {変更ファイル}の変更について:
   - 変更内容: {何が変わったかの要約}
   - 不明点: {具体的に何がわからないか}
   - 選択肢（あれば）:
     a. {解釈A}
     b. {解釈B}
     c. 直接説明する
```

#### 2-3. 検証項目の生成

各変更に対して検証項目を生成する。項目の粒度は「1つの操作 → 1つの確認」を基本とする。

```markdown
### V-{連番}: {検証名}

- 対象: {変更ファイル or 機能名}
- 検証方法: {ターミナル / ブラウザ / 手動}
- 期待動作: {具体的な期待結果}
- 情報源: {チケット / PR説明 / テストコード / ユーザー確認}
- 手順:
  1. {操作手順}
  2. ...
- 確認点:
  - {チェックすべきポイント}
```

ブラウザ検証項目には実行ヒントを追加する:
```markdown
- 実行ヒント:
  - start_url: {テスト開始URL}
  - 検証対象: {確認すべきテキスト・要素・URL}
  - 待機条件: {操作後に待つべきイベント}
```

#### 2-4. 検証項目のピアレビュー

生成した検証項目を `.claude/artifacts/pr-verify-items-draft.md` に一時書き出し、odin-auto-peer-reviewでレビューする。
Skillツールで `odin-auto-peer-review` を呼び出し、ファイルパスを引数に渡す。レビュー観点:
- 検証項目がPR差分の全変更をカバーしているか
- 期待動作の記述が具体的か（曖昧な表現がないか）
- 漏れている観点はないか（正常系・異常系・境界値・回帰）

レビューは1イテレーションで完了とする（検証項目は設計書ほど重厚でないため、フルの反復ループは不要）。指摘があれば修正してから次のステップに進む。レビュー完了後、draftファイルは削除する。

#### 完了チェックポイント（ステップ2）

- 全変更ファイルがいずれかのカテゴリに分類されていること
- 各検証項目に具体的な期待動作が記述されていること（推論不可の項目はユーザーに確認済み）
- 検証方法（ターミナル/ブラウザ/手動）が全項目に付与されていること
- ピアレビューが完了し、指摘事項が解消されていること

---

### ステップ3: ターミナルチェック

PRブランチの状態でターミナルベースの検証を実行する。

#### 3-1. 現在のブランチ確認

```bash
git branch --show-current
```

- PRブランチ上にいる場合: そのまま進行する
- PRブランチ上にいない場合: AskUserQuestionで以下を確認する
  ```
  現在のブランチは {current_branch} です。PR #{number} のブランチ {head_branch} に切り替えますか？
  a. 切り替える（gh pr checkout で取得・切り替え）
  b. 現在のブランチのまま進める（レポートに注記を追加）
  c. ターミナルチェックをスキップする
  ```
  - 選択肢a: `gh pr checkout {PR_URL}` を使う（ローカルにブランチがなくてもfetch+checkoutされる）。未コミット変更がある場合はcheckoutが失敗するため、AskUserQuestionで「先にstashするか、現在のブランチのまま進めるか」を確認する
  - 選択肢b: レポートのメタ情報に「注意: PRブランチではなく {current_branch} 上で検証」と明記する

#### 3-2. ツーリング自動検出・実行

git rootで以下のファイルの有無からツーリングを自動検出し、順次実行する:

1. コード生成: codegen.ts → `pnpm codegen` / prisma/schema.prisma → `pnpm prisma generate`
2. ビルド: package.json(build) → `pnpm build` / tsconfig.json → `tsc --noEmit` / Cargo.toml → `cargo build`
3. lint: biome.json → `biome check .` / eslint.config.* → `eslint .` / ruff.toml → `ruff check .`
4. 型チェック: tsconfig.json → `tsc --noEmit` / pyproject.toml(pyright) → `pyright`
5. テスト: vitest.config.* → `pnpm vitest run` / jest.config.* → `pnpm jest` / Cargo.toml → `cargo test`
6. セキュリティ: pnpm-lock.yaml → `pnpm audit` / package-lock.json → `npm audit`

検出できないカテゴリはskip。各ステップの結果をpass/fail/skipで記録する。

#### 3-3. 変更関連テストの特定

PR差分の変更ファイルに対応するテストファイルを特定し、存在すれば個別実行結果も記録する。

```bash
# 例: 変更ファイルに対応するテストを検索
# src/components/Button.tsx → src/components/Button.test.tsx
# src/lib/auth.ts → src/lib/auth.test.ts
```

テストカバレッジの変化も可能であれば記録する。

#### 完了チェックポイント（ステップ3）

- ツーリング検出が完了していること
- 全チェックの結果がpass/fail/skipで記録されていること
- 変更関連テストが特定・実行されていること

---

### ステップ4: ブラウザ動作検証

ブラウザ検証項目がある場合のみ実行する。ブラウザ検証項目がなければスキップする。

#### 4-1. テスト対象URL確認

odinコンテキストのpr_params.test_urlがあればそれを使う。なければAskUserQuestionで確認する:

```
ブラウザで動作確認を行います。テスト対象のURLを教えてください。
（例: http://localhost:3000, https://dev.example.com）

ブラウザ検証をスキップする場合は「スキップ」と回答してください。
```

「スキップ」の場合はブラウザ検証項目を全て「未実行（手動）」としてステップ5に進む。

#### 4-2. 接続テスト

browser_navigateでテスト対象URLにアクセスし、到達可能であることを確認する。到達不能の場合はAskUserQuestionで再入力を促す（最大3回）。3回失敗した場合はブラウザ検証を全てスキップし、レポートに「接続不能のためブラウザ検証をスキップ」と記録する。

#### 4-3. エビデンスディレクトリ準備

```bash
mkdir -p .claude/artifacts/screenshots
```

#### 4-4. 検証実行ループ

odin-do-qa-executeと同じPlaywright実行パターンに従う。各検証項目について:

1. browser_navigate → 手順に従い操作 → browser_snapshot で期待動作と照合
2. browser_take_screenshot でエビデンス撮影 → `.claude/artifacts/screenshots/` に保存
3. PASS/FAIL/SKIP判定を記録（SKIP: 前提条件未充足・接続不能等で実行不能な場合のみ）

実行ルール:
- 失敗時もスクリーンショット+エラー詳細を記録し、次の項目に進む（中断しない）
- ネットワークタイムアウト・要素未検出は最大3回リトライ（間隔2秒）。アサーション失敗は即FAIL
- browser_snapshot（テキスト）を検証に使い、browser_take_screenshot（画像）はエビデンス用に限定する

#### 完了チェックポイント（ステップ4）

- 全ブラウザ検証項目が実行されていること（またはスキップの旨が記録されていること）
- 各項目にPASS/FAIL/SKIPが記録されていること
- エビデンス（スクリーンショット）が保存されていること

---

### ステップ5: レポート生成

1. `.claude/artifacts/` ディレクトリにレポートを出力する
2. 現在時刻を取得し、`yyyyMMdd-HHmm` 形式のタイムスタンプを生成する
3. 以下のフォーマットでレポートを生成する

出力先: `.claude/artifacts/pr-verify-{yyyyMMdd-HHmm}.md`

```markdown
---
odin_coherence:
  id: "pr-verify-{yyyyMMdd-HHmm}"
  kind: "pr-verify"
  depends_on: []
  updated: "{yyyy-MM-ddTHH:mm}"
---

# PR動作検証レポート

## 対象PR
- PR: {owner/repo}#{number} {title}
- ブランチ: {head} → {base}
- 変更規模: +{additions} / -{deletions}（{files}ファイル）
- 関連チケット: {ticket_id}（{ticket_title}）
- 検証日時: {date}
- テスト対象URL: {url}

## 総合判定

{PASS / FAIL / 要手動確認}

{1〜2文の総合コメント}

## 検証結果サマリー

| 区分 | PASS | FAIL | SKIP | 未実行(手動) | 合計 |
|------|------|------|------|-------------|------|
| ターミナル | - | - | - | - | - |
| ブラウザ | - | - | - | - | - |
| 手動 | - | - | - | - | - |
| 合計 | - | - | - | - | - |

## 不具合一覧（FAILケース）

| 項目ID | 検証名 | 区分 | 期待動作 | 実際の結果 |
|--------|--------|------|---------|-----------|
| V-005 | ... | ブラウザ | ... | ... |

## ターミナルチェック結果

| チェック | 結果 | コマンド | 備考 |
|---------|------|---------|------|
| ビルド | pass | pnpm build | - |
| lint | pass | biome check | warning 2件 |
| 型チェック | pass | tsc --noEmit | - |
| テスト | pass | vitest run | 50/50 passed |
| セキュリティ | skip | - | ツール未検出 |

### 変更関連テスト

| テストファイル | 結果 | テスト数 |
|-------------|------|---------|
| src/components/Button.test.tsx | pass | 5/5 |

## ブラウザ検証結果

（各検証項目: 期待動作・結果・エビデンス画像・コンソールエラー）

## 手動確認チェックリスト

- [ ] V-010: {検証名}
  - 確認点: {チェックすべきポイント}
  - 手順: {操作手順}
```

4. レポートの要約をユーザーに提示する
5. odinから呼ばれた場合は、出力ファイルパスをodinに返す

#### 完了チェックポイント（ステップ5）

- `.claude/artifacts/pr-verify-*.md` が出力されていること
- 全検証項目の結果が含まれていること
- エビデンス画像がMarkdownから正しく参照されていること
- レポートの要約がユーザーに提示されていること

---

## Examples

### 基本的なPR検証

ユーザー: 「このPRを動作確認して https://github.com/owner/repo/pull/42」

```
ステップ1: PR情報収集
  PR #42: 「通知バッジの表示を修正」
  変更: src/components/Header.tsx, src/hooks/useNotifications.ts (+25/-10, 2ファイル)
  チケット: VIV-456「ヘッダーの通知バッジが未読0件でも表示される」
  CI: 全チェック pass

ステップ2: 検証項目生成
  チケットの受入条件から期待動作を推論:
  - 未読0件 → バッジ非表示
  - 未読1件以上 → バッジに件数表示
  
  検証項目:
  V-001: 未読0件でバッジが非表示になること（ブラウザ）
  V-002: 未読3件でバッジに「3」と表示されること（ブラウザ）
  V-003: 未読99件超でバッジに「99+」と表示されること（ブラウザ）
  V-004: useNotificationsのテストが通ること（ターミナル）
  V-005: ビルド・lint・型チェックが通ること（ターミナル）
  
  → odin-auto-peer-reviewで検証項目をレビュー → 指摘なし

ステップ3: ターミナルチェック
  ビルド: pass
  lint: pass
  型チェック: pass
  テスト: pass (useNotifications.test.ts 5/5)

ステップ4: ブラウザ検証
  テスト対象URL: http://localhost:3000
  V-001: 未読0件 → バッジ非表示 → PASS
  V-002: 未読3件 → 「3」表示 → PASS
  V-003: 未読100件 → 「99+」表示 → PASS

ステップ5: レポート出力
  → .claude/artifacts/pr-verify-20260406-1500.md
  総合判定: PASS（全5項目 pass）
```

### 期待動作が不明で質問するケース

ユーザー: 「PR #88を検証して」

```
ステップ1: PR情報収集
  PR #88: 「ダッシュボードにチャートを追加」
  変更: src/pages/Dashboard.tsx, src/components/Chart.tsx (新規), +180/-5
  チケット: なし（PR本文に「チャートを追加した」としか書かれていない）
  CI: pass

ステップ2: 検証項目生成
  → チャートの種類・表示データ・インタラクションが不明
  
  質問:
  「PR #88 の検証項目を作成中です。以下の点が不明です:
  
  1. src/components/Chart.tsx（新規追加）について:
     - 変更内容: ダッシュボードにChart.jsベースのチャートコンポーネントを追加
     - 不明点: チャートに表示されるべきデータと、期待される見た目
     a. 売上データの棒グラフ
     b. アクセス数の折れ線グラフ
     c. 直接説明する」
  
  ユーザー回答: 「月別売上の棒グラフ。ホバーで金額が表示される」

  → 回答をもとに検証項目を生成
  V-001: ダッシュボードにチャートが表示されること
  V-002: 棒グラフに月別データが表示されること
  V-003: 棒にホバーすると金額がツールチップで表示されること
  V-004: チャートがレスポンシブであること（手動）
  ...
```
