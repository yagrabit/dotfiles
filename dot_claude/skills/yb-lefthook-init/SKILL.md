---
name: yb-lefthook-init
description: プロジェクトにLefthookを導入し、pre-commit/pre-pushフックを設定する
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash, Read, Write, Grep, Glob, AskUserQuestion
---

# yb-lefthook-init

プロジェクトにLefthookを導入し、pre-commit/pre-pushフックを設定するスキル。
プロジェクトのツーリングを自動検出し、適切なフック設定を生成する。

## ステップ

### ステップ1: 前提条件の確認

1. lefthookがインストールされているか確認する
   ```bash
   command -v lefthook
   ```
   - 未インストールの場合、ユーザーに `mise install lefthook` の実行を提案する
   - インストール確認後に次のステップへ進む

2. プロジェクトルートにいるか確認する
   ```bash
   git rev-parse --show-toplevel
   ```
   - Gitリポジトリでない場合はエラーを報告して終了する

### ステップ2: 既存フック設定の確認

以下の既存設定ファイル・ディレクトリを検出する:

- `lefthook.yml` / `.lefthook.yml`（Lefthookの既存設定）
- `.husky/`（Huskyのフック設定）
- `package.json` 内の `husky` / `lint-staged` 設定
- `.git/hooks/` 内のカスタムフック（sample以外のファイル）

既存設定が見つかった場合は、AskUserQuestionでユーザーに確認する:
- 選択肢:
  1. 「上書きする」 - 既存設定を置き換えてLefthookを導入する
  2. 「既存設定と並行利用する」 - 既存設定を残したままLefthookを追加する
  3. 「中止する」 - 導入を中止する

### ステップ3: ツーリング検出

プロジェクトのルートディレクトリおよび設定ファイルを調査し、以下のツーリングを自動検出する:

| 検出対象ファイル | ツール | 推奨コマンド |
|---|---|---|
| `biome.json` / `biome.jsonc` | Biome | `biome check`, `biome format --write` |
| `.eslintrc*` / `eslint.config.*` | ESLint | `eslint` |
| prettier設定（`.prettierrc*`, `prettier.config.*`） | Prettier | `prettier --check` |
| `tsconfig.json` | TypeScript | `tsc --noEmit` |
| `vitest.config.*` | Vitest | `vitest run` |
| `jest.config.*` | Jest | `jest` |
| `Cargo.toml` | Rust (cargo) | `cargo clippy`, `cargo fmt --check` |
| `pyproject.toml` / `setup.py` | Python | `ruff check`, `pytest` |

検出結果をまとめてユーザーに提示する。例:
```
検出されたツーリング:
- Biome (biome.json)
- TypeScript (tsconfig.json)
- Vitest (vitest.config.ts)
```

### ステップ4: lefthook.yml生成

検出したツーリングに基づいて `lefthook.yml` を生成する。

生成した内容をユーザーに提示し、AskUserQuestionで承認を得る:
- 選択肢:
  1. 「このまま作成する」 - 提示した内容で lefthook.yml を作成する
  2. 「カスタマイズする（指示をください）」 - ユーザーの指示に基づいて修正する
  3. 「中止する」 - 作成を中止する

### ステップ5: 適用

1. `lefthook.yml` をプロジェクトルートに作成する
2. lefthookをインストールする:
   ```bash
   lefthook install
   ```
3. 結果を報告する:
   - 作成したファイルのパス
   - 設定されたフックの一覧
   - 動作確認方法（`lefthook run pre-commit` 等）

## Examples

### TypeScriptプロジェクトの場合

Biome + TypeScript + Vitest が検出された場合の生成例:

```yaml
# lefthook.yml
# Lefthookによるgitフック設定

pre-commit:
  parallel: true
  commands:
    lint:
      glob: "*.{ts,tsx,js,jsx}"
      run: npx biome check {staged_files}
    format:
      glob: "*.{ts,tsx,js,jsx,css,json}"
      run: npx biome format --write {staged_files}
    typecheck:
      run: npx tsc --noEmit

pre-push:
  commands:
    test:
      run: npx vitest run
```

### Rustプロジェクトの場合

Cargo.toml が検出された場合の生成例:

```yaml
# lefthook.yml
# Lefthookによるgitフック設定

pre-commit:
  parallel: true
  commands:
    clippy:
      glob: "*.rs"
      run: cargo clippy -- -D warnings
    format-check:
      glob: "*.rs"
      run: cargo fmt --check

pre-push:
  commands:
    test:
      run: cargo test
```

## 注意事項

- 全てのメッセージ・コメントは日本語で記述する
- AskUserQuestionの選択肢は2〜4個に絞り、明確な説明を付ける
- lefthookのコマンド内では `{staged_files}` プレースホルダーを使用して、ステージされたファイルのみを対象にする
- `pre-commit` フックは `parallel: true` で並列実行し、高速化を図る
- `pre-push` フックにはテスト実行など、時間のかかる処理を配置する
