# HTMLショーケース仕様

design-dissect スキルの Phase 5 で生成するHTMLショーケースの構造仕様。
Phase 2（構造化データ）と Phase 4（MDレポート）のデータからHTMLを生成する。

---

## 1. CSS変数設計

### ライトモード（:root）

改善後トークン（auditモード）またはそのままの抽出トークン（learnモード）を `:root` に配置する。

```css
:root {
  /* Semantic: Light */
  --primary: {抽出/改善後のprimary色};
  --primary-hover: {primaryを10%暗くした色};
  --secondary: {抽出/改善後のsecondary色};
  --accent: {抽出/改善後のaccent色};
  --accent-hover: {accentを10%暗くした色};
  --error: {抽出/改善後のerror色};
  --bg-primary: {メイン背景色};
  --bg-secondary: {セクション背景色};
  --bg-tertiary: {カード背景色の暗い方};
  --bg-surface: {カード表面色};
  --text-primary: {メインテキスト色};
  --text-secondary: {サブテキスト色};
  --text-tertiary: {補足テキスト色};
  --text-inverse: {反転テキスト色};
  --border-default: {ボーダー色};
  --border-subtle: {薄いボーダー色};

  /* Typography */
  --font-sans: {抽出したフォントファミリー};
  --font-mono: "SF Mono", "Fira Code", Consolas, monospace;
  --fs-h1: {タイプスケール最大値}; --lh-h1: 1.2;
  --fs-h2: {次のスケール値};     --lh-h2: 1.2;
  --fs-h3: {...};               --lh-h3: 1.25;
  --fs-h4: {...};               --lh-h4: 1.25;
  --fs-h5: {...};               --lh-h5: 1.3;
  --fs-body-lg: {...};
  --fs-body: {ベースサイズ};
  --fs-sm: {...};
  --fs-xs: {...};
  --lh-body: 1.5;

  /* Spacing（8pxグリッド） */
  --sp-1: 4px; --sp-2: 8px; --sp-3: 12px; --sp-4: 16px;
  --sp-6: 24px; --sp-8: 32px; --sp-10: 40px;
  --sp-12: 48px; --sp-16: 64px; --sp-24: 96px;

  /* Border Radius */
  --radius-sm: 4px; --radius-md: 8px; --radius-lg: 12px; --radius-pill: 9999px;

  /* Shadow */
  --shadow-sm: 0 1px 3px rgba(0,0,0,0.08);
  --shadow-md: 0 4px 12px rgba(0,0,0,0.08);
  --shadow-lg: 0 8px 24px rgba(0,0,0,0.1);

  /* Transition */
  --transition: 0.2s ease;
}
```

### ダークモード（[data-theme="dark"]）

テーマ検出で2回抽出があればその値を使用する。テーマ未検出の場合は以下のルールで自動生成する:

- primary/secondary/accent: HSL明度を+15%
- bg-primary: #0f1117
- bg-secondary: #1a1d27
- bg-tertiary: #222636
- bg-surface: #1a1d27
- text-primary: #E4E6ED
- text-secondary: #9498A8
- text-tertiary: #6B7085
- text-inverse: #0f1117
- border-default: rgba(255,255,255,0.08)
- shadow: opacity を 3〜4倍に増加

```css
[data-theme="dark"] {
  --primary: {ダーク用primary};
  /* ...上記ルールに基づいて全変数をオーバーライド */
  --shadow-sm: 0 1px 3px rgba(0,0,0,0.3);
  --shadow-md: 0 4px 12px rgba(0,0,0,0.3);
  --shadow-lg: 0 8px 24px rgba(0,0,0,0.4);
}
```

---

## 2. ナビバー

```html
<nav class="topnav">
  <div class="topnav-brand">{サイト名} DS</div>
  <div class="topnav-tabs">
    <button class="topnav-tab active" data-tab="tokens">Tokens</button>
    <button class="topnav-tab" data-tab="before-after">Before / After</button>
    <button class="topnav-tab" data-tab="preview">Preview</button>
  </div>
  <div class="topnav-actions">
    <button class="theme-toggle" id="theme-toggle">☽</button>
  </div>
</nav>
```

