---
name: odin-knowledge
description: 永続ナレッジ層（LLM Wiki）の管理。技術知見をプロジェクト横断で蓄積・検索・メンテナンスする。ingest（取り込み）・query（検索・回答）・lint（ヘルスチェック）の3モード。「知見を保存して」「knowledgeを検索して」「knowledgeの整理をして」で起動。odinから自動起動される場合もある。
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, WebFetch
---

# odin-knowledge

永続ナレッジ層（LLM Wiki）の管理スキル。
プロジェクト横断で技術知見を蓄積・検索・メンテナンスする。

Karpathyの「LLM Wiki」コンセプトに基づき、LLMが構造化Markdownファイル群を継続的に構築・メンテナンスする。「帳簿管理はLLMに、知識の選定は人間に」の原則に従う。

## 3つのモード

| モード | 起動キーワード | 説明 |
|-------|-------------|------|
| ingest | 「知見を保存して」「knowledgeに取り込んで」 | 成果物・テキスト・URLから汎用知見を抽出しknowledgeに統合する |
| query | 「knowledgeを検索して」「前に調べたあれ何だっけ」 | knowledgeを検索して回答し、良い回答は書き戻す |
| lint | 「knowledgeの整理をして」「知識のメンテして」 | 矛盾・孤立・陳腐化をヘルスチェックし、_index.mdを再構築する |

## ナレッジディレクトリ

配置先: `~/.claude/knowledge/`（chezmoi管理外、マシンローカル）

```
~/.claude/knowledge/
├── _index.md           # カテゴリ別インデックス（自動メンテナンス）
├── _log.md             # 時系列の取り込みログ（追記専用）
├── nextjs-app-router.md
├── react-server-components.md
└── ...
```

- フラット構造。カテゴリはfrontmatterで管理する
- メタファイルは `_` プレフィックスで区別する
- ページ数が200を超えた場合、カテゴリ別サブディレクトリへの移行を検討する

## 知識ページフォーマット

```yaml
---
knowledge:
  id: "{slug}"
  title: "{日本語タイトル}"
  category: "{カテゴリ}"
  tags: ["tag1", "tag2"]
  sources:
    - type: "artifact|url|manual"
      ref: "{成果物ID or URL or '手動投入'}"
      date: "YYYY-MM-DD"
  created: "YYYY-MM-DDTHH:mm"
  updated: "YYYY-MM-DDTHH:mm"
  confidence: "high|medium|low"
---

# {タイトル}

## 概要

{この知識の要約。2-3文}

## 詳細

{本文。見出し・コード例・図を含む構造化されたコンテンツ}

## 関連ページ

- [[related-page-slug]] - {関連の説明}

## 出典・参考

- {ソース情報}
```

### フィールド定義

| フィールド | 必須 | 説明 |
|-----------|------|------|
| id | ○ | ファイル名（拡張子なし）と一致するスラッグ。英数字とハイフン |
| title | ○ | 日本語の表示タイトル |
| category | ○ | カテゴリ体系から1つ選択 |
| tags | ○ | 検索用タグ。空配列可 |
| sources | ○ | 知識の出典。複数可 |
| created | ○ | 初回作成日時 |
| updated | ○ | 最終更新日時 |
| confidence | ○ | high=検証済み、medium=妥当だが未検証、low=推測・暫定 |

### カテゴリ体系

| カテゴリ | 対象領域 |
|---------|---------|
| frontend | React, Next.js, CSS, ブラウザAPI, パフォーマンス |
| backend | Node.js, API設計, データベース, サーバー |
| architecture | 設計パターン, アーキテクチャ原則, 設計判断 |
| devops | CI/CD, Docker, クラウド, インフラ |
| tools | Git, エディタ, CLI, 開発環境, chezmoi |
| testing | テスト戦略, フレームワーク, パターン |
| security | 認証, 脆弱性, セキュリティ対策 |
| design | UI/UXパターン, デザインシステム, アクセシビリティ |

新カテゴリが必要な場合はingest時にAskUserQuestionで提案する。

## コンテキスト検出

$ARGUMENTSを確認し、モードを判定する:

1. odinコンテキストJSONがある場合: `task` フィールドからモードを推定する
2. 明示的なモード指定がある場合（例: `ingest .claude/artifacts/research-*.md`）: そのまま使用
3. 判定できない場合: AskUserQuestionで確認する

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

---

## Ingestモード

