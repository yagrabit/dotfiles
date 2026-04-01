---
name: odin-design-dissect
description: "WebサイトURLからデザインシステムを抽出・分析。learnモードで知見を言語化、auditモードで改善点を提案する"
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, Agent, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_resize, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_wait_for, mcp__plugin_playwright_playwright__browser_click
---

# odin-design-dissect

WebサイトのURLからデザインシステムを抽出・分析するスキル。

## 言語

- ユーザーとのやりとりは日本語で行う
- レポート出力も日本語

## 前提条件

- Playwright MCPが接続されていること
- 接続確認: Playwright MCPツールが利用可能かチェック。利用不可の場合はユーザーに設定手順を案内して終了する

## モード判定

ユーザーの入力とURLから自動判定し、AskUserQuestionで確認する。

| 条件 | 推定モード |
|------|----------|
| URLが localhost / 127.0.0.1 / 0.0.0.0 | audit |
| URLが外部サイト | learn |
| ユーザーが「分析して」「学びたい」 | learn |
| ユーザーが「監査して」「改善して」「問題を見つけて」 | audit |

判定後にAskUserQuestionで確認:
- 「{URL} を {learn/audit} モードで分析します。よろしいですか？」
- 選択肢: 「はい」「モードを変更する」

---

## Phase 1: Extract（トークン抽出）

### 1-1. ページ表示

```
browser_navigate → 対象URL
browser_wait_for → "networkidle"（SPA対応: コンテンツのレンダリング完了を待つ）
```

### 1-2. スクリーンショット取得

```
browser_resize → width: 1440, height: 900
browser_take_screenshot → デスクトップ表示を記録

browser_resize → width: 390, height: 844
browser_take_screenshot → モバイル表示を記録
```

### 1-3. デザイントークン抽出

browser_evaluate で以下の4つのJSスニペットを順番に実行する。

#### 色の抽出

```javascript
(() => {
  const colors = new Map();
  document.querySelectorAll('*').forEach(el => {
    const style = getComputedStyle(el);
    ['color', 'backgroundColor', 'borderColor'].forEach(prop => {
      const val = style[prop];
      if (val && val !== 'rgba(0, 0, 0, 0)' && val !== 'transparent') {
        colors.set(val, (colors.get(val) || 0) + 1);
      }
    });
  });
  return Object.fromEntries([...colors.entries()].sort((a, b) => b[1] - a[1]).slice(0, 30));
})()
```

#### タイポグラフィの抽出

```javascript
(() => {
  const typo = new Map();
  document.querySelectorAll('h1,h2,h3,h4,h5,h6,p,span,a,li,td,th,label,button').forEach(el => {
    const style = getComputedStyle(el);
    const key = JSON.stringify({
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      lineHeight: style.lineHeight,
      letterSpacing: style.letterSpacing
    });
    if (!typo.has(key)) {
      typo.set(key, { ...JSON.parse(key), count: 0, sampleText: el.textContent?.slice(0, 50), tag: el.tagName });
    }
    typo.get(key).count++;
  });
  return [...typo.values()].sort((a, b) => b.count - a.count);
})()
```

#### スペーシングの抽出

```javascript
(() => {
  const spacing = { padding: new Map(), margin: new Map(), gap: new Map() };
  document.querySelectorAll('*').forEach(el => {
    const style = getComputedStyle(el);
    ['padding', 'margin'].forEach(prop => {
      ['Top', 'Right', 'Bottom', 'Left'].forEach(dir => {
        const val = style[prop + dir];
        if (val && val !== '0px') {
          spacing[prop].set(val, (spacing[prop].get(val) || 0) + 1);
        }
      });
    });
    const gap = style.gap;
    if (gap && gap !== 'normal') {
      spacing.gap.set(gap, (spacing.gap.get(gap) || 0) + 1);
    }
  });
  return {
    padding: Object.fromEntries([...spacing.padding.entries()].sort((a, b) => b[1] - a[1]).slice(0, 20)),
    margin: Object.fromEntries([...spacing.margin.entries()].sort((a, b) => b[1] - a[1]).slice(0, 20)),
    gap: Object.fromEntries([...spacing.gap.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10))
  };
})()
```

#### エフェクトの抽出（影・角丸・ボーダー）

```javascript
(() => {
  const effects = { shadows: new Map(), radii: new Map(), borders: new Map() };
  document.querySelectorAll('*').forEach(el => {
    const style = getComputedStyle(el);
    if (style.boxShadow && style.boxShadow !== 'none') {
      effects.shadows.set(style.boxShadow, (effects.shadows.get(style.boxShadow) || 0) + 1);
    }
    if (style.borderRadius && style.borderRadius !== '0px') {
      effects.radii.set(style.borderRadius, (effects.radii.get(style.borderRadius) || 0) + 1);
    }
    const bw = style.borderWidth, bs = style.borderStyle;
    if (bw !== '0px' && bs !== 'none') {
      const border = `${bw} ${bs} ${style.borderColor}`;
      effects.borders.set(border, (effects.borders.get(border) || 0) + 1);
    }
  });
  return {
    shadows: Object.fromEntries([...effects.shadows.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10)),
    radii: Object.fromEntries([...effects.radii.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10)),
    borders: Object.fromEntries([...effects.borders.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10))
  };
})()
```