スタイル:
- `position: sticky; top: 0; z-index: 100`
- `backdrop-filter: blur(12px)` で半透明ナビ
- タブは `.active` クラスで色変更
- テーマトグルは ☽（ライト表示中）/ ☀（ダーク表示中）を切替

---

## 3. Tab 1: Tokens

以下のセクションを順番に配置する。各セクションは `.section` クラスで統一。

### 3-1. カラースウォッチ

```html
<div class="swatch-grid"> <!-- grid: repeat(auto-fill, minmax(200px, 1fr)) -->
  <div class="swatch">
    <div class="swatch-color" style="background:var(--primary)"></div>
    <div class="swatch-info">
      <div class="swatch-name">{トークン名}</div>
      <div class="swatch-value">{HEX値}</div>
    </div>
  </div>
  <!-- 全semantic色について繰り返す -->
</div>
```

表示するトークン: primary, secondary, accent, error, bg-primary, bg-secondary, bg-tertiary, text-primary, text-secondary, text-tertiary, border-default, その他サイト固有の色

クリック動作: HEX値をクリップボードにコピーし、swatch-name を一時的に "Copied!" に変更

### 3-2. タイプスケール

Phase 2 のタイポグラフィデータから、改善後のスケール（auditモード）または抽出スケール（learnモード）を表示する。

```html
<div class="typo-scale">
  <div class="typo-row">
    <div class="typo-meta">
      <div class="typo-size">{サイズ}px</div>
      <div class="typo-weight">{ウェイト名} {数値}</div>
    </div>
    <div class="typo-sample" style="font-size:{表示サイズ};font-weight:{ウェイト};line-height:{行間比率}">
      {サンプルテキスト}
    </div>
  </div>
</div>
```

大きなサイズは表示用に80%程度に縮小して良い（48px → 40px表示等）。

### 3-3. スペーシングチャート

8pxグリッドスケールを横棒グラフで表示する。

```html
<div class="spacing-chart">
  <div class="spacing-row">
    <div class="spacing-label">{トークン名}: {値}</div>
    <div class="spacing-bar ok" style="width:{比率}px">{使用回数}</div>
  </div>
</div>
```

- `.ok` クラス: 8px倍数（primaryカラー）
- `.ng` クラス: 非倍数（accentカラー、opacity:0.7）

### 3-4. エフェクト

シャドウ・角丸・ボーダーのデモカード。

```html
<div class="effects-grid"> <!-- grid: repeat(auto-fill, minmax(280px, 1fr)) -->
  <div class="effect-card">
    <div class="effect-card-title">{カテゴリ名}</div>
    <div class="effect-item">
      <div class="effect-demo" style="{実際のCSS}"></div>
      <div class="effect-value">{トークン名}: {値}</div>
    </div>
  </div>
</div>
```

コンポーネントサンプルとして、実際のスタイルを適用したボタンも含める。

### 3-5. 問題一覧（auditモードのみ）

```html
<div class="issue-list">
  <div class="issue-card">
    <div class="issue-dot {critical/warning/info}"></div>
    <div>
      <div class="issue-title">{問題タイトル}</div>
      <div class="issue-desc">{説明と改善案}</div>
      <div class="badge badge-{severity}">{severity}</div>
    </div>
  </div>
</div>
```

issue-dot スタイル:
- `.critical`: background + box-shadow でグロー（errorカラー）
- `.warning`: 同上（accentカラー）
- `.info`: グローなし（secondaryカラー）

---

## 4. Tab 2: Before-After（auditモードのみ）

MDレポートの「改善後デザイントークン案」テーブルから改善前/後の値を取得してスライダーで比較する。

### 4-1. スライダー構造