成果物・テキスト・URLから汎用技術知見を抽出し、knowledgeに統合する。

### ステップ1: 入力の特定

入力ソースを特定する:

1. $ARGUMENTSにファイルパスが指定されている → そのファイルを読み込む
2. $ARGUMENTSにURLが指定されている → WebFetchで取得する
3. $ARGUMENTSに自由テキストがある → そのテキストを入力とする
4. odinコンテキストのartifactsにパスがある → そのファイルを読み込む
5. いずれもない → AskUserQuestionで入力ソースを確認する

#### 完了チェックポイント（ステップ1）
- 入力ソースが特定され、内容が読み込めていること

### ステップ2: 知見の抽出と選定

入力から汎用技術知見を抽出する。

抽出パターン（これらに該当する知識を探す）:
- フレームワーク・ライブラリのAPI使用法やパターン
- エラー対処パターン（エラーメッセージ → 原因 → 解決策）
- 設計パターンの適用例と判断基準
- パフォーマンス最適化手法
- セキュリティ対策のベストプラクティス

除外パターン（これらはknowledgeに含めない）:
- `src/` `app/` 等のプロジェクト固有ファイルパス
- 特定のビジネスドメイン用語（商品名、社内システム名等）
- プロジェクト固有の環境変数名・設定値
- 特定のデータベーススキーマ・テーブル名
- APIキー・シークレット等の機密情報

抽出した知見の候補をリスト化し、AskUserQuestionでユーザーに確認する:

```
以下の知見をknowledgeに取り込みますか？

1. {知見タイトル1} - {概要}（カテゴリ: {category}）
2. {知見タイトル2} - {概要}（カテゴリ: {category}）
3. 全て取り込む
4. 取り込まない
```

ユーザーが選択した知見のみ次のステップに進める。

#### 完了チェックポイント（ステップ2）
- 抽出候補がリスト化されていること
- ユーザーが取り込む知見を承認していること

### ステップ3: 重複検出

ナレッジディレクトリの初期化確認:
```bash
mkdir -p ~/.claude/knowledge
```

取り込む各知見について、既存ページとの重複を2段階で検出する:

一次フィルタ（機械的）:
1. `~/.claude/knowledge/_index.md` を読み込む（存在しない場合はスキップ）
2. 同一カテゴリの既存ページ一覧を取得する
3. 各候補ページのfrontmatterを読み、タグが2つ以上一致するページを重複候補として抽出する

二次判断（LLM）:
- 重複候補がある場合: 既存ページの内容を読み、統合すべきか新規作成すべきかを判断する
- 統合の場合: 既存ページに新情報をenrichする（ステップ4a）
- 新規の場合: 新規ページを作成する（ステップ4b）
- 重複候補がない場合: 新規ページを作成する（ステップ4b）

#### 完了チェックポイント（ステップ3）
- 各知見について統合/新規の判断が完了していること

### ステップ4a: 既存ページの更新（統合の場合）

1. 既存ページをReadで読み込む
2. 新情報を「詳細」セクションに統合する
   - 既存情報と矛盾する場合: 新しい情報を優先し、旧情報は「以前は〜と考えられていたが」の形で残す
3. frontmatterを更新する:
   - `updated` を現在時刻に更新
   - `sources` に新しいソースを追加
   - `tags` に新しいタグを追加（重複除去）
   - `confidence` を更新（複数ソースで裏付けられたらhighに昇格）
4. `[[cross-link]]` を必要に応じて追加する
5. Editツールで保存する

### ステップ4b: 新規ページの作成

1. スラッグ（id）を決定する: 英数字とハイフン、内容を端的に表す英語
2. 知識ページフォーマットに従い、frontmatter + 本文を構成する
3. `~/.claude/knowledge/{slug}.md` にWriteツールで保存する
4. 既存の関連ページがあれば、双方に `[[cross-link]]` を追加する

### ステップ5: インデックスとログの更新

_index.md の更新:
1. `~/.claude/knowledge/_index.md` を読み込む（存在しない場合は新規作成）
2. 該当カテゴリセクションに新規/更新ページのエントリを追加する
3. 「最近の更新」セクションの先頭にエントリを追加する（10件を超えたら古いものを削除）
4. 総ページ数を更新する
5. 更新日時を現在時刻にする

_index.md の新規作成テンプレート:
```markdown
# Knowledge Index

更新日時: {YYYY-MM-DD HH:mm}
総ページ数: 0

## カテゴリ別

## 最近の更新（直近10件）

## 低確信度ページ（要検証）
```