### 1-3.5. テーマ検出

Phase 1-3 の4つのJSスニペット実行完了後、以下のテーマ検出スニペットを browser_evaluate で実行する。

#### テーマ検出スニペット

```javascript
(() => {
  const result = {
    hasThemeSupport: false,
    detectedMethod: null,
    currentTheme: null,
    toggleElement: null
  };

  // 1. prefers-color-scheme メディアクエリの検出
  try {
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules) {
          if (rule instanceof CSSMediaRule &&
              rule.conditionText?.includes('prefers-color-scheme')) {
            result.hasThemeSupport = true;
            result.detectedMethod = 'media-query';
          }
        }
      } catch(e) {}
    }
  } catch(e) {}

  // 2. data-theme / class ベースの検出
  const html = document.documentElement;
  const dataTheme = html.getAttribute('data-theme') ||
                    html.getAttribute('data-color-mode') ||
                    html.getAttribute('data-color-scheme');
  if (dataTheme) {
    result.hasThemeSupport = true;
    result.detectedMethod = 'data-theme';
    result.currentTheme = dataTheme.includes('dark') ? 'dark' : 'light';
  } else if (html.classList.contains('dark') || document.body.classList.contains('dark')) {
    result.hasThemeSupport = true;
    result.detectedMethod = 'class';
    result.currentTheme = 'dark';
  } else if (html.classList.contains('light') || document.body.classList.contains('light')) {
    result.hasThemeSupport = true;
    result.detectedMethod = 'class';
    result.currentTheme = 'light';
  }

  // 3. 背景色の明度からテーマ推定（フォールバック）
  if (!result.currentTheme) {
    const bg = getComputedStyle(document.body).backgroundColor;
    const match = bg.match(/\d+/g);
    if (match) {
      const [r, g, b] = match.map(Number);
      const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
      result.currentTheme = luminance < 0.5 ? 'dark' : 'light';
    }
  }

  // 4. テーマ切替ボタンの検出
  const toggleSelectors = [
    '[aria-label*="theme" i]', '[aria-label*="dark" i]',
    '[aria-label*="light" i]', '[aria-label*="mode" i]',
    '[data-testid*="theme" i]',
    '.theme-toggle', '#theme-toggle',
    '[class*="theme-switch"]', '[class*="dark-mode"]',
    'button:has([class*="moon"])', 'button:has([class*="sun"])'
  ];
  for (const sel of toggleSelectors) {
    try {
      const el = document.querySelector(sel);
      if (el) {
        result.hasThemeSupport = true;
        result.toggleElement = sel;
        break;
      }
    } catch(e) {}
  }

  return result;
})()
```

#### 2回抽出フロー

テーマ検出結果で `hasThemeSupport: true` の場合:

1. 現在のテーマでの抽出結果を1回目として記録（Phase 1-3の結果がそのまま使われる）
2. テーマを切り替える:
   - `toggleElement` がある場合: `browser_click` でトグルボタンをクリック
   - `detectedMethod === 'data-theme'` の場合: `browser_evaluate` で属性値を変更
   - `detectedMethod === 'class'` の場合: `browser_evaluate` でクラスを切替
   - `detectedMethod === 'media-query'` のみの場合: 制限事項。Playwright MCPには `emulateMedia` 相当のツールがないため、サポート外とする。「media-queryベースのテーマ切替は自動抽出に非対応です」とレポートに記載する
3. `browser_wait_for` で遷移完了を待機（500ms）
4. Phase 1-3 の4つのJSスニペット（色・タイポグラフィ・スペーシング・エフェクト）を再実行（2回目の抽出）
5. 両方の結果をレポートに `### ライトモードトークン` / `### ダークモードトークン` として出力

テーマ未検出（`hasThemeSupport: false`）の場合:
- 1回のみの抽出結果を使用
- 背景色の明度から推定したテーマ名（light/dark）を記録
- tokens.jsonはテーマ分岐なし（フラット構造）で生成
- レポートに「テーマ切替は検出されませんでした。{推定テーマ名}モードとして抽出しました」と記載

### 1-4. エラーハンドリング

