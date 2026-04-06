---
name: pr-coderabbit-fix
description: PRのCodeRabbitレビューコメントを取得・分析し、このPRで導入された問題のみを特定して修正する。「CodeRabbitの指摘を直して」「PRのレビューコメントを確認して」「CRの指摘を対応して」「コードレビューの修正をして」など、CodeRabbitやPRレビューへの対応が求められたときに使用する。PRのURLや番号が指定された場合もこのスキルを使う。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent, AskUserQuestion
---

CodeRabbitのレビュー指摘を取得し、PRで導入された問題のみを特定して修正するスキル。
既存コードの問題を巻き込まないよう、diffとの照合が重要になる。

## 1. PRの特定

PRの番号やURLが指定されていない場合は、現在のブランチからPRを探す。

```bash
# 現在のブランチ名を取得
git branch --show-current

# そのブランチのPRを探す
gh pr list --head <branch-name> --json number,title,url
```

PRが見つからない場合はユーザーに確認する。

## 2. CodeRabbitコメントの取得

3種類のコメントを並行して取得する。インラインコメントはGraphQL APIで未解決スレッドのみに絞り込む。

owner/repo は `gh repo view --json owner,name` で取得する。

### 2-1. インラインレビューコメント（未解決のみ）

REST APIにはスレッドの解決状態（resolved）が存在しないため、GraphQL APIを使う。
`isResolved == false` でフィルタし、解決済みコメントを除外する。

```bash
gh api graphql -f query='
{
  repository(owner: "{owner}", name: "{repo}") {
    pullRequest(number: {number}) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 10) {
            nodes {
              id
              body
              author { login }
            }
          }
        }
      }
    }
  }
}' --jq '
[
  .data.repository.pullRequest.reviewThreads.nodes[]
  | select(.isResolved == false)
  | select(.comments.nodes | any(.author.login | test("coderabbit")))
  | {
      threadId: .id,
      path: .path,
      line: .line,
      isOutdated: .isOutdated,
      comments: [.comments.nodes[] | {id: .id, body: .body, author: .author.login}]
    }
]'
```

注意: `isOutdated == true` のスレッドはコードが更新されて古くなった指摘。未解決でもoutdatedなら優先度を下げる。

### 2-2. issueコメント（PR全体のサマリー・ウォークスルー）

```bash
gh api repos/{owner}/{repo}/issues/{number}/comments \
  --jq '.[] | select(.user.login | test("coderabbit")) | {id, body}'
```

### 2-3. レビュー本文（Outside diff range の指摘を含む）

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --jq '.[] | select(.user.login | test("coderabbit")) | {id, state, body}'
```

## 3. コメントの分類と要約

取得したコメントを以下の観点で整理する:

- 重要度: Critical > Major > Minor > Nitpick
- 対象ファイルと行番号
- 指摘の要約（HTMLタグやMarkdown装飾を取り除いた簡潔な説明）
- CodeRabbitの提案差分があればその内容

"Outside diff range" とCodeRabbit自身が明記しているコメントは、この時点で「diff範囲外」とマークしておく。

## 4. diff照合による原因判定

各指摘について、PRのdiffと照合し「このPRで導入された問題か」を判定する。
これがこのスキルの最も重要なステップ。誤判定すると不要な修正をしてしまう。

```bash
# ベースブランチとの差分を取得
git diff <base-branch>...HEAD -- <file-path>
```

判定基準:
- このPRで新規作成されたファイルへの指摘 → このPRの問題
- このPRで変更した行への指摘 → このPRの問題
- diff範囲外（変更していない行）への指摘 → 既存の問題
- このPRで片方だけ修正して片方を見落とした場合 → 顕在化した既存問題（対応推奨）

## 5. インパクト分析

各指摘について、修正する価値を以下の観点で評価する。単にファイルと指摘を列挙するのではなく、「なぜ直すべきか（または直さなくてよいか）」をユーザーが判断できる情報を提供する。

分析観点:
- セキュリティリスク: 脆弱性につながるか（XSS、インジェクション、認証バイパス等）
- バグ発生確率: 本番で不具合を引き起こす可能性があるか
- パフォーマンス影響: レスポンスタイムやリソース消費に影響するか
- 保守性: 将来の変更時に問題を引き起こすか（可読性低下、密結合等）
- コードスタイル: 一貫性・規約違反レベルの指摘か

各指摘に対して以下を判定する:
- インパクトレベル: High（本番障害・セキュリティリスク）/ Medium（品質低下・将来の技術負債）/ Low（スタイル・好み）
- 修正コスト: 行数・影響範囲の概算
- 推奨: 修正する / 後回し（チケット化）/ 対応不要

影響範囲が不明な指摘は、コードを読んで呼び出し元・依存先を確認してから判定する。推測で判定しない。

## 6. 判定結果の報告

判定結果をカテゴリ別に表形式で報告する。各指摘にインパクトレベルと推奨アクションを付与する。

報告カテゴリ:
1. このPRで導入された問題（対応必須）
2. このPRで顕在化した既存の問題（対応推奨）
3. 既存の問題 / diff範囲外（スコープ外）

表の列: ファイル / 行 / 指摘概要 / インパクト / 修正コスト / 推奨

ユーザーにどの指摘を対応するか確認する。

## 7. 修正の実施

ユーザーが対応を承認したら、修正を行う。
修正はサブエージェントに委譲し、完了後に成果物を検証する。

修正時の注意:
- CodeRabbitの提案差分がある場合はそれをベースにする
- ただし提案をそのまま適用せず、コードの文脈を読んでから修正する
- 修正のスコープは指摘された箇所に限定し、周辺コードのリファクタリングはしない

## 8. コミット

修正が完了したら、コミットメッセージを作成してコミットする。
コミットする前にユーザーの承認を得る。

コミットメッセージの形式:
```
fix: CodeRabbitレビュー指摘への対応

- 修正1の説明
- 修正2の説明
```

## 9. pushの実行

コミット完了後、CodeRabbitが修正を確認できるようリモートにpushする。

```bash
git push
```

push後、CodeRabbitが新しいコミットに対してレビューを更新するのを待つ。

## 10. 対応済みコメントへの返信

push後、修正・コミットが完了した指摘に対して、CodeRabbitのレビューコメントに「修正しました」と返信する。

```bash
# インラインレビューコメントへの返信
gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies \
  -f body="修正しました"

# issueコメントへの返信（PR全体コメントの場合）
gh api repos/{owner}/{repo}/issues/{number}/comments \
  -f body="修正しました"
```

対応しなかった指摘（diff範囲外・スコープ外と判定したもの）には返信しない。
返信対象は、ステップ7で実際に修正を行ったコメントのみに限定する。
