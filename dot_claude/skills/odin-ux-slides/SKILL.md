---
name: odin-ux-slides
description: Chart.js・デザイントークン・コピーライティング公式を使ったHTMLプレゼンテーションを生成する。戦略選択→レイアウト決定→コピー最適化→スライド出力の一連フローを自動化する。
argument-hint: "[topic] [slide-count]"
user-invocable: true
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# odin-ux-slides

Chart.js・デザイントークン・コピーライティング公式で戦略的HTMLプレゼンテーションを生成する。

<args>$ARGUMENTS</args>

## 使いどころ

- マーケティングプレゼンや投資家向けピッチデッキの作成
- Chart.js を用いたデータビジュアライゼーションを含むスライド
- 戦略的なレイアウトパターンとコピーライティング公式を活用した資料
- ブランドデザイントークン準拠のHTML単一ファイル出力

## 実行フロー

### ステップ1: ゴール解析

`$ARGUMENTS` からトピック・スライド枚数・対象オーディエンスを解析する。
情報が不足している場合は `AskUserQuestion` でトピックと目的を確認する。

### ステップ2: 戦略選択

BM25検索で最適なデッキ構造を取得する。

```bash
cd ~/.claude/skills/odin-ux-slides
python scripts/search-slides.py "{topic}" -d strategy
```

`data/slide-strategies.csv` から以下を特定する:
- デッキ構造（YC Seed Deck, Nancy Duarte Sparkline 等）
- 感情アーク（curiosity → frustration → hope → confidence → trust → urgency）
- スパークラインビート（1/3・2/3 位置でのパターンブレイク）

戦略リファレンス: `references/slide-strategies.md`

### ステップ3: 各スライドの意思決定

各スライドについて以下を順に決定する。

```bash
# コンテキスト付き検索（位置・前感情を考慮）
python scripts/search-slides.py "{slide_goal}" --context --position {n} --total {total} --prev-emotion {emotion}

# レイアウト決定
python scripts/search-slides.py "{slide_goal}" -d layout

# タイポグラフィ・カラー個別検索
python scripts/search-slides.py "{content_type}" -d typography
python scripts/search-slides.py "{emotion}" -d color
```

Decision System CSVs:

| ファイル | 用途 |
|---------|------|
| `data/slide-strategies.csv` | 15種のデッキ構造 + 感情アーク + スパークラインビート |
| `data/slide-layouts.csv` | 25種のレイアウト + コンポーネントバリアント + アニメーション |
| `data/slide-layout-logic.csv` | ゴール → レイアウト + break_pattern フラグ |
| `data/slide-typography.csv` | コンテンツタイプ → タイポグラフィスケール |
| `data/slide-color-logic.csv` | 感情 → カラートリートメント |
| `data/slide-backgrounds.csv` | スライドタイプ → 背景画像カテゴリ（Pexels/Unsplash） |
| `data/slide-copy.csv` | 25種のコピーライティング公式（PAS, AIDA, FAB 等） |
| `data/slide-charts.csv` | 25種のチャートタイプ + Chart.js 設定 |

### ステップ4: コピー生成

コピーライティング公式を検索してスライドのコピーに適用する。

```bash
python scripts/search-slides.py "{copy_goal}" -d copy
```

公式リファレンス: `references/copywriting-formulas.md`

主要公式:
- PAS（Problem → Agitation → Solution）: 課題提起スライドに
- AIDA（Attention → Interest → Desire → Action）: CTAスライドに
- FAB（Features → Advantages → Benefits）: 製品説明スライドに

### ステップ5: HTML 生成

`references/html-template.md` のベーステンプレートを使い、単一 HTML ファイルを生成する。

制約（必須）:
1. デザイントークンは `<style>` 内の `:root {}` にインラインで定義する（外部CSSファイル参照不可）
2. CSS 変数を使用する: `var(--color-primary)`, `var(--slide-bg)` 等
3. チャートには Chart.js を使用する（CSSのみのバーグラフ不可）
4. ナビゲーション必須（キーボード矢印キー・クリック・プログレスバー）
5. コンテンツはセンター配置
6. スライドコンテンツは必ず `.slide-content` ラッパーで囲む

