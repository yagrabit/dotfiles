---
name: odin-design-generate
description: "デザイン分析結果からデザインシステム（HTMLビジュアルガイド + tokens.json + DESIGN.md）を生成し、対話的に改善する"
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_resize
---

# odin-design-generate

odin-design-dissect の分析結果（dissect-*.md / audit-*.md）から、人間とAI両方が使えるデザインシステムを生成するスキル。
DESIGN.md（Google Stitch標準の9セクション形式）を中心に、tokens.json + HTMLショーケースを出力する。
生成後は対話的に改善し、確定したDSをベースに開発に入る「デザインPlanモード」を提供する。

## 言語

- ユーザーとのやりとりは日本語で行う
- 生成物のコメントも日本語

## 入力

以下の優先順で入力ファイルを探す:
1. ユーザーが明示指定したファイルパス
2. `.claude/artifacts/` 内の最新の `audit-*.md` または `dissect-*.md`
3. 見つからない場合はAskUserQuestionで確認

## 出力先

プロジェクトルート（またはユーザー指定）に以下を生成:

```
design-system/
├── DESIGN.md            ← AI向けデザインシステム定義（9セクション形式）
├── tokens.json          ← SSOT: 全デザイントークン
└── showcase/
    └── index.html       ← ビジュアルガイド（人間向け）
```

AskUserQuestionで出力先を確認する:
- 「design-system/ ディレクトリに生成します。場所を変更しますか？」

---

## Phase 1: トークン構造化

入力ファイルから抽出済みのトークンデータを読み取り、tokens.json を生成する。

### tokens.json の構造

```json
{
  "meta": {
    "name": "Project Name",
    "version": "1.0.0",
    "generated": "yyyy-MM-dd",
    "source": "audit-*.md / dissect-*.md",
    "defaultTheme": "dark"
  },
  "color": {
    "primitive": {
      "blue-500": "#3182CE",
      "slate-900": "#1A202C",
      "white": "#FFFFFF"
    },
    "semantic": {
      "light": {
        "primary": "{color.primitive.blue-500}",
        "bg-primary": "{color.primitive.white}",
        "text-primary": "{color.primitive.slate-900}"
      },
      "dark": {
        "primary": "{color.primitive.blue-500}",
        "bg-primary": "{color.primitive.slate-900}",
        "text-primary": "{color.primitive.slate-200}"
      }
    }
  },
  "typography": {
    "font-family": {
      "heading": "Inter",
      "body": "Inter",
      "code": "SFMono-Regular"
    },
    "font-size": {
      "xs": "12px", "sm": "14px", "base": "16px", "lg": "18px",
      "xl": "20px", "2xl": "24px", "3xl": "36px", "4xl": "44px", "5xl": "68px"
    },
    "font-weight": { "normal": "400", "semibold": "600", "bold": "700" },
    "line-height": { "tight": "1.15", "snug": "1.25", "normal": "1.5", "relaxed": "1.6" },
    "scale": { "name": "Perfect Fourth", "ratio": 1.333 }
  },
  "spacing": {
    "base": "8px",
    "scale": { "xs": "4px", "sm": "8px", "md": "16px", "lg": "24px", "xl": "32px", "2xl": "48px", "3xl": "64px", "4xl": "96px" }
  },
  "border-radius": { "sm": "4px", "md": "8px", "lg": "12px", "full": "9999px" },
  "shadow": {
    "sm": "rgba(0,0,0,0.05) 0px 4px 6px -1px",
    "md": "rgba(0,0,0,0.1) 0px 8px 16px -4px",
    "lg": "rgba(0,0,0,0.15) 0px 16px 32px -8px"
  }
}
```

#### テーマ構造

- `meta.defaultTheme`: ショーケースの初期表示テーマ。dissectの抽出時に検出したアクティブテーマを記録する
- `color.semantic`: light/dark の2キーに分岐。各キーの中身はフラットなトークン名→参照値の構造
- テーマ分岐ルール: テーマで値が変わるのは `color.semantic` のみ。他のカテゴリ（shadow / typography / spacing等）はテーマ非依存
- 後方互換: `color.semantic` 直下のキーが `light` / `dark` ならテーマ分岐構造、`primary` 等のトークン名なら旧形式と判別可能