| エラー | 対処 |
|--------|------|
| Playwright MCP未接続 | 「Playwright MCPが接続されていません。`claude mcp add playwright -- npx @anthropic-ai/mcp-playwright` で追加してください」と案内 |
| URL到達不可（404/timeout） | 1回リトライ → 失敗時「URLにアクセスできません」と報告 |
| JS実行エラー（CSP等） | フォールバック: スクリーンショットのみで Phase 3 の定性分析に進む。「トークンの自動抽出ができないため、スクリーンショットベースで分析します」と通知 |
| SPA/動的レンダリング | browser_wait_for("networkidle") で対応。それでも表示されない場合はユーザーに待機時間を確認 |
| 認証が必要なページ | 「ログインが必要なページです。先にブラウザでログインしてから再実行してください」と案内 |

---

## Phase 2: Structure（構造化）

抽出した生データを3層トークン構造に整理する。

### 2-1. 色の分類

1. rgba値をHSLに変換
2. 分類ルール:
   - 彩度 < 10% → neutral（グレースケール）
   - 使用頻度が最も高い有彩色 → primary候補
   - primary候補と色相差150-210°の色 → secondary候補
   - 高彩度かつ使用頻度が低い色 → accent候補
   - 残り → additional
3. 各カテゴリを明度でスケール化（50, 100, 200, 300, 400, 500, 600, 700, 800, 900）

### 2-2. タイプスケール検出

1. font-sizeをpx値に正規化してソート
2. 隣接サイズ間の比率を計算
3. 最頻比率を既知スケールにマッチング（許容誤差 ±0.03）:
   - 1.067: Minor Second / 1.125: Major Second / 1.200: Minor Third
   - 1.250: Major Third / 1.333: Perfect Fourth / 1.414: Augmented Fourth
   - 1.500: Perfect Fifth / 1.618: Golden Ratio
4. マッチしない場合は「カスタムスケール（比率 {N}）」と記録

### 2-3. スペーシングスケール検出

1. 使用頻度上位のスペーシング値をpxに正規化
2. 値が8の倍数かどうかを判定 → 8pxグリッド準拠率を計算
3. 最大公約数を計算 → ベース単位を推定
4. ベース単位の倍数でスケール表を生成

### 2-4. 出力形式

各カテゴリを以下のテーブル形式で整理する:

```
### カラーパレット
| 役割 | トークン名 | 値 | 使用回数 | 用途 |
|------|----------|-----|---------|------|

### タイポグラフィ
| レベル | フォント | サイズ | ウェイト | 行間 | サンプルテキスト |
|--------|---------|--------|---------|------|----------------|

### スペーシング
| トークン名 | 値 | 使用回数 | 主な用途 |
|-----------|-----|---------|---------|

### エフェクト
| 種類 | 値 | 使用回数 |
|------|-----|---------|
```

#### テーマ対応時の出力

テーマが検出された場合、上記の各テーブルをライトモード・ダークモードそれぞれで出力する:

```
### ライトモードトークン

（上記と同じテーブル形式でライトモードの値を出力）

### ダークモードトークン

（上記と同じテーブル形式でダークモードの値を出力）
```

---

## Phase 3: Analyze（5軸分析）

[analysis-framework.md](analysis-framework.md) を読み込み、各軸で分析を実行する。

### 3-1. 定量分析

Phase 2 の構造化データを使って計算する:

| 項目 | 計算方法 |
|------|---------|
| タイプスケール比率 | Phase 2-2 で検出済み。既知スケール名を付与 |
| WCAGコントラスト比 | テキスト色/背景色のペアから相対輝度比を計算。4.5:1未満を問題として検出 |
| 8pxグリッド準拠率 | Phase 2-3 で計算済み |
| カラーハーモニー | primary-secondary間の色相差からハーモニー分類を判定 |
| 行間値 | line-height / font-size の比率。本文で1.4-1.6の範囲に収まるか |

### 3-2. 定性分析

Phase 1 のスクリーンショットを視覚的に判断する:

- 3秒テスト: 最初に目に入る要素は何か → ビジネス上最も重要な要素と一致するか
- ゲシュタルト原則: 近接・類似・図と地の活用度
- レイアウトパターン: ベントグリッド / 12カラム / 非対称 / その他
- ナビゲーション型: トップナビ / ハンバーガー / サイドナビ / メガメニュー
- CTA配置・強調度
- フック分析: Hookモデル4段階（トリガー → アクション → 報酬 → 投資）の特定

### 3-3. トレンド照合

[trends.md](trends.md) を読み込み、6領域で照合する:
1. レイアウト
2. タイポグラフィ
3. カラー
4. インタラクション・アニメーション
5. UIコンポーネント
6. デザインシステム

各領域について「トレンドに沿っている / 独自路線 / クラシック」を判定し、根拠を記述する。

---

## Phase 4: Report（レポート出力）

### 4-1. サイト名の推定

