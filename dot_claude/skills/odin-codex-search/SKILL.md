---
name: odin-codex-search
description: Codex経由でWeb検索・技術調査を実行する。Codexプラグインが利用可能な場合はcodex:rescueでタスクを委任し、利用不可の場合はClaude CodeのWebSearchにフォールバックする。odinから自動起動される。
user-invocable: false
allowed-tools: Bash, Read, Grep, Glob, WebSearch, WebFetch, Skill
---

# odin-codex-search

Codex連携Web検索スキル。odinのthinkフェーズで技術調査やWeb検索が必要な場合に使用する。
Codexプラグインの有無を自動判定し、利用可能ならCodexに委任、不可ならClaude Codeの標準ツールにフォールバックする。

## コンテキスト検出

$ARGUMENTS を確認し、odinコンテキストJSONが含まれているか判定する。

odinコンテキストJSONの例:
```json
{
  "odin_context": {
    "task": "React Server Componentsの最新仕様を調査",
    "search_queries": ["React Server Components 2026", "RSC streaming"],
    "purpose": "設計判断の根拠となる技術情報の収集"
  }
}
```

入力の形式:
- `search_queries`: 検索クエリの配列（必須）
- `purpose`: 調査目的（任意、Codex委任時のコンテキストとして使用）
- `depth`: 調査深度 `quick` | `standard` | `deep`（デフォルト: `standard`）

## ステップ1: 環境判定

Codexプラグインの利用可能性を判定する。

判定方法: Skillツールで `codex:rescue` の存在を確認する。具体的には、利用可能なスキル一覧（system-reminderに記載）に `codex:rescue` が含まれているかを確認する。

- 利用可能 → ステップ2A（Codex経由）
- 利用不可 → ステップ2B（フォールバック）

## ステップ2A: Codex経由の検索

Skillツールで `codex:rescue` を実行する。

委任タスクの構築:
```
以下の調査を実行してください。

目的: {purpose}

検索クエリ:
{search_queriesの各項目をリスト化}

調査の要件:
- 各クエリについて、信頼性の高いソース（公式ドキュメント、RFC、著名な技術ブログ）を優先する
- 最新の情報を重視する（2025年以降の情報を優先）
- 各結果について、ソースURL・要約・信頼度を記載する
- 調査深度: {depth}
```

depth別の挙動:
- `quick`: 各クエリ1-2件のソースで十分
- `standard`: 各クエリ3-5件のソースを確認
- `deep`: 各クエリ5件以上、関連トピックも展開

Codex実行オプション:
- `--wait` を付けて完了を待つ
- `--model` は指定しない（Codex側のデフォルトを使用）

## ステップ2B: フォールバック（WebSearch）

Codexが利用不可の場合、Claude CodeのWebSearchツールを使用する。

1. search_queriesの各クエリに対してWebSearchを実行する
2. 関連性の高い結果についてWebFetchで詳細を取得する
3. depth に応じて取得する情報量を調整する:
   - `quick`: 各クエリ1回のWebSearch、WebFetchなし
   - `standard`: 各クエリ1-2回のWebSearch、上位2件をWebFetch
   - `deep`: 各クエリ2-3回のWebSearch（関連クエリも追加）、上位3件をWebFetch

## ステップ3: 結果の構造化

検索結果を以下の形式で構造化する:

```
## 調査結果

### {クエリ1}

1. {ソース名} ({URL})
   - 要約: {1-2文の要約}
   - 信頼度: 高/中/低
   - 更新日: {分かれば記載}

2. ...

### {クエリ2}
...

---

### まとめ

{目的に対する調査結果の総括。主要な知見を3-5項目で整理}

### 検索方法

{Codex経由 or WebSearchフォールバック}
```

#### 完了チェックポイント（ステップ3）

- 全てのsearch_queriesに対する結果が含まれていること
- 各結果にソースと信頼度が付いていること
- まとめセクションで目的に対する回答が提示されていること

## Examples

### Example 1: odinからの技術調査（Codex利用可能）

```
入力: {
  "odin_context": {
    "search_queries": ["Next.js 16 App Router changes", "React 20 new features"],
    "purpose": "技術スタック更新の判断材料",
    "depth": "standard"
  }
}

ステップ1: codex:rescue が利用可能 → Codex経由
ステップ2A: codex:rescue --wait で調査タスクを委任
ステップ3: 結果を構造化して返却
```

### Example 2: Codex未対応環境でのフォールバック

```
入力: {
  "odin_context": {
    "search_queries": ["chezmoi template functions"],
    "purpose": "テンプレート条件分岐の記法確認",
    "depth": "quick"
  }
}

ステップ1: codex:rescue が利用不可 → フォールバック
ステップ2B: WebSearch で検索 → 結果取得
ステップ3: 結果を構造化して返却
```