```html
<div class="ba-container" id="ba-container">
  <!-- Before（左側・背面） -->
  <div class="ba-pane before" style="background:{現状bg色}">
    {改善前の値でスタイリングされた要素}
  </div>

  <!-- After（右側・前面） -->
  <div class="ba-pane after" style="clip-path: inset(0 0 0 50%)">
    {改善後の値でスタイリングされた要素}
  </div>

  <!-- スライダー -->
  <div class="ba-slider" id="ba-slider">
    <div class="ba-handle">⇔</div>
  </div>

  <div class="ba-label before-label">BEFORE</div>
  <div class="ba-label after-label">AFTER</div>
</div>
```

### 4-2. スライダーインタラクション

- マウスドラッグ: mousedown → mousemove → mouseup
- タッチ: touchstart → touchmove → touchend
- スライダー位置に応じて `clip-path: inset(0 0 0 {pct}%)` を更新
- 範囲制限: 5%〜95%

```javascript
function updateSlider(x) {
  const rect = container.getBoundingClientRect();
  let pct = ((x - rect.left) / rect.width) * 100;
  pct = Math.max(5, Math.min(95, pct));
  slider.style.left = pct + '%';
  afterPane.style.clipPath = `inset(0 0 0 ${pct}%)`;
}
```

### 4-3. 比較要素（Before/After 各ペインに配置）

1. カラースウォッチ（3x2グリッド: primary / secondary / accent / bg / bg-secondary / text）
2. タイポグラフィサンプル（H1見出し + body本文。改善前は現状のサイズ/行間、改善後はスケール適用後）
3. コンポーネント（CTAボタン + カード。改善前は現状のスタイル、改善後は改善トークン適用）

Before ペインは改善前の値をインラインstyleで直接指定する（CSS変数を使わない）。
After ペインはCSS変数 `var(--xxx)` を使用する（テーマ切替に追従）。

---

## 5. Tab 3: Preview（SaaS LPテンプレート）

改善後トークン（またはそのまま抽出トークン）を適用した汎用SaaS LPテンプレート。
全スタイルをCSS変数経由で適用し、テーマトグルで即座に切り替わるデモ。

### 5-1. セクション構成

```
┌─────────────────────────────────────────┐
│ ナビゲーション                            │
│ [ブランド名] [リンク群]          [CTA]    │
├─────────────────────────────────────────┤
│ ヒーロー（bg-secondary）                  │
│   H1見出し / サブテキスト / 2つのボタン     │
├─────────────────────────────────────────┤
│ 機能紹介（bg-primary）                    │
│   H2見出し / 3カラムの機能カード            │
├─────────────────────────────────────────┤
│ テスティモニアル（bg-secondary）           │
│   引用文 / 引用元                         │
├─────────────────────────────────────────┤
│ 料金表（bg-primary）                     │
│   H2見出し / 3カラムの料金カード            │
│   中央カードに「おすすめ」バッジ             │
├─────────────────────────────────────────┤
│ フッター（bg-tertiary）                   │
│   コピーライト                            │
└─────────────────────────────────────────┘
```

### 5-2. コンテンツのカスタマイズ

テンプレートのテキストコンテンツは、分析対象サイトの業界・サービスに合わせて調整する:
- ヒーローのH1/サブテキスト: 対象サイトのキャッチコピーや価値提案を参考に
- 機能カード: 対象サイトの主要機能を3つ選んで要約
- テスティモニアル: 対象サイトのユーザーの声セクションを参考に
- 料金表: 対象サイトの料金体系があればそれを参考に（なければ汎用的な3段階）

### 5-3. CSS変数の適用箇所

| 要素 | 適用する変数 |
|------|------------|
| ナビ背景 | `var(--bg-surface)` |
| ナビCTA | `var(--primary)` / `var(--text-inverse)` |
| ヒーロー背景 | `var(--bg-secondary)` |
| ヒーローH1 | `var(--text-primary)` / `var(--fs-h1)` |
| ヒーロー本文 | `var(--text-secondary)` |
| プライマリボタン | `var(--accent)` / `var(--text-inverse)` |
| セカンダリボタン | `border: var(--border-default)` / `var(--text-secondary)` |
| 機能カード | `var(--bg-surface)` / `var(--shadow-sm)` / `var(--radius-lg)` |
| 機能カードhover | `var(--shadow-md)` / `translateY(-2px)` |
| テスティモニアル | `var(--bg-secondary)` / `var(--text-secondary)` |
| 料金カード | `var(--bg-surface)` / `var(--border-default)` |
| おすすめカード | `border-color: var(--primary)` / `var(--shadow-md)` |
| フッター | `var(--bg-tertiary)` / `var(--text-tertiary)` |