_log.md の更新:
1. `~/.claude/knowledge/_log.md` を読み込む（存在しない場合は新規作成）
2. 本日の日付セクションがなければ追加する
3. エントリを追記する:
   ```
   - {HH:mm} [ingest|update] {slug}.md - {ソース情報}
   ```

#### 完了チェックポイント（ステップ5）
- _index.md が更新されていること
- _log.md にエントリが追記されていること

### ステップ6: 報告

取り込み結果をユーザーに報告する:

```
knowledgeに取り込みました:

- {新規|更新}: {ページタイトル} ({slug}.md) - {カテゴリ}
- ...

現在のknowledge: {総ページ数}ページ
```

---

## Queryモード

knowledgeを検索して回答し、良い回答は書き戻す。

### ステップ1: 質問の理解

$ARGUMENTSまたはAskUserQuestionで質問を取得する。

質問からキーワードと想定カテゴリを抽出する。

#### 完了チェックポイント（ステップ1）
- 質問内容が明確であること

### ステップ2: 知識の検索（2段階絞り込み）

1. `~/.claude/knowledge/_index.md` を読み込む
   - 存在しない場合: 「knowledgeがまだ初期化されていません。ingestモードで知見を取り込んでください」と報告して終了
2. 質問に関連するカテゴリを特定する
3. 該当カテゴリに属するファイル名一覧を_index.mdから取得する
4. 取得したファイル群に限定してGrepでキーワード検索する:
   ```
   Grep(pattern: "キーワード", path: "~/.claude/knowledge/", glob: "{file1}.md,{file2}.md,...")
   ```
5. ヒットしたページをReadで読み込む（上位5ページまで）
6. 読み込んだページの `[[cross-link]]` を1段階辿り、関連ページも読み込む

#### 完了チェックポイント（ステップ2）
- 関連ページが0件以上見つかっていること（0件の場合はステップ3でその旨を報告）

### ステップ3: 回答の合成と提示

関連ページが見つかった場合:
- 収集したページ群から回答を合成する
- 回答にはソースページへの参照を含める（例: 「(→ nextjs-app-router.md)」）

関連ページが見つからなかった場合:
- 「knowledgeに該当する知見がありません」と報告する
- yb-memoryでの検索を提案する: 「yb-memory search "{キーワード}" で過去の会話を検索できます」

### ステップ4: 書き戻し判定

回答を合成した場合、書き戻しの判定を行う:

- 合成した回答が既存ページにない新しい整理・視点を含む場合:
  AskUserQuestionで確認する:
  ```
  この回答をknowledgeに保存しますか？

  1. 新規ページとして保存する
  2. 既存ページ {title} に追記する
  3. 保存しない
  ```
- 保存する場合: Ingestモードのステップ4a/4b/5と同じ手順で保存する
- 保存しない場合: そのまま終了

---

## Lintモード

知識ベースのヘルスチェックと_index.mdの完全再構築を行う。

### ステップ1: 全ページの収集

1. `~/.claude/knowledge/` 内の全Markdownファイルを列挙する（`_` プレフィックスのメタファイルを除く）
   ```
   Glob(pattern: "[!_]*.md", path: "~/.claude/knowledge/")
   ```
2. 各ページのfrontmatterを読み込む
3. ページが0件の場合: 「knowledgeにページがありません」と報告して終了

#### 完了チェックポイント（ステップ1）
- 全ページのfrontmatterが読み込めていること

### ステップ2: ヘルスチェック実行

以下のチェックを実行する:

| チェック | 条件 | 重大度 |
|---------|------|-------|
| 陳腐化 | updated が90日以上前 | warn |
| 孤立 | 他ページからのリンクが0かつ自身のリンクも0 | info |
| 低確信度放置 | confidence: low が30日以上未更新 | warn |
| カテゴリ偏り | 1カテゴリに全体の50%以上集中 | info |
| 重複候補 | 同一カテゴリ内でタグが2つ以上一致するページペア | warn |
| リンク切れ | [[slug]] の参照先ページが存在しない | error |
| frontmatter不正 | 必須フィールドの欠損やフォーマット不正 | error |

各チェックの実行方法:

陳腐化チェック:
- 各ページの `updated` を現在日時と比較する
- 90日以上経過しているページをリストアップする

