---
name: odin-auto-review
description: code-reviewer・security-reviewerを並列起動し、品質とセキュリティの多角的セルフレビュー結果を統合して報告する。odin司令塔から実装完了後に自動呼び出されるほか、「レビューして」「セルフレビューして」で単体起動。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Agent, AskUserQuestion
---

# odin-auto-review

実装完了後に多角的なセルフレビューを自動実行する補助スキル。
odin司令塔から呼び出される他、単体でも使用可能。

## talk-reviewとの違い

- auto-review: do系スキル完了後にodinから自動呼び出しされる軽量版。変更差分に対して定型的な品質・セキュリティチェックを実行し、結果をチャットに出力するのみ
- talk-review: ユーザーが明示的に「レビューして」と依頼した場合の詳細版。対話的なフィードバック、改善提案、修正の実施まで含む

## コンテキスト検出

### odinコンテキストがある場合（$ARGUMENTSにodin_contextが含まれる場合）
- odinから自動呼び出しされている
- レビュー対象の変更差分はodinコンテキストから把握する
- 結果をodinに返却し、重大な問題がある場合はodinにエスカレーションする

### odinコンテキストがない場合（ユーザー直接呼び出し）
- ステップ1からレビュー対象を自動検出する

## ステップ1: レビュー対象の特定

1. git diffでレビュー対象の変更を取得する:
   - ベースブランチとの差分: `git diff $(git merge-base HEAD main)..HEAD`
   - ベースブランチがmain以外の場合はAskUserQuestionで確認する
2. 変更ファイル一覧を取得する:
   - `git diff --name-only $(git merge-base HEAD main)..HEAD`

#### 完了チェックポイント（ステップ1）

- レビュー対象の変更差分が取得できていること
- 変更ファイル一覧が把握できていること

## ステップ2: 並列レビュー実行

以下の4つのレビューを1回のレスポンスで同時起動する:

1. Agentツールで code-reviewer サブエージェントタイプを起動（model: sonnet）
   - 変更差分を渡し、品質・保守性の観点でレビューを依頼する
2. Agentツールで security-reviewer サブエージェントタイプを起動（model: sonnet）
   - 変更差分を渡し、OWASP Top 10ベースでセキュリティレビューを依頼する
3. Skillツールで `simplify` を実行
   - 変更コードの再利用性・効率性をチェックする
4. Agentツールで subagent_type に "coderabbit:code-reviewer" を指定して起動する
   - プラグイン未インストールの場合はスキップする

全レビューの完了を待つ。

#### 完了チェックポイント（ステップ2）

- 4つのレビュー（code-reviewer, security-reviewer, simplify, coderabbit）が実行されていること
- coderabbitがスキップされた場合、残り3つが実行されていること

> superpowersプラグインが未インストールの場合: simplifyスキルをスキップし、残りの2-3レビューで実行する。

## ステップ3: 結果統合と報告

レビュー結果を以下の形式で統合して報告する:

```
## レビュー結果サマリー

### 重大な問題（即座に修正が必要）
- [security] SQLインジェクションの可能性: src/api/users.ts:42
- [quality] 未使用のimport: src/components/Header.tsx:3

### 改善提案（推奨）
- [quality] 関数の分割を推奨: src/utils/validate.ts:15-45
- [simplify] 重複コードの共通化: src/hooks/useAuth.ts

### 情報（参考）
- [security] 依存パッケージのバージョン確認推奨
```

問題の優先度で分類する:
- 重大: セキュリティ脆弱性、バグ、データ損失リスク
- 改善: コード品質、保守性、パフォーマンス
- 情報: スタイル、ベストプラクティス

#### 完了チェックポイント（ステップ3）

- レビュー結果が重大/改善/情報の3段階で分類されていること
- 重複する指摘が統合されていること
- 結果サマリーが出力されていること

## Examples

### 実装完了後の自動レビュー

```
ステップ1: レビュー対象特定
  git diff main..HEAD → 5ファイル変更

ステップ2: 並列レビュー実行
  code-reviewer → 品質指摘2件
  security-reviewer → 指摘0件
  simplify → 改善提案1件
  coderabbit → スキップ（未インストール）

ステップ3: 結果統合
  重大な問題: 0件
  改善提案: 3件（関数分割推奨、重複コード、未使用import）
  情報: 0件
```
