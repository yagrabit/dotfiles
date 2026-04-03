---
name: odin-auto-quality
description: lint・型チェック・テスト・セキュリティスキャンを一括実行し、pass/fail/skipで結果を報告する。--fixで自動修正ループも実行可能。do系スキル完了後にPostToolUseフックが自動リマインドするほか、「品質チェックして」「lint通して」で単体起動。
user-invocable: false
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent
---

# odin-auto-quality

プロジェクトの品質チェックを一括実行する自動補助スキル。
odin司令塔からdo系スキル完了後に呼び出される他、単体でも使用可能。

$ARGUMENTSで以下のフラグを受け付ける:
- --fix: 失敗時に自動修正ループを実行する（最大3回）
- --strict: warningもfail扱いにする

## コンテキスト検出

### odinコンテキストがある場合（$ARGUMENTSにodin_contextが含まれる場合）
- odinから自動呼び出しされている
- odinコンテキストの情報（対象ディレクトリ等）を活用して実行する
- 結果をodinに返却し、failがある場合はodinにエスカレーションする

### odinコンテキストがない場合（ユーザー直接呼び出し）
- ステップ1からツーリング自動検出を開始する

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

### ステップ1: ツーリング自動検出

git rootで以下のツーリングを検出する:

コード生成:
- src/lib/graphql/queries/ + codegen.ts の存在確認 → pnpm codegen
- prisma/schema.prisma の存在確認 → pnpm prisma generate
- 上記いずれにも該当しない場合はskip

ビルド:
- package.json(build script) → pnpm run build / npm run build
- tsconfig.json → tsc --noEmit
- Cargo.toml → cargo build

lint:
- biome.json / biome.jsonc → biome check .
- oxlint.json → oxlint
- .eslintrc系 / eslint.config.* → eslint .
- ruff.toml / pyproject.toml(ruff) → ruff check .

型チェック:
- tsconfig.json → tsc --noEmit
- pyproject.toml(pyright) → pyright

テスト:
- vitest.config.* / vite.config.*(test) → pnpm vitest run
- jest.config.* → pnpm jest
- pyproject.toml(pytest) → pytest
- Cargo.toml → cargo test

セキュリティ:
- package-lock.json → npm audit
- pnpm-lock.yaml → pnpm audit
- pyproject.toml → pip-audit

検出結果を一覧表示する。検出できなかった項目はskipとする。

#### 完了チェックポイント（ステップ1）

- 6カテゴリ（コード生成/ビルド/lint/型チェック/テスト/セキュリティ）の検出が完了していること
- 各カテゴリの検出結果（ツール名またはskip）が一覧表示されていること

### ステップ2: 検証パイプライン実行

検出したツールを以下の順序で実行する:
1. コード生成（codegen等。型チェック・テストの前提条件）
2. ビルド
3. lint
4. 型チェック
5. テスト
6. セキュリティスキャン

各ステップの結果をpass/fail/skipで記録する。
--strict指定時はwarningもfail扱いにする。

#### 完了チェックポイント（ステップ2）

- 検出された全ツールが実行されていること
- 各ツールの結果がpass/fail/skipで記録されていること

### ステップ3: 修正ループ（--fix指定時のみ）

--fix が指定されている場合:
1. 失敗した検証のエラー内容を分析する
2. 自動修正可能なものは修正コマンドを使用する:
   - biome check --write
   - eslint --fix
   - ruff check --fix
   - oxlint --fix
3. 自動修正できないものはAgentツールでサブエージェントに修正を委譲する
4. 修正後、失敗した検証から再実行する
5. 最大3ループまで（イテレーション上限: 3回）
6. 3ループで解決しない場合のフォールバック:
   - 残存エラーの一覧（ファイルパス・行番号・エラーメッセージ）をユーザーに報告する
   - 自動修正を断念し、手動対応を依頼する
   - 報告形式: 「3回の修正ループで以下のエラーが解消できませんでした。手動での対応をお願いします。」+ エラー一覧

--fix が指定されていない場合はこのステップをスキップする。

#### 完了チェックポイント（ステップ3）

- 修正ループが3回以内で完了していること、または3回で解決しない場合はユーザーに報告済みであること
- 修正後の再実行で結果が改善されていること

### ステップ4: 結果報告

一覧形式で結果を表示する:

```
コード生成:    pass (pnpm codegen)
ビルド:        pass (tsc --noEmit)
lint:          fail (biome) - 3 errors
型チェック:    pass (tsc --noEmit)
テスト:        pass (vitest) - 50/50
セキュリティ:  skip (未検出)
```

--fix使用時は修正内容と修正ループ回数も報告する。
failが1つでもある場合はエラー詳細と修正方法を提示する。

#### 完了チェックポイント（ステップ4）

- 全カテゴリの結果がpass/fail/skipで一覧表示されていること
- --fix使用時は修正内容と修正ループ回数が報告されていること
- failがある場合はエラー詳細が提示されていること

## Examples

### 品質チェック実行（修正なし）

ユーザー: 「品質チェックして」

```
ステップ1: ツーリング自動検出
  ビルド: pnpm build（検出済み）
  lint: pnpm oxlint（検出済み）
  型チェック: pnpm tsc --noEmit（検出済み）
  テスト: pnpm vitest run（検出済み）
  セキュリティ: pnpm audit（検出済み）

ステップ2: 検証パイプライン実行
  ビルド: pass
  lint: pass（2 warnings）
  型チェック: pass
  テスト: pass（24/24 passed）
  セキュリティ: pass（0 vulnerabilities）

ステップ3: スキップ（--fix未指定）

ステップ4: 結果報告
  全5カテゴリ pass
```

### 品質チェック+自動修正

ユーザー: 「品質チェックして --fix」

```
ステップ1-2: 同上（lint: fail 3 errors）

ステップ3: 修正ループ
  ループ1: oxlint --fix → 2/3 修正成功
  ループ2: Agentで残り1件修正 → 全解消
  再検証: lint pass

ステップ4: 結果報告（lint修正済み、全カテゴリ pass）
```
