---
name: pr-5-coderabbit-fix
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

3つのAPIエンドポイントから並行してコメントを取得する。CodeRabbitのユーザー名は `coderabbitai` でフィルタする。

```bash
# インラインレビューコメント（ファイルの特定行に対する指摘）
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  --jq '.[] | select(.user.login | test("coderabbit")) | {id, path, line, body}'

# issueコメント（PR全体に対するサマリーやウォークスルー）
gh api repos/{owner}/{repo}/issues/{number}/comments \
  --jq '.[] | select(.user.login | test("coderabbit")) | {id, body}'

# レビューコメント（レビュー本文、Outside diff range の指摘を含む）
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --jq '.[] | select(.user.login | test("coderabbit")) | {id, state, body}'
```

owner/repo は `gh repo view --json owner,name` で取得できる。

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

## 5. 判定結果の報告

判定結果をカテゴリ別に表形式で報告する:

1. このPRで導入された問題（対応必須）
2. このPRで顕在化した既存の問題（対応推奨）
3. 既存の問題 / diff範囲外（スコープ外）

ユーザーにどの指摘を対応するか確認する。

## 6. 修正の実施

ユーザーが対応を承認したら、修正を行う。
修正はサブエージェントに委譲し、完了後に成果物を検証する。

修正時の注意:
- CodeRabbitの提案差分がある場合はそれをベースにする
- ただし提案をそのまま適用せず、コードの文脈を読んでから修正する
- 修正のスコープは指摘された箇所に限定し、周辺コードのリファクタリングはしない

## 7. コミット

修正が完了したら、コミットメッセージを作成してコミットする。
コミットする前にユーザーの承認を得る。

コミットメッセージの形式:
```
fix: CodeRabbitレビュー指摘への対応

- 修正1の説明
- 修正2の説明
```
