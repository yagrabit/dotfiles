---
name: odin-think-research
description: コードベース・技術調査。odinワークフローのthinkフェーズとして、既存プロジェクトの構造・実装パターン・テスト基盤を多角的に調査しレポートを出力する。「コードベースを調査して」「プロジェクト構成を把握して」「既存コードを分析して」などで起動。odinから自動起動される場合もある。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Agent, Write, AskUserQuestion
---

# odin-think-research

コードベース・技術調査スキル。odin司令塔のthinkフェーズで使用する。
既存プロジェクトの構造・実装パターン・テスト基盤を調査し、後続の設計・実装に必要な情報をレポートにまとめる。

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

### コンテキスト検出

$ARGUMENTS を確認し、odinコンテキストJSONが含まれているか判定する。

odinコンテキストJSONの例:
```json
{
  "odin_context": {
    "task": "通知機能の追加",
    "target_area": "src/components/notification",
    "focus": ["既存の類似実装", "テストパターン"],
    "artifacts": {}
  }
}
```

- odinコンテキストがある場合: そこから調査目的・対象を読み取り、ステップ1をスキップしてステップ2に進む
- odinコンテキストがない場合: ステップ1からAskUserQuestionで確認する

### ステップ1: 調査目的の確認

AskUserQuestionで以下を確認する:

1. 調査の目的（追加/変更したい機能の概要）
2. 特に知りたいこと（既存の類似機能、技術的制約、テストパターン等）
3. 対象ディレクトリの絞り込み（あれば）

$ARGUMENTSに情報が含まれている場合はそれを使用し、不足分のみ質問する。

#### 完了チェックポイント（ステップ1）

- 調査目的が明確であること
- 対象機能の概要を把握していること

### ステップ2: Exploreエージェント3並列調査

以下を Explore エージェント（最大3並列）に委譲して調査する:

エージェント1: プロジェクト構造
- package.json（依存関係、scripts）
- tsconfig.json（TypeScript設定）
- ディレクトリ構成（src/, app/, components/, lib/, utils/ 等）
- フレームワーク判定（Next.js App Router/Pages Router, React, Vue等）
- パッケージマネージャ（pnpm, npm, yarn）
- リンター・フォーマッター設定（oxlint, eslint, prettier等）
- ビルドツール（vite, webpack, turbopack等）

エージェント2: 対象領域の既存実装
- ステップ1で確認した機能に関連する既存コード
- 同種の画面/コンポーネント/API/ロジックの実装パターン
- 共有コンポーネント・ユーティリティの把握
- 状態管理パターン（useState, zustand, jotai, Redux等）
- データフェッチパターン（fetch, React Query, SWR等）
- 命名規約（ファイル名、関数名、型名の慣習）
- エラーハンドリングパターン

エージェント3: テスト・品質基盤
- テストフレームワーク（vitest, jest, playwright等）
- テストファイルの配置パターン（__tests__/, *.test.ts, *.spec.ts）
- テストの書き方の慣習（モック方法、テストユーティリティ、setup/teardown）
- E2Eテスト環境（playwright, cypress等）
- CI/CD設定（.github/workflows/ 等）
- コードカバレッジ設定

#### 完了チェックポイント（ステップ2）

- 3つのエージェントの調査結果が全て揃っていること
- 技術スタック、ディレクトリ構成、関連既存コード、テストパターンが判明していること
- 不明点がある場合は「不明」と記録し、先に進む

### ステップ3: 調査レポートの出力

1. `.claude/artifacts/` ディレクトリが存在しなければ作成する
2. 現在時刻を取得し、`yyyyMMdd-HHmm` 形式のタイムスタンプを生成する
3. 以下のフォーマットで調査レポートを出力する（先頭にodin_coherence frontmatterを付与する）

出力先: `.claude/artifacts/research-{yyyyMMdd-HHmm}.md`

```
---
odin_coherence:
  id: "research-{yyyyMMdd-HHmm}"
  kind: "research"
  depends_on: []
  updated: "{yyyy-MM-ddTHH:mm}"
---

# コードベース調査レポート

調査日: {yyyy-MM-dd HH:mm}
対象機能: {機能の概要}

## 技術スタック

- フレームワーク: {Next.js 14 App Router 等}
- 言語: {TypeScript 等}
- パッケージマネージャ: {pnpm 等}
- テスト: {vitest 等}
- リンター: {oxlint / eslint 等}
- ビルドツール: {vite 等}

## ディレクトリ構成

{主要なディレクトリとその役割}

## 関連する既存実装

{対象機能に近い既存コードのパス・概要・実装パターン}

## 命名規約・コーディングパターン

{既存コードから読み取れるファイル名・関数名・型名の慣習}

## テストパターン

{テストの配置・書き方・モック方法の慣習}

## 依存関係・共有コンポーネント

{再利用すべき既存コンポーネント・ユーティリティ・ライブラリ}

## 設計への示唆

{後続の設計フェーズで考慮すべき点・注意点・制約}
```

4. レポートの要約をユーザーに提示する
5. odinから呼ばれた場合は、出力ファイルパスをodinに返す

#### 完了チェックポイント（ステップ3）

- `.claude/artifacts/research-*.md` が出力されていること
- 全セクションが埋まっていること（該当なしの場合は「該当なし」と明記）
- 設計への示唆セクションに具体的な内容が記載されていること

## Examples

### 既存Next.jsプロジェクトに通知機能を追加する場合

ユーザー: 「通知機能を追加したいのでコードベースを調査して」

```
ステップ1: 調査目的の確認
  機能概要: リアルタイム通知（ベル通知 + メール通知）
  特に知りたいこと: WebSocket/SSEの既存実装、メール送信基盤の有無
  対象ディレクトリ: 特に指定なし

ステップ2: エージェント3並列調査
  [エージェント1] Next.js 14 App Router, pnpm, TypeScript, oxlint, vite
  [エージェント2] 既存のWebSocket実装なし、メール送信はResend利用、
                 類似UI: src/components/dropdown/ のドロップダウンメニュー
  [エージェント3] vitest + @testing-library/react, __tests__/ 配置,
                 MSWでAPIモック

ステップ3: レポート出力
  → .claude/artifacts/research-20260320-1430.md
```