HTMLテンプレートリファレンス: `references/html-template.md`
レイアウトパターンリファレンス: `references/layout-patterns.md`

### ステップ6: バリデーション

生成した HTML のトークン準拠を検証する。

```bash
python scripts/slide-token-validator.py {output_file}
```

エラーがあれば修正してから出力する。

### ステップ7: 出力

生成した HTML を Write ツールで出力先に書き込む。
出力先が未指定の場合は `{topic}-slides-{yyyyMMdd}.html` のファイル名でカレントディレクトリに出力する。

## デザイントークン規則

```css
/* 正しい使い方 - CSS変数を参照 */
background: var(--slide-bg);
color: var(--color-primary);
font-family: var(--typography-font-heading);

/* 禁止 - ハードコード */
background: #0D0D0D;
color: #FF6B6B;
font-family: 'Space Grotesk';
```

デフォルトトークン（デザインシステム未定義の場合に使用）:

| CSS変数 | デフォルト値 | 用途 |
|---------|------------|------|
| `--color-primary` | `#FF6B6B` | CTA・ハイライト |
| `--color-background` | `#0D0D0D` | スライド背景 |
| `--color-secondary` | `#FF8E53` | サブ要素 |
| `--primitive-gradient-primary` | `linear-gradient(135deg, #FF6B6B, #FF8E53)` | タイトルグラデーション |
| `--typography-font-heading` | `'Space Grotesk', sans-serif` | 見出し |
| `--typography-font-body` | `'Inter', sans-serif` | 本文 |

## Chart.js 統合

```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>

<div class="chart-container" style="width: min(80%, 600px); height: clamp(200px, 40vh, 350px);">
    <canvas id="revenueChart"></canvas>
</div>
<script>
new Chart(document.getElementById('revenueChart'), {
    type: 'line',
    data: {
        labels: ['Sep', 'Oct', 'Nov', 'Dec'],
        datasets: [{
            data: [5, 12, 28, 45],
            borderColor: 'var(--color-primary)',
            backgroundColor: 'rgba(255, 107, 107, 0.1)',
            borderWidth: 3,
            fill: true,
            tension: 0.4
        }]
    },
    options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
            x: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#B8B8D0' } },
            y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#B8B8D0' } }
        }
    }
});
</script>
```

チャートタイプの検索:

```bash
python scripts/search-slides.py "revenue growth trend" -d chart
```

## パターンブレイク（Duarte Sparkline）

感情のコントラストでエンゲージメントを高める。
「現状（frustration）」と「理想（hope）」を交互に配置する:

```
現状（frustration） ↔ 理想（hope）
```

1/3 と 2/3 の位置でパターンブレイクを挿入する。
`--context` フラグを使うと、前のスライドの感情を考慮した決定が自動化される。

## リファレンスファイル一覧

| ファイル | 内容 |
|---------|------|
| `references/create.md` | スライド作成の詳細手順 |
| `references/html-template.md` | HTMLベーステンプレート・アニメーションクラス |
| `references/layout-patterns.md` | レイアウトパターン集 |
| `references/copywriting-formulas.md` | コピーライティング公式集 |
| `references/slide-strategies.md` | 15種のデッキ構造リファレンス |

## スクリプト一覧

| スクリプト | 用途 |
|-----------|------|
| `scripts/search-slides.py` | スライドDB横断BM25検索CLI |
| `scripts/slide_search_core.py` | 検索コアモジュール（search-slides.pyが内部利用） |
| `scripts/slide-token-validator.py` | 生成HTMLのトークン準拠バリデーション |
| `scripts/fetch-background.py` | 背景画像の取得 |
| `scripts/generate-slide.py` | HTMLスライド生成（スクリプト単体利用時） |

スクリプトは `~/.claude/skills/odin-ux-slides/scripts/` に配置される。
