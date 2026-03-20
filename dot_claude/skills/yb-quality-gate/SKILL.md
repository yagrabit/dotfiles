---
name: yb-quality-gate
description: コミットやPR前の品質チェック統合。プロジェクトのツーリングを自動検出し、lint/型チェック/テスト/セキュリティスキャンを一括実行する
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, AskUserQuestion
---

コミットやPR前の品質チェックを統合実行する。プロジェクトのツーリングを自動検出し、lint・型チェック・テスト・セキュリティスキャンを一括で実行する。

$ARGUMENTSで以下のフラグを受け付ける:

- --fix: 自動修正可能な問題を修正する
- --strict: warningもfail扱いにする

## 1. ツーリング検出

git rootで以下のツーリングを検出する:

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

## 2. 実行

検出したツールを順次実行する。

--fix 指定時は自動修正コマンドを使用する:
- biome check --write
- eslint --fix
- ruff check --fix

各ツールの結果をpass/fail/skipで記録する。

## 3. 結果報告

一覧形式で結果を表示する:

```
lint:        pass (biome)
型チェック:  fail (tsc) - 3 errors
テスト:      pass (vitest)
セキュリティ: skip (npm audit 未検出)
```

--strict モードではwarningもfail扱いにする。

failが1つでもある場合は、エラー内容の詳細と修正方法を提示する。
