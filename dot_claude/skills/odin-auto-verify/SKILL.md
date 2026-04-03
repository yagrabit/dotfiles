---
name: odin-auto-verify
description: タスク完了宣言の前にテスト・ビルド・lintを実行し、証拠付きで成果を検証する。superpowersのverification-before-completionと連携し、「検証なしに完了と言わない」原則を徹底する。タスク完了宣言前にPostToolUseフックが自動リマインドするほか、「検証して」「完了確認して」で単体起動。
user-invocable: false
allowed-tools: Bash, Read, Grep, Glob, Skill, AskUserQuestion
---

# odin-auto-verify

タスク完了宣言の前に、成果を証拠付きで検証する自動補助スキル。
superpowersの verification-before-completion スキルを呼び出して検証を実行する。

> superpowersプラグインが未インストールの場合: verification-before-completionの手順をスキップし、同等の検証（IDENTIFY→RUN→READ→VERIFY）を手動で実行する。

### コンテキスト検出

$ARGUMENTS を確認し、odinコンテキストJSONが含まれているか判定する。

- odinコンテキストがある場合: odinコンテキストのtask情報から検証対象を自動特定する
- odinコンテキストがない場合: 直近の作業内容から検証対象を推測する。不明な場合はユーザーに確認する

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

## 鉄則

検証なしに「完了」「修正済み」「テスト通過」と言ってはならない。
証拠が先、主張は後。

### ステップ1: 検証対象の特定

完了を主張する内容に応じて検証コマンドを決定する:

| 主張 | 必須の検証 | 不十分な検証 |
|------|-----------|-------------|
| テスト通過 | テスト実行して出力確認 | 前回の実行結果 |
| ビルド成功 | ビルド実行してexit 0確認 | lintの通過 |
| バグ修正 | 再現テストが通過 | コード変更のみ |
| lint通過 | lint実行して出力確認 | 部分チェック |
| 機能実装 | テスト通過 + 動作確認 | コード存在 |
| UI実装 | テスト通過 + ビジュアルQA確認 | テスト通過のみ |

#### 完了チェックポイント（ステップ1）

- 完了主張の内容が特定されていること
- 各主張に対する検証コマンドが決定されていること

### ステップ2: 検証実行

1. Skillツールで `superpowers:verification-before-completion` を実行する
2. 検証ゲート:
   - IDENTIFY: この主張は何で証明するか特定する
   - RUN: 完全なコマンドを新規実行する（キャッシュ不可）
   - READ: 出力全体と終了コードを確認する
   - VERIFY: 出力は主張を裏付けるか判定する
   ビジュアルQA（UI実装の場合）:
   - MCPの利用可能判定: ToolSearchツールで "chrome" または "playwright" を検索し、該当するMCPツールが返された場合に利用可能と判定する。ToolSearchで結果が0件の場合はビジュアルQAをスキップする。
   - Chrome MCP / Playwright MCPが利用可能な場合:
     - デスクトップ(1440px)とモバイル(390px)でスクリーンショットを取得する
     - コンソールエラーがないことを確認する
     - 主要なインタラクション（クリック、ホバー）が動作することを確認する
   - MCP未利用の場合:
     - `npx playwright test --update-snapshots` でベースラインを生成する（Playwrightが導入済みの場合）
     - 導入されていない場合はビジュアルQAをスキップし、その旨を報告する
3. 判定:
   - YES → 証拠付きで完了を報告する
   - NO → 実際のステータスを証拠付きで報告する

#### 完了チェックポイント（ステップ2）

- 全検証コマンドが新規実行されていること（キャッシュ不可）
- 各コマンドの出力と終了コードが確認されていること
- 失敗項目がある場合、その詳細（失敗テスト名・エラーメッセージ）が記録されていること
- 検証証拠（コマンド出力の要約）が結果報告に含められる状態であること

### ステップ3: 結果報告

検証結果を以下の形式で報告する:

```
## 検証結果

状態: PASS / FAIL

### 検証項目
- [PASS] テスト: vitest run → 50/50 passed (exit 0)
- [PASS] ビルド: tsc --noEmit → no errors (exit 0)
- [FAIL] lint: biome check → 2 errors found (exit 1)

### 証拠
（コマンド出力を添付）
```

FAILの場合は修正が必要な箇所を具体的に報告する。

#### 完了チェックポイント（ステップ3）

- 全検証項目のPASS/FAILが証拠付きで記録されていること
- FAIL項目がある場合、odinにエスカレーションされていること

## Examples

### 実装タスクの完了検証

```
ステップ1: 検証対象の特定
  タスク: 通知機能の実装
  主張: テスト通過、ビルド成功
  検証コマンド: pnpm vitest run, pnpm build, pnpm tsc --noEmit

ステップ2: 検証実行
  IDENTIFY: テスト・ビルド・型チェックで証明する
  RUN: 3コマンドを新規実行
  READ: 全出力を確認
  VERIFY:
    テスト: 12/12 passed (exit 0) → PASS
    ビルド: no errors (exit 0) → PASS
    型チェック: no errors (exit 0) → PASS

ステップ3: 結果報告
  状態: PASS（全3項目通過）
```

### FAIL検出時の検証

```
ステップ1: 検証対象の特定
  主張: バグ修正完了

ステップ2: 検証実行
  テスト: 11/12 passed, 1 failed (exit 1) → FAIL
  → 失敗テスト: "should handle empty input"

ステップ3: 結果報告
  状態: FAIL（テスト1件失敗）
  → odinにエスカレーション: 修正が必要
```
