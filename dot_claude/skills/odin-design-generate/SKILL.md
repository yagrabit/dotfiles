---
name: odin-design-generate
description: "デザイン分析結果からデザインシステム（HTMLビジュアルガイド + tokens.json + design.md）を生成し、対話的に改善する"
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_resize
---

# odin-design-generate

odin-design-dissect の分析結果（dissect-*.md / audit-*.md）から、人間とAI両方が使えるデザインシステムを生成するスキル。
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
├── tokens.json          ← SSOT: 全デザイントークン
├── design.md            ← AI向けルール定義
├── prohibited.md        ← 禁止パターン
├── showcase/
│   └── index.html       ← ビジュアルガイド（人間向け）
└── claude-snippet.md    ← CLAUDE.mdに貼るクイックリファレンス
```

AskUserQuestionで出力先を確認する:
- 「design-system/ ディレクトリに生成します。場所を変更しますか？」

---

## Phase 1: トークン構造化

入力ファイルから抽出済みのトークンデータを読み取り、tokens.json を生成する。

### tokens.json の構造

```json
{
  "color": {
    "primitive": {
      "blue-500": "#3182CE",
      "slate-900": "#1A202C"
    },
    "semantic": {
      "primary": "{color.primitive.blue-500}",
      "bg-primary": "{color.primitive.slate-900}",
      "text-primary": "{color.primitive.slate-200}"
    }
  },
  "typography": {
    "font-family": {
      "heading": "Inter",
      "body": "Inter",
      "code": "SFMono-Regular"
    },
    "font-size": {
      "xs": "12px",
      "sm": "14px",
      "base": "16px",
      "lg": "18px",
      "xl": "20px",
      "2xl": "24px",
      "3xl": "36px",
      "4xl": "44px",
      "5xl": "68px"
    },
    "font-weight": {
      "normal": "400",
      "semibold": "600",
      "bold": "700"
    },
    "line-height": {
      "tight": "1.15",
      "snug": "1.25",
      "normal": "1.5",
      "relaxed": "1.6"
    },
    "scale": {
      "name": "Perfect Fourth",
      "ratio": 1.333
    }
  },
  "spacing": {
    "base": "8px",
    "scale": {
      "xs": "4px",
      "sm": "8px",
      "md": "16px",
      "lg": "24px",
      "xl": "32px",
      "2xl": "48px",
      "3xl": "64px",
      "4xl": "96px"
    }
  },
  "border-radius": {
    "sm": "4px",
    "md": "8px",
    "lg": "12px",
    "full": "9999px"
  },
  "shadow": {
    "sm": "rgba(0,0,0,0.05) 0px 4px 6px -1px",
    "md": "rgba(0,0,0,0.1) 0px 8px 16px -4px",
    "lg": "rgba(0,0,0,0.15) 0px 16px 32px -8px"
  }
}
```

auditモードの入力の場合: 「改善後デザイントークン案」セクションの値を優先的に採用する。
learnモードの入力の場合: 抽出したトークンをそのまま構造化する。

---

## Phase 2: design.md 生成

AI（Claude Code）がUI生成時に参照するルール定義ファイルを生成する。

含める内容:
- カラーシステム（各色の用途と使い分けルール）
- タイポグラフィ（フォント、サイズ階層、ウェイトの使い分け、行間ルール）
- スペーシング（基本単位、スケール、使い分け）
- コンポーネント仕様（ボタン、カード、ナビゲーション等のクラスとHTML構造）
- レイアウトパターン（グリッド、セクション構成）

形式: melta-uiのdesign.mdを参考に、クイックリファレンス（テーブル形式）を中心に構成する。

---

## Phase 3: prohibited.md 生成

禁止パターンリストを生成する。

auditモードの入力の場合: 問題点一覧から禁止パターンを自動抽出する。
共通の禁止パターン（melta-uiの知見から）:
- text-black (#000000) 禁止 → text-primary トークンを使う
- shadow-lg の多用禁止 → shadow-sm で十分
- 装飾的グラデーション禁止（ブランドで定義された場合を除く）
- 絵文字の多用禁止
- border-l-4 のカラーバー禁止

形式:
```markdown
# 禁止パターン

| # | カテゴリ | 禁止 | 代替 | 理由 |
|---|---------|------|------|------|
| 1 | 色 | text-black / #000000 | text-primary トークン | コントラストが硬すぎる |
```

---

## Phase 4: HTMLショーケース生成

ビジュアルガイドとして、tokens.jsonの値を使った単一HTMLファイルを生成する。

### 構成セクション

1. ヘッダー: プロジェクト名 + 「Design System」
2. Colors: プライマリ/セカンダリ/ニュートラル/アクセントのスウォッチグリッド。各色にトークン名・HEX値・RGB値を表示
3. Typography: 各レベル（H1〜body〜caption）のサンプルテキストを実寸レンダリング。フォント名・サイズ・ウェイト・行間を表示。タイプスケール比率の図解
4. Spacing: スペーシングスケールをバー表示で可視化。各値のトークン名・px値を表示
5. Border Radius: 各radius値のサンプルボックス
6. Shadows: 各shadow値のサンプルカード
7. Components: ボタン（プライマリ/セカンダリ/サイズ違い）、カード、入力フィールドのサンプル
8. Do / Don't: 禁止パターンの良い例・悪い例を並べて表示

### 技術仕様

- 単一HTMLファイル（CSS・JSインライン）。外部依存なし
- CSS Custom Propertiesでtokens.jsonの値を反映
- レスポンシブ対応（PC/モバイル切替可能）
- ダークモード/ライトモード切替トグル（該当する場合）
- セクション間のスムーズスクロールナビゲーション
- 各色スウォッチのクリックでHEX値をコピーする機能

### デザイン品質の基準

HTMLショーケース自体が「このデザインシステムで作るとこうなる」という見本であるべき。
ショーケース自身のスタイリングに生成したデザイントークンを適用する。

---

## Phase 5: claude-snippet.md 生成

CLAUDE.mdに貼り付けるクイックリファレンスを生成する。

含める内容:
- カラートークンのテーブル（トークン名 → 値 → 用途）
- ボタン・カード等の頻出コンポーネントのクラス指定
- 禁止パターンの要約（上位10件）
- 「詳細はdesign-system/design.mdを参照」の案内

---

## Phase 6: 対話的改善ループ

生成後、ユーザーにビジュアルガイドの確認を依頼する。

```
1. 「design-system/showcase/index.html を開いて確認してください」と案内
   （localhostで配信中の場合はURLを案内）
2. ユーザーからのフィードバックを受け付ける
   例: 「primaryをもっと暖かい色に」「見出しの行間を詰めて」「ボタンの角丸をもっと大きく」
3. tokens.json を更新
4. 影響するファイルを再生成（showcase/index.html, design.md, claude-snippet.md）
5. 「更新しました。再度確認してください」
6. ユーザーが「OK」「確定」「これで進める」と言うまでループ
```

確定時:
- 「デザインシステムが確定しました。このDSをベースに開発を進める場合は、odin-think-design → odin-think-plan → odin-do-implement で進められます」と案内
- claude-snippet.md の内容をプロジェクトのCLAUDE.mdに追加するか確認

---

## エラーハンドリング

| エラー | 対処 |
|--------|------|
| 入力ファイルが見つからない | 「先にodin-design-dissectでサイトを分析してください」と案内 |
| tokens.jsonの値が不完全 | デフォルト値で補完し、ユーザーに確認 |
| HTMLの表示崩れ | Playwright MCPでスクリーンショットを取り、問題を特定して修正 |
