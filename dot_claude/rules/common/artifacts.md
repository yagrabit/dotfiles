# 成果物管理ルール

## 配置場所

- 全ての中間成果物は対象プロジェクトの `.claude/artifacts/` ディレクトリに出力する
- `.claude/artifacts/` はコミット対象外（プロジェクトの .gitignore に追加すること）
- PRマージ後は削除してよい

## ファイル名規約

- 基本形式: `{type}-{yyyyMMdd-HHmm}.md`
- 複数機能を並列で進める場合: `{type}-{feature-name}-{yyyyMMdd-HHmm}.md`
- type一覧（スキルの実際の出力名に準拠）:
  - `research`: コードベース調査レポート（think-research）
  - `requirements`: 構造化された要件定義書（think-requirements）
  - `clarified`: 要件明確化ドキュメント（talk-clarify）
  - `design`: 設計ドキュメント（think-design）
  - `adr-{NNN}`: Architecture Decision Record（think-design ステップ4）
  - `plan`: 実装計画・タスク一覧（think-plan）
  - `qa-test-items`: QA試験項目書（think-qa-design）

## 成果物の参照ルール

- スキル間の連携は原則として成果物ファイルの読み込みで行う
- ただし、odinオーケストレーター経由のSkillツール呼び出しや、同一カテゴリ内の前提スキル参照（例: ux系スキル間の連携）は許容する
- 入力の探索順序:
  1. $ARGUMENTSにファイルパスが明示指定されていればそれを使う
  2. なければ `.claude/artifacts/` 内の該当typeの最新ファイルを使う
  3. 該当ファイルが見つからない場合はAskUserQuestionでユーザーに確認する

## コヒーレンスfrontmatter

成果物間の依存関係を機械的に追跡するため、全成果物のファイル先頭にYAML frontmatterを付与する。

### フォーマット

```yaml
---
odin_coherence:
  id: "{type}-{yyyyMMdd-HHmm}"
  kind: "{type}"
  depends_on: []
  updated: "YYYY-MM-DDTHH:mm"
---
```

### フィールド定義

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `id` | ○ | 成果物の一意識別子。ファイル名（拡張子なし）と一致させる |
| `kind` | ○ | 成果物のtype。デフォルト依存チェーンの解決に使用する |
| `depends_on` | ○ | 依存する成果物のidの配列。依存がない場合は空配列 |
| `updated` | ○ | 最終更新日時（ISO 8601、分まで） |

### デフォルト依存チェーン

`depends_on` が空配列の場合、type名から以下のデフォルト依存関係を推論する:

```
research（起点）
  ├→ requirements
  └→ clarified
       └→ design（requirements または clarified に依存）
            ├→ adr-*
            ├→ qa-test-items
            └→ plan
```

| kind | デフォルト依存元 |
|------|----------------|
| `research` | なし（起点） |
| `requirements` | `research` |
| `clarified` | `research` |
| `design` | `requirements` または `clarified`（先に見つかった方） |
| `adr` | `design` |
| `qa-test-items` | `design` |
| `plan` | `design` |

明示的に `depends_on` を指定した場合はデフォルトより優先する。

### 信頼度スコア

`odin-auto-coherence` スキルがfrontmatterを読み取り、タイムスタンプ比較でスコアを算出する:

| スコア | 条件 | アクション |
|--------|------|-----------|
| Green | 全依存元の `updated` ≤ 自身の `updated` | そのまま使用可 |
| Amber | いずれかの依存元の `updated` > 自身の `updated` | ユーザーに再生成 or 続行を確認 |
| Missing | 宣言された依存ファイルが存在しない | Phase進入をブロック |

### 運用ルール

- think系スキルは成果物出力時にfrontmatterを自動付与する
- odinはPhase 5進入前に `odin-auto-coherence` でスキャンする
- Amber: ユーザーに「依存元が更新されたが続行するか」を確認する
- Missing: 該当する上流Phaseの再実行を促す

## セッション分離

- 成果物はファイルに永続化されるため、セッションをまたいでも情報を失わない
- コンパクション後も成果物ファイルのパスだけ覚えていれば復元可能