---

## 6. JavaScript

### 6-1. テーマ切替

```javascript
const toggle = document.getElementById('theme-toggle');
toggle.addEventListener('click', () => {
  const current = document.documentElement.getAttribute('data-theme');
  if (current === 'dark') {
    document.documentElement.removeAttribute('data-theme');
    toggle.textContent = '☽';
  } else {
    document.documentElement.setAttribute('data-theme', 'dark');
    toggle.textContent = '☀';
  }
});
```

初期テーマ: learnモードで背景が暗い場合は `data-theme="dark"` を初期設定。それ以外はライト。

### 6-2. タブ切替

```javascript
document.querySelectorAll('.topnav-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.topnav-tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    tab.classList.add('active');
    document.getElementById('tab-' + tab.dataset.tab).classList.add('active');
  });
});
```

### 6-3. Before-Afterスライダー

セクション4-2のインタラクション仕様を参照。マウスとタッチの両方に対応する。

### 6-4. カラースウォッチのコピー

```javascript
document.querySelectorAll('.swatch').forEach(s => {
  s.style.cursor = 'pointer';
  s.addEventListener('click', () => {
    const val = s.querySelector('.swatch-value')?.textContent;
    if (val && val !== 'theme-aware') {
      navigator.clipboard.writeText(val).then(() => {
        const nameEl = s.querySelector('.swatch-name');
        const orig = nameEl.textContent;
        nameEl.textContent = 'Copied!';
        setTimeout(() => { nameEl.textContent = orig; }, 1000);
      });
    }
  });
});
```

---

## 7. レスポンシブ

ブレークポイント: 768px

```css
@media (max-width: 768px) {
  .topnav { padding: var(--sp-2) var(--sp-4); }
  .topnav-brand { font-size: 15px; }
  .topnav-tab { padding: var(--sp-1) var(--sp-2); font-size: 12px; }
  .tab-content { padding: var(--sp-6) var(--sp-4); }
  .swatch-grid { grid-template-columns: repeat(2, 1fr); }
  .typo-row { flex-direction: column; gap: var(--sp-1); }
  .typo-meta { text-align: left; }
  .pv-features-grid, .pv-pricing-grid { grid-template-columns: 1fr; }
  .pv-hero h1 { font-size: var(--fs-h3); }
  .pv-nav-links { display: none; }
  .ba-container { height: 500px; }
}
```

---

## 8. モード別動作

| 要素 | learn モード | audit モード |
|------|-------------|-------------|
| Tab 1: Tokens | 抽出トークンを表示 | 改善後トークン + 問題一覧を表示 |
| Tab 2: Before-After | 非表示（タブ自体を生成しない） | 表示（改善前/後スライダー比較） |
| Tab 3: Preview | 抽出トークンでプレビュー | 改善後トークンでプレビュー |
| テーマ切替 | テーマ検出時のみ表示 | 常に表示（ダーク版を自動生成） |
| カラースウォッチ swatch-value | HEX値を表示 | 改善前→改善後の場合 "theme-aware" |
| 問題一覧セクション | 非表示 | 表示（critical/warning/info） |

### learnモードの出力

```
成果物:
  - dissect-{site}-{timestamp}.md（MDレポート）
  - showcase-{site}-{timestamp}.html（HTMLショーケース）
```

### auditモードの出力

```
成果物:
  - audit-{site}-{timestamp}.md（MDレポート）
  - showcase-{site}-{timestamp}.html（HTMLショーケース）
```
