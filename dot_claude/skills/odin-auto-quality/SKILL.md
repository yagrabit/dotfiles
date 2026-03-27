---
name: odin-auto-quality
description: 品質チェック自動実行。lint/型チェック/テスト/セキュリティスキャンを一括実行し、問題があれば修正提案する。odin司令塔からdo系スキル完了後に自動呼び出し、または単体で「品質チェックして」で起動。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent
---

# odin-auto-quality

プロジェクトの品質チェックを一括実行する自動補助スキル。
odin司令塔からdo系スキル完了後に呼び出される他、単体でも使用可能。

$ARGUMENTSで以下のフラグを受け付ける:
- --fix: 失敗時に自動修正ループを実行する（最大3回）
- --strict: warningもfail扱いにする

## 1. ツーリング自動検出

git rootで以下のツーリングを検出する:

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

## 2. 検証パイプライン実行

検出したツールを以下の順序で実行する:
1. ビルド
2. lint
3. 型チェック
4. テスト
5. セキュリティスキャン

各ステップの結果をpass/fail/skipで記録する。
--strict指定時はwarningもfail扱いにする。

## 3. 修正ループ（--fix指定時のみ）

--fix が指定されている場合:
1. 失敗した検証のエラー内容を分析する
2. 自動修正可能なものは修正コマンドを使用する:
   - biome check --write
   - eslint --fix
   - ruff check --fix
   - oxlint --fix
3. 自動修正できないものはAgentツールでサブエージェントに修正を委譲する
4. 修正後、失敗した検証から再実行する
5. 最大3ループまで
6. 3ループで解決しない場合はユーザーに報告して中止する

--fix が指定されていない場合はこのステップをスキップする。

## 4. 結果報告

一覧形式で結果を表示する:

```
ビルド:        pass (tsc --noEmit)
lint:          fail (biome) - 3 errors
型チェック:    pass (tsc --noEmit)
テスト:        pass (vitest) - 50/50
セキュリティ:  skip (未検出)
```

--fix使用時は修正内容と修正ループ回数も報告する。
failが1つでもある場合はエラー詳細と修正方法を提示する。
