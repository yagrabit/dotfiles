---
name: ux-5-design
description: "ロゴ生成（55スタイル）・CIPモックアップ・アイコン・ソーシャルフォト生成。Gemini AIを活用した総合デザインスキル"
user-invocable: true
allowed-tools: Bash, Read, Write, AskUserQuestion
---

## 言語

- ユーザーとのやりとりは日本語で行うこと
- 検索クエリやスクリプト実行時のキーワードは英語を使用すること（CSVデータが英語のため）
- 検索結果の説明・提案は日本語に翻訳して伝えること

# Design

ロゴ、CIP（コーポレートアイデンティティプログラム）、アイコンの生成を統合したデザインスキル。

## セットアップ

### 認証（3段階フォールバック）

スクリプトは以下の優先順位で認証を試みます。いずれか1つが設定されていれば動作します:

1. APIキー（最も簡単、推奨）
   ```bash
   export GEMINI_API_KEY='your-key'
   # https://aistudio.google.com/apikey で無料取得（500画像/日）
   ```

2. .envファイル
   ```bash
   echo 'GEMINI_API_KEY=your-key' >> ~/.claude/.env
   ```

3. ADC - Application Default Credentials（APIキー管理不要）
   ```bash
   gcloud auth application-default login
   export GOOGLE_CLOUD_PROJECT='your-project-id'
   # Vertex AI APIの有効化が必要
   ```

### パッケージ

```bash
pip install google-genai pillow
```

## スキル名マッピング

関連スキルとの連携:
- `ui-ux-pro-max` / `ux-3-core` → UI/UXデザインインテリジェンス
- `ux-4-styling` → shadcn/ui + Tailwind CSSスタイリング
- `ux-2-tokens` → デザイントークン設計
- `ux-6-banner` → バナーデザイン
- `ux-1-brand` → ブランドアイデンティティ管理
- `ux-7-slides` → HTMLプレゼンテーション

## スクリプトパス

全スクリプトはこのスキルディレクトリ内にあります:
`~/.claude/skills/ux-5-design/scripts/`

---

## ロゴデザイン

55+ スタイル、30 カラーパレット、25 業界ガイド。Gemini Nano Bananaモデル使用。

### ロゴ: デザインブリーフ生成

```bash
python3 ~/.claude/skills/ux-5-design/scripts/logo/search.py "tech startup modern" --design-brief -p "BrandName"
```

### ロゴ: スタイル/カラー/業界検索

```bash
python3 ~/.claude/skills/ux-5-design/scripts/logo/search.py "minimalist clean" --domain style
python3 ~/.claude/skills/ux-5-design/scripts/logo/search.py "tech professional" --domain color
python3 ~/.claude/skills/ux-5-design/scripts/logo/search.py "healthcare medical" --domain industry
```

### ロゴ: AI生成

出力ロゴ画像は白背景で生成すること。

```bash
python3 ~/.claude/skills/ux-5-design/scripts/logo/generate.py --brand "TechFlow" --style minimalist --industry tech
python3 ~/.claude/skills/ux-5-design/scripts/logo/generate.py --prompt "coffee shop vintage badge" --style vintage
```

スクリプトが失敗した場合は直接修正を試みること。

生成後、AskUserQuestionでHTMLプレビューを作成するか確認する。希望する場合は `/ux-3-core` でギャラリーを作成。

---

## CIPデザイン

50+ 成果物、20 スタイル、20 業界。Gemini Nano Banana（Flash/Pro）。

### CIP: ブリーフ生成

```bash
python3 ~/.claude/skills/ux-5-design/scripts/cip/search.py "tech startup" --cip-brief -b "BrandName"
```

### CIP: ドメイン検索

```bash
python3 ~/.claude/skills/ux-5-design/scripts/cip/search.py "business card letterhead" --domain deliverable
python3 ~/.claude/skills/ux-5-design/scripts/cip/search.py "luxury premium elegant" --domain style
python3 ~/.claude/skills/ux-5-design/scripts/cip/search.py "hospitality hotel" --domain industry
python3 ~/.claude/skills/ux-5-design/scripts/cip/search.py "office reception" --domain mockup
```

### CIP: モックアップ生成

```bash
# ロゴ付き（推奨）
python3 ~/.claude/skills/ux-5-design/scripts/cip/generate.py --brand "TopGroup" --logo /path/to/logo.png --deliverable "business card" --industry "consulting"

# フルCIPセット
python3 ~/.claude/skills/ux-5-design/scripts/cip/generate.py --brand "TopGroup" --logo /path/to/logo.png --industry "consulting" --set

# Proモデル（4Kテキスト品質）
python3 ~/.claude/skills/ux-5-design/scripts/cip/generate.py --brand "TopGroup" --logo logo.png --deliverable "business card" --model pro

# ロゴなし
python3 ~/.claude/skills/ux-5-design/scripts/cip/generate.py --brand "TechFlow" --deliverable "business card" --no-logo-prompt
```