テーマ未検出時（learnモードでテーマ切替がないサイト）:
```json
{
  "meta": { "defaultTheme": "dark" },
  "color": {
    "primitive": { "...": "..." },
    "semantic": {
      "primary": "{color.primitive.blue-500}",
      "bg-primary": "{color.primitive.slate-900}"
    }
  }
}
```
テーマ分岐なしのフラット構造で生成する。ショーケースのテーマ切替トグルは非表示にする。

#### _before セクション（auditモード時のみ）

auditモードの入力の場合、改善前のトークン値を `_before` セクションとして保持する。
入力のaudit-*.mdレポートの「デザイントークン」セクション（改善前の抽出値）から自動抽出する。

```json
{
  "_before": {
    "color": {
      "semantic": {
        "primary": "{color.primitive.xxx}",
        "bg-primary": "{color.primitive.xxx}"
      }
    }
  }
}
```

`_before` の構造は抽出時の実態に従う: テーマ未対応サイトならフラット構造、テーマ対応サイトならlight/dark分岐。
`_before` はショーケースのBefore-Afterタブで使用される。

auditモードの入力の場合: 「改善後デザイントークン案」セクションの値を優先的に採用する。
learnモードの入力の場合: 抽出したトークンをそのまま構造化する。

---

## Phase 2: DESIGN.md 生成

AI（Claude Code等）がUI生成時に参照するデザインシステム定義ファイルを生成する。
Google Stitch標準の9セクション形式に従い、awesome-design-md（github.com/VoltAgent/awesome-design-md）と互換性のあるフォーマットで出力する。

出力先: `design-system/DESIGN.md`

### 9セクション構造

```markdown
# Design System: {プロジェクト名}

## 1. Visual Theme & Atmosphere

{デザインの雰囲気・哲学・第一印象を散文的に記述する。}
{入力のdissect/auditレポートの「サイト概要」「5軸分析 > 1. 視覚原則」から要素を抽出し、}
{デザインの「なぜ」を伝える文章にする。}
{Key Characteristicsとして箇条書きで特徴を5-7個列挙する。}

## 2. Color Palette & Roles

### Primary
- {セマンティック名} (`{HEX}`): {この色の役割・使いどころの説明}

### Secondary & Accent
- {セマンティック名} (`{HEX}`): {役割の説明}

### Surface & Background
- {セマンティック名} (`{HEX}`): {役割の説明}

### Neutrals & Text
- {セマンティック名} (`{HEX}`): {役割の説明}

### Semantic & Accent
- {セマンティック名} (`{HEX}`): {ボーダー・リング・ステートの説明}

### Gradient System
- {グラデーションの使い方、または「グラデーション不使用」の方針}

## 3. Typography Rules

### Font Family
- Headline: {フォント名}, with fallback: {フォールバック}
- Body / UI: {フォント名}, with fallback: {フォールバック}
- Code: {フォント名}, with fallback: {フォールバック}

### Hierarchy

| Role | Font | Size | Weight | Line Height | Letter Spacing | Notes |
|------|------|------|--------|-------------|----------------|-------|
| Display / Hero | ... | ... | ... | ... | ... | ... |
| Section Heading | ... | ... | ... | ... | ... | ... |
| ... | ... | ... | ... | ... | ... | ... |

### Principles
- {タイポグラフィの設計原則を箇条書きで3-5個}

## 4. Component Stylings

### Buttons
{各バリアント（Primary / Secondary / Ghost等）のBackground, Text, Padding, Radius, Shadow, Hover/Focusを記述}

### Cards & Containers
{Background, Border, Radius, Shadow, Padding}

### Inputs & Forms
{Text, Padding, Border, Focus状態, Radius}

### Navigation
{構造、リンクスタイル、CTAボタン、Hover挙動}

### Distinctive Components
{そのデザイン固有の特徴的コンポーネント}

## 5. Layout Principles

### Spacing System
- Base unit: {N}px
- Scale: {値一覧}

### Grid & Container
- Max container width: {値}
- {レイアウト構成の説明}

### Whitespace Philosophy
- {余白に対する設計哲学}

### Border Radius Scale
{各段階のradius値とその用途}

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | {値} | {用途} |
| Contained (Level 1) | {値} | {用途} |
| ... | ... | ... |

{シャドウの設計哲学}

## 7. Do's and Don'ts

### Do
- {推奨パターンを箇条書き}

### Don't
- {禁止パターンを箇条書き}

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|-------------|
| Mobile | {値} | {変化内容} |
| Tablet | {値} | {変化内容} |
| Desktop | {値} | {変化内容} |

### Touch Targets
- {タッチターゲットのサイズガイドライン}

### Collapsing Strategy
- {ナビゲーション、グリッド、タイポグラフィの折りたたみ方}

## 9. Agent Prompt Guide

### Quick Color Reference
- {役割}: "{セマンティック名} ({HEX})"

### Example Component Prompts
- "{AIへの具体的な指示例}"
- "{AIへの具体的な指示例}"

### Iteration Guide
{AIとの反復的な改善の進め方}
```

