---
name: yb-verification-loop
description: 変更後の品質検証を自動ループ実行する。ビルド→テスト→lint→型チェック→セキュリティスキャンを実施し、失敗があれば修正して再検証する
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent
---

変更後の品質検証を自動ループで実行する。検出したツーリングに応じてビルド・テスト・lint・型チェック・セキュリティスキャンを順次実行し、失敗があれば修正して再検証する。

## 1. プロジェクト検出

git rootディレクトリで以下のファイルを検索し、プロジェクト種別とツーリングを特定する:

- package.json → Node.jsプロジェクト
- tsconfig.json → TypeScriptプロジェクト
- pyproject.toml / setup.py → Pythonプロジェクト
- Cargo.toml → Rustプロジェクト
- go.mod → Goプロジェクト

各ツーリングの有無を自動検出し、利用可能なチェックを一覧表示する。

## 2. 検証パイプライン実行

検出したツーリングに応じて以下を順次実行する:

1. ビルド（build script、tsc --noEmit、cargo build等）
2. テスト（vitest, jest, pytest, cargo test等）
3. lint（biome check, eslint, oxlint, ruff等）
4. 型チェック（tsc --noEmit, pyright等）
5. セキュリティスキャン（npm audit, pip audit等）

各ステップの結果をpass/failで記録する。

## 3. 失敗時の修正ループ

- 失敗した検証のエラー内容を分析する
- 修正をサブエージェントに委譲する
- 修正後、失敗した検証から再実行する
- 最大3ループまで（無限ループ防止）
- 3ループで解決しない場合はユーザーに報告して中止する

## 4. 結果報告

全検証の結果を一覧形式で報告する:

```
ステップ        結果    概要
ビルド          pass    tsc --noEmit 成功
テスト          fail    vitest 3/50 failed（ループ1で修正済み）
lint            pass    biome check 成功
型チェック      pass    tsc --noEmit 成功
セキュリティ    pass    npm audit 問題なし

修正ループ: 1回実行（テスト失敗を修正）
最終結果: 全検証パス
```