孤立チェック:
- 全ページの `[[slug]]` リンクを収集する
- リンク元もリンク先もないページを検出する

重複候補チェック:
- 同一カテゴリ内のページペアについてタグの一致数を計算する
- 2つ以上一致するペアを候補としてリストアップする

リンク切れチェック:
- 全ページの `[[slug]]` リンクを収集する
- 参照先ファイルが存在しないリンクを検出する

### ステップ3: _index.md の完全再構築

全ページのfrontmatterから_index.mdを完全に再生成する:

1. カテゴリ別にページを分類する
2. 各カテゴリセクションにページ一覧を記載する（タイトル + 概要の1行目）
3. updatedの降順で「最近の更新」セクションを生成する（上位10件）
4. confidence: lowのページを「低確信度ページ」セクションに記載する
5. 総ページ数と更新日時を記載する

### ステップ4: レポート出力

```
## Knowledge Lintレポート

総ページ数: {N}
カテゴリ分布: {category}: {N}ページ, ...

### error ({N}件)
- {ファイル名}: {問題の説明}

### warn ({N}件)
- {ファイル名}: {問題の説明} → 提案: {修正提案}

### info ({N}件)
- {ファイル名}: {問題の説明}

_index.md を再構築しました。
```

---

## odinからの自動起動

### Ingestの自動起動

odinのPhase 5実行ループ（execution-loop.md 5-X.5）で、think系スキル（research, design, investigate, analyze）完了後に自動起動される。

odinコンテキスト例:
```json
{
  "odin_context": {
    "task": "research成果物からknowledgeにingest",
    "mode": "ingest",
    "source": ".claude/artifacts/research-20260405-1400.md"
  }
}
```

### Lintの自動起動

gardening.mdの月次チェックの一環として起動される。

### Queryの自動起動

odinのPhase 1（初期入力分析）でthink系スキル実行前に、関連する既存知識がないか確認する際に起動されることがある。

## 他のodinスキルとの関係

| スキル | 関係 |
|-------|------|
| odin-auto-record | 独立。insightsは運用メモ（短命）、knowledgeは技術知見（永続） |
| odin-design-knowledge | 共存。デザイン分析はサイト単位の具体的分析、knowledgeは汎用技術知見 |
| odin-learn | 独立。learnは個人習熟度管理、knowledgeは技術知見蓄積。連携: knowledgeからフラッシュカード生成可 |
| yb-memory | 補完関係。yb-memory=会話ログ検索、knowledge=構造化知識。knowledgeにない場合yb-memoryにフォールバック可 |

## Examples

### Example 1: think-research成果物からのIngest

```
入力: odin-knowledge ingest .claude/artifacts/research-20260405-1400.md

ステップ1: research成果物を読み込み
ステップ2: 抽出候補
  1. "Next.js App Routerのキャッシュ戦略" - RSCとData Cacheの使い分け（frontend）
  2. "PrismaのN+1問題対策" - includeとselectの最適化パターン（backend）
  → ユーザーが「全て取り込む」を選択
ステップ3: 重複検出
  - "nextjs-app-router.md" が既存 → タグ3つ一致 → 統合判断
  - "prisma-n-plus-1.md" は存在しない → 新規作成
ステップ4a: nextjs-app-router.md を更新（キャッシュ戦略の情報を追加）
ステップ4b: prisma-n-plus-1.md を新規作成
ステップ5: _index.md と _log.md を更新
ステップ6: 報告
```

### Example 2: Query

```
入力: odin-knowledge query "React Server Componentsでのデータフェッチのベストプラクティスは？"

ステップ1: キーワード="React Server Components, データフェッチ", カテゴリ=frontend
ステップ2: _index.mdからfrontendの12ページを特定 → Grepで3ページヒット
  - react-server-components.md
  - nextjs-app-router.md
  - nextjs-data-fetching.md（cross-link経由）
ステップ3: 3ページから回答を合成して提示
ステップ4: 「この回答をknowledgeに保存しますか？」→ 「保存しない」
```

### Example 3: Lint

```
入力: odin-knowledge lint

ステップ1: 25ページのfrontmatterを収集
ステップ2: チェック結果
  error: 1件（リンク切れ: deprecated-api.md の [[old-page]] が存在しない）
  warn: 3件（陳腐化2件、低確信度放置1件）
  info: 2件（孤立1件、カテゴリ偏り: frontendが60%）
ステップ3: _index.md を完全再構築
ステップ4: レポート出力
```
