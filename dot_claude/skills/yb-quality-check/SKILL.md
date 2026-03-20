---
name: yb-quality-check
description: プロジェクトの品質チェックを実行する。lint/型チェック/テスト/セキュリティスキャンを一括実行し、--fixで自動修正ループも可能。「品質チェックして」「lint通して」「テスト回して」などで起動。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent, AskUserQuestion
---

# Quality Check

プロジェクトの品質チェックを実行する。ツーリングを自動検出し、lint・型チェック・テスト・セキュリティスキャンを一括実行する。

$ARGUMENTSで以下のフラグを受け付ける:
- --fix: 失敗時に自動修正ループを実行する（最大3回）
- --strict: warningもfail扱いにする

## 1. ツーリング検出

git rootで以下のツーリングを検出する:

ビルド:
- package.json(build script) → npm/pnpm run build
- tsconfig.json → tsc --noEmit
- Cargo.toml → cargo build

lint:
- biome.json → biome check
- .eslintrc系 → eslint
- oxlint.json → oxlint
- ruff.toml / pyproject.toml(ruff) → ruff

型チェック:
- tsconfig.json → tsc --noEmit
- pyproject.toml(pyright) → pyright

テスト:
- vitest.config / jest.config → vitest/jest
- pyproject.toml(pytest) → pytest
- Cargo.toml → cargo test

セキュリティ:
- package.json → npm audit
- pyproject.toml → pip audit

検出結果を一覧表示する。

## 2. 検証パイプライン実行

検出したツールを順次実行する:
1. ビルド
2. lint
3. 型チェック
4. テスト
5. セキュリティスキャン

各ステップの結果をpass/fail/skipで記録する。

## 3. 修正ループ（--fix指定時のみ）

--fix が指定されている場合:
- 失敗した検証のエラー内容を分析する
- 自動修正可能なものは修正コマンドを使用する:
  - biome check --write
  - eslint --fix
  - ruff check --fix
- 自動修正できないものはサブエージェントに修正を委譲する
- 修正後、失敗した検証から再実行する
- 最大3ループまで（無限ループ防止）
- 3ループで解決しない場合はユーザーに報告して中止する

--fix が指定されていない場合:
- このステップをスキップし、結果報告に進む

## 4. 結果報告

一覧形式で結果を表示する:

（例）
ビルド:        pass (tsc --noEmit)
lint:          fail (biome) - 3 errors
型チェック:    pass (tsc --noEmit)
テスト:        pass (vitest) - 50/50
セキュリティ:  skip (未検出)

--fix使用時は修正ループの回数と修正内容も報告する:

修正ループ: 1回実行（lint失敗を修正）
最終結果: 全検証パス

--strict モードではwarningもfail扱いにする。
failが1つでもある場合は、エラー内容の詳細と修正方法を提示する。
