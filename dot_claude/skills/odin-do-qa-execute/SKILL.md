---
name: odin-do-qa-execute
description: QA試験の実行とエビデンス収集。QA試験項目書を入力にPlaywright MCPで自動実行可能な項目を実行し、スクリーンショット・ログ付きレポートを生成する。手動項目はチェックリスト形式で出力する。「QAを実行して」「テストを実行して」「エビデンスを取って」などで起動。odinから自動起動される場合もある。
user-invocable: true
allowed-tools: Bash, Read, Write, Grep, Glob, AskUserQuestion, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_type, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_select_option, mcp__plugin_playwright_playwright__browser_file_upload, mcp__plugin_playwright_playwright__browser_hover, mcp__plugin_playwright_playwright__browser_press_key, mcp__plugin_playwright_playwright__browser_wait_for, mcp__plugin_playwright_playwright__browser_resize, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_network_requests, mcp__plugin_playwright_playwright__browser_console_messages, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_navigate_back, mcp__plugin_playwright_playwright__browser_tabs, mcp__plugin_playwright_playwright__browser_close, mcp__plugin_playwright_playwright__browser_handle_dialog, mcp__plugin_playwright_playwright__browser_drag, mcp__plugin_playwright_playwright__browser_run_code
---

# odin-do-qa-execute

QA試験実行スキル。odin司令塔のdoフェーズで使用する。
QA試験項目書を入力とし、Playwright MCPで自動実行可能な項目を実行してエビデンス付きレポートを生成する。手動項目はチェックリスト形式で出力する。

Playwrightは手動テストの代替ツールとして使用する。E2Eテストフレームワークとしてではなく、QAチームが手動で行うブラウザ操作をPlaywright MCP経由で自動化し、エビデンスを収集する。

## ガードレール（安全制御）

このスキルは以下の安全制御を遵守する:

- git操作は一切実行しない（git push / git commit / git reset --hard等。レポートのコミットはodin-do-commitの責務）
- Bashツールの用途はscreenshotsディレクトリ操作・ファイルコピー・出力ディレクトリ確認に限定する
- テスト対象アプリケーションのデータを破壊的に変更しない（テスト用データのみ操作）
- Playwright MCPのbrowser_evaluateで本番データを変更するスクリプトを実行しない
- テスト失敗時も全テストケースを最後まで実行する（途中中断しない）

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
    "task": "QA試験の自動実行",
    "target_area": "Dev環境",
    "focus": ["自動テスト実行", "エビデンス収集"],
    "constraints": ["テスト用データのみ操作", "本番データ変更禁止"],
    "artifacts": {
      "qa_test_items": ".claude/artifacts/qa-test-items-20260402-1500.md"
    },
    "qa_params": {
      "test_url": "https://dev.example.com",
      "test_data_env_var": "QA_TEST_CREDENTIALS"
    }
  }
}
```

- odinコンテキストがある場合: artifactsからQA試験項目書のパスを取得し、qa_paramsからテスト対象URLを取得する
- odinコンテキストがない場合: 成果物管理ルールに従いQA試験項目書を探索する

テスト用認証情報はJSON平文に含めず、環境変数またはAskUserQuestionで実行時に取得する。

### 成果物管理

入力ファイルの探索順序:
1. $ARGUMENTSにファイルパスが明示指定されていればそれを使う
2. odinコンテキストのartifactsにパスがあればそれを使う
3. `.claude/artifacts/` 内の最新の `qa-test-items-*.md` を使う
4. 該当ファイルが見つからない場合はAskUserQuestionでユーザーに確認する

出力ファイル:
- `.claude/artifacts/qa-report-{yyyyMMdd-HHmm}.md`
- `.claude/artifacts/screenshots/{TC-ID}-{状態}-{yyyyMMdd-HHmm}.png`

エビデンス命名規則:
- 「状態」の定義: テスト結果を示す `pass` / `fail` または操作段階を示す `before` / `after` / `step-{N}`
- 例: `TC-001-pass-20260402-1530.png`, `TC-005-fail-20260402-1535.png`, `TC-003-step-2-20260402-1532.png`

### ステップ1: 入力読み込み・環境確認

1. QA試験項目書を読み込む
2. 自動/手動の分類を確認し、実行対象のテストケース一覧を把握する
3. Playwright MCPの出力ディレクトリを確認する（デフォルト: `.playwright-mcp/`）
4. テスト対象URLの疎通確認を行う（browser_navigateで接続テスト）
5. テストデータ（認証情報等）をAskUserQuestionで確認する
6. `.claude/artifacts/screenshots/` ディレクトリを作成する

#### 完了チェックポイント（ステップ1）

- 試験項目書が正常に読み込めていること
- テスト対象URLにアクセスできること
- テストデータが揃っていること
- Playwright MCPの出力ディレクトリが把握できていること

### ステップ2: 実行計画生成

1. 自動テストケースを依存順にソートする
   - 認証が必要なケースの前にログインテストを配置する
   - 同一画面のテストをグループ化する（画面遷移回数を最小化）
2. ブラウザセッション管理の計画を立てる:
   - 認証状態を共有できるケースをグループ化する
   - ブラウザリサイズが必要なケース（レスポンシブ確認）は後回しにする
3. 各テストケースの実行手順をPlaywright MCPツールにマッピングする:

| テスト手順の動作 | Playwright MCPツール |
|----------------|---------------------|
| URLに遷移 | browser_navigate |
| ボタン/リンクをクリック | browser_click |
| テキスト入力 | browser_type / browser_fill_form |
| セレクトボックス選択 | browser_select_option |
| ファイルアップロード | browser_file_upload |
| ホバー | browser_hover |
| キーボード操作 | browser_press_key |
| 待機 | browser_wait_for |
| 画面サイズ変更 | browser_resize |
| ページ内容確認 | browser_snapshot |
| スクリーンショット | browser_take_screenshot |
| APIレスポンス確認 | browser_network_requests |
| コンソール確認 | browser_console_messages |
| JS実行 | browser_evaluate |
| 複合操作・カスタムロケーター | browser_run_code（フォールバック） |

個別ツールで対応できない操作（特定のAPIレスポンス待機後のクリック、複雑なセレクター指定、複数ステップの原子的実行等）は `browser_run_code` にフォールバックする。

#### 完了チェックポイント（ステップ2）

- 実行順序が決定していること
- 全テストケースの手順がPlaywrightツールにマッピングされていること

### ステップ3: 自動テスト実行ループ

各テストケースについて以下を実行する:

1. browser_navigate でテスト対象画面に遷移する
2. テスト手順に従い操作を実行する（click/type/fill_form等）
3. 各手順後に browser_snapshot でアクセシビリティツリーを取得する
4. 期待結果との照合を行う:
   - テキスト内容の一致確認（アクセシビリティツリーのテキストノード）
   - 要素の存在確認（ロール・名前ベース）
   - URL確認（browser_navigateの結果）
   - HTTPステータス確認（browser_network_requests）
   - 注意: browser_snapshotはDOM構造のテキスト表現を返すため、CSSスタイル（色・サイズ・位置）の検証はできない。視覚的検証が必要な場合はbrowser_evaluateでcomputedStyleを取得するか、手動テストに分類する
5. エビデンスを収集する:
   - browser_take_screenshot でスクリーンショットを撮影する
   - browser_network_requests でAPIレスポンスを記録する
   - browser_console_messages でコンソールエラーを確認する
6. PASS/FAIL判定を記録する

失敗時の処理:
- FAILスクリーンショットを撮影する
- コンソールエラー・ネットワークエラーを詳細記録する
- 次のテストケースに進む（中断しない）
- リトライ方針: ネットワークタイムアウト・要素未検出等の一時的エラーのみ最大3回リトライする（リトライ間隔2秒）。アサーション失敗（期待結果と実際が異なる）はリトライせず即FAILとして記録する
- 3回リトライ後も失敗した場合はFAILとして記録する（SKIPにしない）

エビデンス保存フロー:
- browser_take_screenshotのfilenameパラメータに命名規則に従った名前を指定して撮影する
- Playwright MCPの `--output-dir` に保存される
- 撮影後、Bashツールで `.claude/artifacts/screenshots/` にコピーする
  ```bash
  cp {playwright_output_dir}/{filename}.png .claude/artifacts/screenshots/{TC-ID}-{状態}-{date}.png
  ```
- 代替手段: `browser_run_code` で `page.screenshot({ path: '.claude/artifacts/screenshots/{name}.png' })` を使い直接保存も可能

ブラウザセッション障害時のリカバリ:
- ブラウザクラッシュ・タイムアウトで応答がない場合、browser_closeで既存セッションを閉じ、browser_navigateで新規セッションを開始する
- リカバリ後、障害発生時のテストケースから再開する

パフォーマンス最適化:
- browser_snapshot（テキスト）を検証に使い、browser_take_screenshot（画像）はエビデンス用に限定する（トークン効率が約10〜100倍異なる）
- 同一画面内の複数テストはナビゲーションを共有する

#### 完了チェックポイント（ステップ3）

- 全自動テストケースが実行されていること
- 各テストケースにPASS/FAIL/SKIPが記録されていること
- エビデンス（スクリーンショット）が保存されていること

### ステップ4: 手動テスト用チェックリスト生成

手動テストケースを実行しやすいチェックリスト形式に変換する。優先度順に並べる。

```markdown
## 手動テスト チェックリスト