モデル: `flash`（デフォルト、`gemini-2.5-flash-image`）、`pro`（`gemini-3-pro-image-preview`）

### CIP: HTMLプレゼンテーション生成

```bash
python3 ~/.claude/skills/ux-5-design/scripts/cip/render-html.py --brand "TopGroup" --industry "consulting" --images /path/to/cip-output
```

ロゴが未作成の場合は、先にロゴデザインセクションで生成すること。

---

## アイコンデザイン

15 スタイル、12 カテゴリ。Gemini 3.1 Pro PreviewでSVGテキスト出力。

### アイコン: 単体生成

```bash
python3 ~/.claude/skills/ux-5-design/scripts/icon/generate.py --prompt "settings gear" --style outlined
python3 ~/.claude/skills/ux-5-design/scripts/icon/generate.py --prompt "shopping cart" --style filled --color "#6366F1"
python3 ~/.claude/skills/ux-5-design/scripts/icon/generate.py --name "dashboard" --category navigation --style duotone
```

### アイコン: バッチ生成

```bash
python3 ~/.claude/skills/ux-5-design/scripts/icon/generate.py --prompt "cloud upload" --batch 4 --output-dir ./icons
```

### アイコン: マルチサイズ出力

```bash
python3 ~/.claude/skills/ux-5-design/scripts/icon/generate.py --prompt "user profile" --sizes "16,24,32,48" --output-dir ./icons
```

### アイコン: API不要モード

APIキー未設定時でも、`--no-api` フラグでプロンプト情報をJSON出力できます。
このJSONをClaude等のLLMに渡してSVGを生成させることが可能です。

```bash
python3 ~/.claude/skills/ux-5-design/scripts/icon/generate.py --prompt "settings gear" --style outlined --no-api
```

### アイコン: 主要スタイル

| スタイル | 用途 |
|---------|------|
| outlined | UIインターフェース、Webアプリ |
| filled | モバイルアプリ、ナビバー |
| duotone | マーケティング、ランディングページ |
| rounded | フレンドリーなアプリ、ヘルスケア |
| sharp | テック、フィンテック、エンタープライズ |
| flat | マテリアルデザイン、Google風 |
| gradient | モダンブランド、SaaS |

モデル: `gemini-3.1-pro-preview` — テキストのみ出力（SVGはXMLテキスト）。画像生成APIは不要。

---

## ワークフロー

### ブランドパッケージ一式

1. ロゴ → `scripts/logo/generate.py` → ロゴバリエーション生成
2. CIP → `scripts/cip/generate.py --logo ...` → 成果物モックアップ作成
3. プレゼンテーション → `scripts/cip/render-html.py` → ピッチデッキ生成

### デザインシステム構築

1. ブランド（`/ux-1-brand`）→ カラー、タイポグラフィ、ボイス定義
2. トークン（`/ux-2-tokens`）→ セマンティックトークン層作成
3. 実装（`/ux-4-styling`）→ Tailwind、shadcn/ui設定

## リファレンス

| トピック | ファイル |
|---------|---------|
| デザインルーティング | `references/design-routing.md` |
| ロゴデザインガイド | `references/logo-design.md` |
| ロゴスタイル | `references/logo-style-guide.md` |
| ロゴカラー心理学 | `references/logo-color-psychology.md` |
| ロゴプロンプト | `references/logo-prompt-engineering.md` |
| CIPデザインガイド | `references/cip-design.md` |
| CIP成果物 | `references/cip-deliverable-guide.md` |
| CIPスタイル | `references/cip-style-guide.md` |
| CIPプロンプト | `references/cip-prompt-engineering.md` |
| アイコンデザインガイド | `references/icon-design.md` |

## スクリプト一覧

| スクリプト | 用途 |
|-----------|------|
| `scripts/auth.py` | 共通認証モジュール（APIキー/ADCフォールバック） |
| `scripts/logo/search.py` | ロゴスタイル・カラー・業界検索 |
| `scripts/logo/generate.py` | Gemini AIによるロゴ生成 |
| `scripts/logo/core.py` | ロゴデータ用BM25検索エンジン |
| `scripts/cip/search.py` | CIP成果物・スタイル・業界検索 |
| `scripts/cip/generate.py` | Gemini AIによるCIPモックアップ生成 |
| `scripts/cip/render-html.py` | CIPモックアップのHTMLプレゼンテーション生成 |
| `scripts/cip/core.py` | CIPデータ用BM25検索エンジン |
| `scripts/icon/generate.py` | SVGアイコン生成（Gemini 3.1 Pro / --no-apiモード対応） |

## データ

| ディレクトリ | 内容 |
|------------|------|
| `data/logo/` | styles.csv (55スタイル), colors.csv (30パレット), industries.csv (25業界) |
| `data/cip/` | deliverables.csv (50成果物), styles.csv (20スタイル), industries.csv (20業界), mockup-contexts.csv (20シーン) |
| `data/icon/` | styles.csv (15スタイル) |