### 各セクションのデータソース

| セクション | 主な入力データ |
|-----------|--------------|
| 1. Visual Theme | dissect: サイト概要 + 5軸分析「視覚原則」 |
| 2. Color Palette | tokens.json: color + dissect: カラーパレット |
| 3. Typography | tokens.json: typography + dissect: タイポグラフィ |
| 4. Component Stylings | dissect: 5軸分析「UIパターン」+ スクリーンショット分析 |
| 5. Layout Principles | tokens.json: spacing + dissect: スペーシング |
| 6. Depth & Elevation | tokens.json: shadow + dissect: エフェクト |
| 7. Do's and Don'ts | dissect: 学びのポイント + audit問題点 + 共通禁止パターン |
| 8. Responsive | dissect: ブレークポイント抽出データ |
| 9. Agent Prompt | tokens.json全体からクイックリファレンスとプロンプト例を生成 |

### Do's and Don'ts の生成ルール

Do's:
- dissectレポートの「学びのポイント」「このサイト固有の工夫」からデザインの意図を推奨パターンとして抽出
- tokens.jsonの主要トークン（primary色、基本フォント、ベーススペーシング等）の正しい使い方を記述

Don'ts:
- auditモードの入力の場合: 問題点一覧から禁止パターンを抽出
- 共通の禁止パターン:
  - text-black (#000000) 禁止 → text-primary トークンを使う
  - shadow-lg の多用禁止 → shadow-sm で十分
  - 装飾的グラデーション禁止（ブランドで定義された場合を除く）
  - 絵文字の多用禁止
  - border-l-4 のカラーバー禁止
- dissectの5軸分析で検出されたデザイン方針に反するパターンを追加

### 記述スタイル

- Section 1 (Visual Theme) は散文的に記述し、デザインの「なぜ」を伝える
- Section 2-6 はリスト・テーブル形式で具体的な値とルールを記述する
- Section 7 は箇条書きで明確に推奨/禁止を列挙する
- Section 8 はテーブル + 箇条書きで構造的に記述する
- Section 9 はAIが直接コピーペーストできるプロンプト例を含める
- 全セクションで具体的なHEX値・px値・トークン名を記載し、曖昧な表現を避ける

---

## Phase 3: HTMLショーケース生成

ビジュアルガイドとして、tokens.jsonの値を使った単一HTMLファイルを生成する。

### 構成

ショーケースは3タブ構成で、ヘッダーにテーマ切替トグルを持つ。

#### ヘッダー + タブバー
- プロジェクト名 + 「Design System」
- タブボタン: Tokens / Before-After / Preview
- テーマ切替トグル: ☀/☽ アイコン（右端に配置）
- Before-Afterタブは `_before` データがある場合のみ表示

#### テーマ切替メカニズム
- `:root` にライトテーマのCSS変数を定義
- `[data-theme="dark"]` にダークテーマのCSS変数を定義
- 初期テーマは `meta.defaultTheme` に従う
- トグルクリックで `data-theme` 属性を切替
- テーマ分岐なし（旧形式）のtokens.jsonの場合はテーマトグルを非表示にする

#### Tab 1: Tokens
既存の7セクションをそのまま収容:
1. Colors: プライマリ/セカンダリ/ニュートラル/アクセントのスウォッチグリッド
2. Typography: 各レベルのサンプルテキストを実寸レンダリング。タイプスケール比率の図解
3. Spacing: スペーシングスケールをバー表示で可視化
4. Border Radius: 各radius値のサンプルボックス
5. Shadows: 各shadow値のサンプルカード
6. Components: ボタン、カード、入力フィールドのサンプル
7. Do / Don't: 禁止パターンの良い例・悪い例

テーマ切替で全セクションの表示色が即座に変わる。

#### Tab 2: Before-After（`_before`存在時のみ）
- 改善前（Before）と改善後（After）のトークンをスライダーで左右比較
- 背面にBefore（全体表示）、前面にAfter（clip-pathで表示範囲を制御）
- スライダーを右に動かすとAfter（改善後）の表示領域が広がる
- 比較表示要素: セマンティックカラースウォッチ、タイポグラフィサンプル、ボタン+カード
- マウスドラッグ + タッチ対応

#### Tab 3: Preview（SaaSランディングページテンプレート）
汎用SaaSランディングページテンプレートにデザイントークンを適用した実寸プレビュー:
- ナビゲーション（ロゴ + メニュー + CTAボタン）
- ヒーロー（H1見出し + リードテキスト + CTA 2つ）
- 3カラム機能カード（アイコン + タイトル + 説明）
- テスティモニアル（引用 + 発言者）
- 料金表（Free / Pro / Enterprise の3プラン）
- フッター（リンク列 + コピーライト）
全スタイルをCSS変数経由で適用し、テーマ切替で即座にlight/darkが切り替わる。

### 技術仕様

- 単一HTMLファイル（CSS・JSインライン）。外部依存なし
- CSS Custom Propertiesでtokens.jsonの値を反映
- レスポンシブ対応（PC/モバイル切替可能）
- テーマ切替: `:root` にライトテーマ、`[data-theme="dark"]` にダークテーマのCSS変数を定義。meta.defaultThemeに応じた初期テーマ設定
- セクション間のスムーズスクロールナビゲーション
- 各色スウォッチのクリックでHEX値をコピーする機能

### デザイン品質の基準

HTMLショーケース自体が「このデザインシステムで作るとこうなる」という見本であるべき。
ショーケース自身のスタイリングに生成したデザイントークンを適用する。

---

## Phase 4: 対話的改善ループ

生成後、ユーザーにビジュアルガイドの確認を依頼する。

```
1. 「design-system/showcase/index.html を開いて確認してください」と案内
   （localhostで配信中の場合はURLを案内）
2. ユーザーからのフィードバックを受け付ける
   例: 「primaryをもっと暖かい色に」「見出しの行間を詰めて」「ボタンの角丸をもっと大きく」
3. tokens.json を更新
4. 影響するファイルを再生成（showcase/index.html, DESIGN.md）
5. 「更新しました。再度確認してください」
6. ユーザーが「OK」「確定」「これで進める」と言うまでループ
```

確定時:
- 「デザインシステムが確定しました。このDSをベースに開発を進める場合は、odin-think-design → odin-think-plan → odin-do-implement で進められます」と案内
- DESIGN.md のパスをプロジェクトのCLAUDE.mdに参照設定として追加するか確認
  - 追加する場合: `## デザインシステム\n\nUI生成時は design-system/DESIGN.md に従うこと。` をCLAUDE.mdに追記

---

## エラーハンドリング

| エラー | 対処 |
|--------|------|
| 入力ファイルが見つからない | 「先にodin-design-dissectでサイトを分析してください」と案内 |
| tokens.jsonの値が不完全 | デフォルト値で補完し、ユーザーに確認 |
| HTMLの表示崩れ | Playwright MCPでスクリーンショットを取り、問題を特定して修正 |