### 高優先度（P0-P1）

- [ ] TC-020: 印刷レイアウトが正しいこと
  - 前提: ダッシュボードにデータが表示されている
  - 手順:
    1. ブラウザの印刷プレビューを開く（Ctrl+P）
    2. 用紙サイズA4横を選択
  - 確認点:
    - ヘッダー・フッターの位置が正しい
    - 改ページ位置がデータの途中で切れない
    - グラフが完全に表示される
  - エビデンス記録欄: ___

### 中優先度（P2-P3）

- [ ] TC-025: ...
```

#### 完了チェックポイント（ステップ4）

- 全手動テストケースがチェックリストに含まれていること

### ステップ5: レポート生成

1. `.claude/artifacts/` ディレクトリにレポートを出力する
2. 現在時刻を取得し、`yyyyMMdd-HHmm` 形式のタイムスタンプを生成する
3. 自動テスト結果と手動チェックリストを統合したレポートを生成する

出力先: `.claude/artifacts/qa-report-{yyyyMMdd-HHmm}.md`

```markdown
# QA検証レポート

## メタ情報
- 対象機能: {機能名}
- 試験項目書: {qa-test-items-*.md のパス}
- テスト対象URL: {url}
- 実行日時: {date}
- 実行環境: {Chromium / macOS}

## テスト結果サマリー

| 区分 | PASS | FAIL | SKIP | 未実行(手動) | 合計 |
|------|------|------|------|-------------|------|
| 自動 | -    | -    | -    | -           | -    |
| 手動 | -    | -    | -    | -           | -    |
| 合計 | -    | -    | -    | -           | -    |

SKIPの定義: テスト対象URLへの到達不能、前提条件の未充足（依存テストがFAILの場合等）、ブラウザセッション障害からのリカバリ不能でテスト実行自体ができなかった場合。アサーション失敗はFAIL（SKIPにしない）。

## 不具合一覧（FAILケース）

| TC-ID | テスト名 | 期待結果 | 実際の結果 | 重大度 |
|-------|---------|---------|-----------|--------|
| TC-005 | ... | ... | ... | High |

## 自動テスト結果詳細

### TC-001: {テスト名} [PASS]

- 実行時間: {n}秒
- エビデンス:

![{説明}](screenshots/TC-001-pass-{date}.png)

- API: {メソッド} {パス} → {ステータス}
- コンソールエラー: なし

### TC-005: {テスト名} [FAIL]

- 実行時間: {n}秒
- 期待: {期待結果}
- 実際: {実際の結果}
- エビデンス:

![{説明}](screenshots/TC-005-fail-{date}.png)

- コンソールエラー: {エラー内容}
- ネットワークエラー: {該当あれば}

## 手動テスト チェックリスト

（ステップ4の出力をここに配置）
```

4. レポートの要約をユーザーに提示する
5. odinから呼ばれた場合は、出力ファイルパスをodinに返す

#### 完了チェックポイント（ステップ5）

- `.claude/artifacts/qa-report-*.md` が出力されていること
- 全テストケースの結果が含まれていること
- エビデンス画像がMarkdownから正しく参照されていること

## Examples

### QA試験の自動実行

ユーザー: 「QA試験項目書をもとにテストを実行して」

```
ステップ1: 入力読み込み
  試験項目書: .claude/artifacts/qa-test-items-20260402-1500.md
  テスト対象URL: https://dev.example.com
  自動テスト: 18件、手動テスト: 6件
  → URLにアクセス可能、テストデータ確認済み

ステップ2: 実行計画
  グループA（認証不要）: TC-001〜TC-003
  グループB（認証後）: TC-004〜TC-015（ログイン後の画面操作）
  グループC（レスポンシブ）: TC-016〜TC-018（リサイズが必要）

ステップ3: 自動実行
  TC-001: /login ページ表示 → PASS（2.1秒）
  TC-002: ログイン操作 → PASS（3.5秒）
  TC-003: ダッシュボード表示 → PASS（1.8秒）
  ...
  TC-012: バリデーションエラー → FAIL（エラーメッセージ未表示）
  ...
  結果: PASS 16件, FAIL 1件, SKIP 1件

ステップ4: 手動チェックリスト
  6件の手動テストをチェックリスト形式で出力

ステップ5: レポート出力
  → .claude/artifacts/qa-report-20260402-1530.md
  → .claude/artifacts/screenshots/ に18枚のスクリーンショット
```
