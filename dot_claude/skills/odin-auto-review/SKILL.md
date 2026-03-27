---
name: odin-auto-review
description: 多角的セルフレビュー自動実行。code-reviewer + security-reviewerを並列起動し、結果を統合して報告する。odin司令塔から実装完了後に自動呼び出し、または単体で「レビューして」で起動。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Agent
---

# odin-auto-review

実装完了後に多角的なセルフレビューを自動実行する補助スキル。
odin司令塔から呼び出される他、単体でも使用可能。

## 1. レビュー対象の特定

1. git diffでレビュー対象の変更を取得する:
   - ベースブランチとの差分: `git diff $(git merge-base HEAD main)..HEAD`
   - ベースブランチがmain以外の場合はAskUserQuestionで確認する
2. 変更ファイル一覧を取得する:
   - `git diff --name-only $(git merge-base HEAD main)..HEAD`

## 2. 並列レビュー実行

以下の4つのレビューを1回のレスポンスで同時起動する:

1. Agentツールで code-reviewer サブエージェントタイプを起動（model: sonnet）
   - 変更差分を渡し、品質・保守性の観点でレビューを依頼する
2. Agentツールで security-reviewer サブエージェントタイプを起動（model: sonnet）
   - 変更差分を渡し、OWASP Top 10ベースでセキュリティレビューを依頼する
3. Skillツールで `simplify` を実行
   - 変更コードの再利用性・効率性をチェックする
4. Agentツールで `coderabbit:code-reviewer` サブエージェントを起動
   - プラグイン未インストールの場合はスキップする

全レビューの完了を待つ。

## 3. 結果統合と報告

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
