---
name: odin-auto-coherence
description: 成果物間の整合性を自動追跡する。frontmatterの依存宣言をもとに依存グラフを構築し、信頼度スコア（Green/Amber/Missing）を算出する。Phase進入前のゲートチェック、影響分析、整合性スキャンを提供する。「整合性チェックして」「コヒーレンスを確認して」で起動。odinから自動起動される場合もある。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# odin-auto-coherence

成果物間の整合性追跡スキル。VCSDDのCEG（Conditioned Evidence Graph）にインスパイアされた仕組み。

成果物のfrontmatterに宣言された `odin_coherence` メタデータを読み取り、依存グラフの構築・信頼度スコアの算出・影響分析を行う。

## サブコマンド

$ARGUMENTS または直接の指示から、以下のサブコマンドを判定する:

| サブコマンド | 説明 | 使用場面 |
|-------------|------|---------|
| `scan` | 全成果物をスキャンし、依存グラフと信頼度スコアを一覧表示 | 定期チェック、状況把握 |
| `validate` | 構造的問題（循環依存・欠損依存）を検出しゲート判定を返す | Phase進入前のゲートチェック |
| `impact` | 指定した成果物の変更が影響する下流ノードを特定 | 要件変更時の影響分析 |

デフォルト（サブコマンド未指定）: `scan` を実行する。

## Instructions

### 共通: 成果物の収集

1. artifacts_dirを決定する:
   - odinコンテキストの `artifacts_dir` があればそれを使う
   - なければ `.claude/artifacts/` を使う

2. 対象ディレクトリ内の全 `.md` ファイルを列挙する（Globツール使用）

3. 各ファイルの先頭からYAML frontmatter（`---` で囲まれた部分）を読み取る:
   - `odin_coherence` ブロックがあれば `id`, `depends_on`, `updated` を抽出する
   - frontmatterがないファイルはレガシー成果物として扱う（後述）

### レガシー成果物の扱い

frontmatterがない既存の成果物は、以下のルールで推論する:

- `id`: ファイル名から拡張子を除いたもの（例: `research-20260320-1430.md` → `research-20260320-1430`）
- `kind`: idのプレフィックスから推論する（例: `research-20260320-1430` → `research`）
- `depends_on`: `kind` とデフォルト依存チェーンから推論する（下表参照）
- `updated`: ファイルの最終更新日時（`stat -f %Sm -t "%Y-%m-%dT%H:%M"` で取得）

デフォルト依存チェーン（`kind` で解決）:

| kind | デフォルト依存元 |
|------|----------------|
| `research` | なし（起点） |
| `requirements` | 同一artifacts_dir内の最新 `research-*` |
| `clarified` | 同一artifacts_dir内の最新 `research-*` |
| `design` | 同一artifacts_dir内の最新 `requirements-*` または `clarified-*` |
| `adr` | 同一artifacts_dir内の最新 `design-*` |
| `qa-test-items` | 同一artifacts_dir内の最新 `design-*` |
| `plan` | 同一artifacts_dir内の最新 `design-*` |

### scan サブコマンド

1. 全成果物を収集し、依存グラフを構築する
2. 各ノードの信頼度スコアを算出する:

   | スコア | 条件 |
   |--------|------|
   | Green | 全依存元の `updated` ≤ 自身の `updated` |
   | Amber | いずれかの依存元の `updated` > 自身の `updated` |
   | Missing | `depends_on` に記載されたidのファイルが存在しない |

3. 結果を以下の形式で出力する:

```
## コヒーレンススキャン結果

スキャン日時: {yyyy-MM-dd HH:mm}
対象ディレクトリ: {artifacts_dir}
成果物数: {N}

### 依存グラフ

{テキストベースのツリー図}

例:
research-20260320-1430 [Green]
  └→ requirements-20260320-1500 [Green]
       └→ design-20260320-1600 [Amber]
            ├→ plan-20260320-1700 [Amber]
            └→ test-plan-20260320-1700 [Green]

### 信頼度スコア一覧

| 成果物 | スコア | 依存元 | 備考 |
|--------|--------|--------|------|
| {id} | {Green/Amber/Missing} | {depends_on} | {スコアの理由} |

### サマリー

- Green: {N}件
- Amber: {N}件（内容確認または再生成を推奨）
- Missing: {N}件（上流成果物の生成が必要）
```

### validate サブコマンド

1. 全成果物を収集し、依存グラフを構築する
2. 以下の構造的問題を検出する:

   | 問題 | 検出方法 | 重大度 |
   |------|---------|--------|
   | 循環依存 | グラフ内の閉路検出（DFS） | エラー |
   | 欠損依存 | `depends_on` に記載されたidのファイルが存在しない | エラー |
   | 孤立ノード | 他のノードから参照されず、何にも依存していない | 警告 |
   | frontmatter未設定 | `odin_coherence` ブロックがない | 情報 |
   | Amber状態 | 依存元が自身より後に更新されている | 警告 |

3. ゲート判定を行う（3段階）:
   - PASS: エラーが0件かつAmber状態が0件
   - WARN: エラーが0件だがAmber状態が1件以上（ユーザー確認が必要）
   - FAIL: エラーが1件以上（Phase進入をブロック）

4. 結果を以下の形式で出力する:

```
## コヒーレンス検証結果

検証日時: {yyyy-MM-dd HH:mm}
ステータス: {PASS / WARN / FAIL}

### 検出された問題

| # | 重大度 | 問題 | 対象 | 推奨アクション |
|---|--------|------|------|--------------|
| 1 | {エラー/警告/情報} | {問題の説明} | {対象ノード} | {修正方法} |

### ゲート判定

{PASS: Phase進入を許可する / WARN: Amber状態の成果物が{N}件あり、ユーザー確認が必要 / FAIL: エラーが{N}件あるためPhase進入をブロックする}
```

### impact サブコマンド

1. $ARGUMENTS から変更対象の成果物id（またはファイル名）を取得する
   - 指定がない場合は AskUserQuestion で確認する
2. 依存グラフを構築し、指定ノードからBFS（幅優先探索）で下流ノードを探索する
3. 影響を受けるノードとその信頼度変化を報告する:

```
## 影響分析結果

変更元: {id}
影響ノード数: {N}

### 影響伝播ツリー

{変更元} (変更済み)
  └→ {直接依存ノード1} (Green → Amber)
       └→ {間接依存ノード1a} (Green → Amber)
  └→ {直接依存ノード2} (Green → Amber)

### 推奨アクション

| 優先度 | 成果物 | アクション |
|--------|--------|-----------|
| 1 | {id} | 再生成が必要（直接依存） |
| 2 | {id} | 内容確認を推奨（間接依存） |
```

## odinとの連携

odinのPhase 5進入前に `validate` を自動実行する。結果に基づくアクション:

| 結果 | odinのアクション |
|------|----------------|
| PASS | Phase 5に進む |
| WARN | AskUserQuestionで「Amber状態の成果物を再生成 or 続行」を確認する |
| FAIL（Missing） | 欠損している上流成果物のPhaseを再実行する |
| FAIL（循環依存） | 依存関係の修正を促す |

## Examples

```
例1: Phase進入前のゲートチェック
  → odin-auto-coherence validate
  → 結果: PASS（全成果物Green、構造的問題なし）
  → Phase 5進入を許可

例2: 要件変更後の影響分析
  → odin-auto-coherence impact requirements-20260320-1500
  → 結果: design-20260320-1600, plan-20260320-1700 が影響を受ける
  → 設計と実装計画の再生成を推奨

例3: 定期スキャン
  → odin-auto-coherence scan
  → 結果: 5件Green, 1件Amber（design → その後requirementsが更新された）
  → designの再生成を推奨
```