URLのドメイン名からサイト名を推定する。`https://stripe.com/jp` → `stripe`

### 4-2. レポート出力

出力先: `.claude/artifacts/dissect-{site-name}-{yyyyMMdd-HHmm}.md`（learnモード）
出力先: `.claude/artifacts/audit-{site-name}-{yyyyMMdd-HHmm}.md`（auditモード）

以下のフォーマットで出力する:

```markdown
# デザイン分析: {サイト名}

分析日: {yyyy-MM-dd}
URL: {対象URL}
モード: {learn / audit}
業界: {SaaS / EC / メディア / コーポレート / ポートフォリオ / その他}

## サイト概要

{サイトの目的・ターゲットユーザー・第一印象の1-3文サマリー}

## デザイントークン

テーマサポート: {あり（{検出方法}） / なし（{推定テーマ名}モードとして抽出）}

テーマサポートありの場合、カラーパレットとエフェクトのセクションをテーマごとに分けて出力:

### ライトモード カラーパレット
（テーブル）

### ダークモード カラーパレット
（テーブル）

### カラーパレット

| 役割 | トークン名 | 値 | 用途 |
|------|----------|-----|------|

カラーハーモニー: {補色 / 類似色 / トライアド / スプリット補色 / モノクロマティック}

### タイポグラフィ

| レベル | フォント | サイズ | ウェイト | 行間 |
|--------|---------|--------|---------|------|

タイプスケール: {比率名}（倍率 {N}）
フォントペアリング: {見出しフォント} + {本文フォント}（{調和 / 対比}）

### スペーシング

ベース単位: {N}px
8pxグリッド準拠率: {N}%
スケール: {値一覧}

### エフェクト

影: {shadow定義一覧}
角丸: {radius定義一覧}

## 5軸分析

### 1. 視覚原則

{ゲシュタルト原則の適用箇所を具体的に}
{視覚階層の構成（3秒テスト結果）}
{グリッドシステムの種類と整合性}

### 2. タイポグラフィ

{タイプスケールの評価}
{フォントペアリングの評価}
{可読性（行間・字間・1行文字数）}

### 3. 配色

{カラーハーモニーの評価}
{WCAGコントラスト比の結果}
{色の心理効果とブランドの適合性}

### 4. スペーシング

{8pxグリッド準拠度}
{余白のリズム}
{内部/外部スペーシングの関係}

### 5. UIパターン

{ナビゲーション型の分類と評価}
{CTA配置・強調度}
{フック分析（Hookモデルの4段階）}

## トレンド照合

| 領域 | 判定 | 根拠 |
|------|------|------|
| レイアウト | {トレンド/独自/クラシック} | {具体的な根拠} |
| タイポグラフィ | | |
| カラー | | |
| アニメーション | | |
| コンポーネント | | |
| デザインシステム | | |

## 学びのポイント

### このサイトから学べる普遍的テクニック
- {テクニック}: {なぜ効いているかの説明}

### このサイト固有の工夫
- {工夫}: {なぜこのサイトで効いているかの説明}

### 他のプロジェクトに応用できるパターン
- {パターン}: {どう応用するかの具体的な方法}
```

### 4-3. auditモード追加セクション

auditモードの場合、上記に加えて以下を出力する:

```markdown
## 問題点一覧

| # | 重大度 | 軸 | 問題 | 該当箇所 | 改善提案 |
|---|--------|-----|------|---------|---------|

重大度の基準:
- critical: アクセシビリティ違反（WCAG不適合）、重大なUX阻害
- warning: デザイン原則からの逸脱、一貫性の欠如
- info: 改善すれば良くなるが現状でも機能する

## 改善後デザイントークン案

| トークン | 現状値 | 改善案 | 変更理由 |
|---------|-------|-------|---------|

## 次のステップ（odin連携）

この監査結果をもとに改善を進める場合:
1. `odin-think-design` にこのファイルを渡して改善後のアーキテクチャを設計
2. `odin-think-plan` でタスク分解・実装計画を作成
3. `odin-do-implement` でTDDベースで実装
```

### 4-4. ナレッジインデックスの更新

分析完了後、`.claude/artifacts/design-knowledge-index.md` を更新する。

ファイルが存在しない場合は新規作成:

```markdown
# デザインナレッジインデックス

## 分析済みサイト一覧

| サイト名 | URL | 業界 | モード | 分析日 | レポートパス |
|---------|-----|------|-------|-------|-------------|
```

既存ファイルがある場合は行を追加する。

### 4-5. 完了報告

レポートのサマリーをユーザーに提示する:
- サイト名、業界、モード
- 5軸分析の要点（各軸1行）
- トレンド照合の総合判定
- learnモード: 「学びのポイント」のトップ3
- auditモード: critical/warningの問題数と最も重要な改善提案
- レポートファイルのパス
