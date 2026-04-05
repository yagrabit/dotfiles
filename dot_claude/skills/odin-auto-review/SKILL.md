---
name: odin-auto-review
description: code-reviewer・security-reviewerを並列起動し、品質とセキュリティの多角的セルフレビュー結果を統合して報告する。全実装完了後にPostToolUseフックが自動リマインドするほか、「レビューして」「セルフレビューして」で単体起動。
user-invocable: false
allowed-tools: Bash, Read, Grep, Glob, Agent, Skill, AskUserQuestion
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

## 独立評価の原則（コンテキスト隔離）

Anthropic公式: "separating the agent doing the work from the agent judging it proves to be a strong lever"
VCSDDのAdversary設計: 毎回フレッシュコンテキスト（会話履歴ゼロ）で起動し、成果物のみで判定する。

- code-reviewerとsecurity-reviewerは必ず新しいAgentツールで起動する（同一コンテキストで実行しない）
- レビューエージェントには変更差分のみを渡す。実装時の意図・経緯・会話履歴は渡さない（肯定バイアス防止）
- レビュー結果は「実装者の意図」ではなく「コードの品質」のみで判断する
- 渡してよい情報: git diff出力、変更ファイル一覧、CLAUDE.mdのコーディング規約
- 渡してはいけない情報: 設計判断の経緯、ユーザーとの会話、意図説明

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

以下の5つのレビューを1回のレスポンスで同時起動する:

1. Agentツールで code-reviewer サブエージェントタイプを起動（model: sonnet）
   - 変更差分を渡し、品質・保守性の観点でレビューを依頼する
   - AIスロップ検出（以下の3分類を明示的にチェックするよう指示する）:
     - 構造的スロップ: 使われない抽象化、不要なインターフェース設計、過剰なデザインパターン適用、実際には呼ばれないヘルパー関数
     - ロジックスロップ: ハッピーパスのみの対応、バリデーションが浅い、エッジケース未考慮、エラーハンドリングが形式的
     - テストスロップ: 実装をそのままコピーしたミラーテスト、アサーションが形式的、モックだらけで実際の動作を検証していないテスト
   - AIスロップが検出された場合は「重大」に分類する
2. Agentツールで security-reviewer サブエージェントタイプを起動（model: sonnet）
   - 変更差分を渡し、OWASP Top 10ベースでセキュリティレビューを依頼する
3. Skillツールで `simplify` を実行
   - 変更コードの再利用性・効率性をチェックする
4. Agentツールで subagent_type に "coderabbit:code-reviewer" を指定して起動する
   - 存在チェック（Codexとは独立）: system-reminderのスキル一覧に `coderabbit:` プレフィックスのスキルが存在するか確認する
   - 存在しない場合のみスキップ。この判定はCodexの存在有無に影響されない

5. Bashツールで Codex レビューを直接実行する（サブエージェント不要）
   - codex-companion.mjsは別プロセスで動作するため、コンテキスト隔離は維持される
   - 存在チェックと実行を1つのBashコマンドで行う:
     ```bash
     CODEX_ROOT=$(jq -r '.plugins["codex@openai-codex"][0].installPath // empty' ~/.claude/plugins/installed_plugins.json 2>/dev/null)
     if [ -n "$CODEX_ROOT" ] && [ -f "$CODEX_ROOT/scripts/codex-companion.mjs" ]; then
       node "$CODEX_ROOT/scripts/codex-companion.mjs" review --base main --wait
     else
       echo "[codex] Codexプラグインが未インストールのためスキップ"
     fi
     ```
   - 他の4レビューのAgent起動と同じレスポンスでBashを呼び出し、並列実行する
   - この判定はCodeRabbitの存在有無に影響されない

全レビューの完了を待つ。

#### 完了チェックポイント（ステップ2）

- 5つのレビュー（code-reviewer, security-reviewer, simplify, coderabbit, codex）が実行されていること
- coderabbit・codexがスキップされた場合、残りのレビューが実行されていること

> superpowersプラグインが未インストールの場合: simplifyスキルをスキップし、残りのレビューで実行する。

## ステップ3: 結果統合と報告

レビュー結果を以下の形式で統合して報告する:

```
## レビュー結果サマリー

### 重大な問題（即座に修正が必要）
- F-001 [security] SQLインジェクションの可能性: src/api/users.ts:42
  routeToSkill: do-implement
- F-002 [quality] 未使用のimport: src/components/Header.tsx:3
  routeToSkill: do-implement

### 改善提案（推奨）
- F-003 [quality] 関数の分割を推奨: src/utils/validate.ts:15-45
  routeToSkill: do-refactor
- F-004 [simplify] 重複コードの共通化: src/hooks/useAuth.ts
  routeToSkill: do-refactor

### 情報（参考）
- [security] 依存パッケージのバージョン確認推奨
```

Finding ID規約:
- 形式: `F-{NNN}`（3桁ゼロ埋め、レビューセッション内で連番。重大・改善の全指摘に付与。情報レベルは不要）
- routeToSkillで差し戻し先スキルを明示する。判定基準はexecution-loop.md § 5-3.7の正本を参照
- odinにエスカレーション時、routeToSkillを伝達することで自動修正ルーティングを可能にする

問題の優先度で分類する:
- 重大: セキュリティ脆弱性、バグ、データ損失リスク、AIスロップ
- 改善: コード品質、保守性、パフォーマンス
- 情報: スタイル、ベストプラクティス

### レビュー完了フラグの記録

pre-push-review-gateフックと連携するため、レビュー完了フラグを作成する。
フィーチャーブランチ上でレビューを実施した場合のみ実行する。

```bash
# レビュー完了フラグを作成（push前のゲートチェック用）
mkdir -p /tmp/claude-sessions
date +%s > "/tmp/claude-sessions/review-passed-$(git branch --show-current | tr '/' '-')"
```

mainブランチの場合はスキップする。

#### 完了チェックポイント（ステップ3）

- レビュー結果が重大/改善/情報の3段階で分類されていること
- 重複する指摘が統合されていること
- 結果サマリーが出力されていること

## Examples

### Example 1: odinから自動呼び出し（実装完了後）

ユーザー: （odinがdo-implement完了後に自動呼び出し）

```
ステップ1: レビュー対象特定
  odinコンテキストから変更差分を取得
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
  → odinに返却（重大な問題なし、続行可能）
```

### Example 2: ユーザー手動起動（セルフレビュー）

ユーザー: 「セルフレビューして」

```
ステップ1: レビュー対象特定
  git diff main..HEAD → 3ファイル変更（認証機能の修正）

ステップ2: 並列レビュー実行
  code-reviewer → 品質指摘1件（エラーハンドリング不足）
  security-reviewer → 重大指摘1件（トークン検証の不備）
  simplify → 指摘なし
  coderabbit → レビュー完了、指摘2件

ステップ3: 結果統合
  重大な問題: 1件 [security] トークン有効期限の検証漏れ: src/auth/verify.ts:28
  改善提案: 2件（エラーハンドリング追加、型定義の厳密化）
  情報: 1件（テストカバレッジ確認推奨）
```
