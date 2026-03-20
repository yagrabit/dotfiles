---
name: worktree
description: PRレビュー用worktreeの作成や、新機能追加・大規模リファクタなどブランチを切るべき大規模な実装作業で使用する。小規模な修正や設定変更では使用不要。
user-invocable: true
---

# Worktree運用ガイド

人間の開発者がメインworktreeで開発しているため、Claude Codeの変更がメインworktreeのファイルや状態に干渉することを防ぐ必要がある。
大規模な実装作業は新規worktreeで実施し、小規模な修正はメインworktreeで直接作業してよい。

## worktreeで作業すべきケース

大規模な実装作業（新機能追加、大規模リファクタなど、明確にブランチを切るべき作業）は新規worktreeで実施する。
小規模な修正（バグ修正、設定変更、軽微な編集など）はworktree不要。メインworktreeで直接作業してよい。

- 対話的に作業する場合: EnterWorktreeで新規worktreeを作成する
- subagentに実装を委譲する場合: Agent(isolation: "worktree")を使用する

## メインworktreeで作業して良いケース

以下の作業は、メインworktreeで直接実施してよい。

- 調査・分析（コードリーディング、依存関係の調査など）
- ドキュメント作成・レビュー
- コード分析・レポート作成
- git logやgit diffの確認
- 小規模な修正（バグ修正、設定変更、軽微なコード修正など）

## worktree完了後のフロー

worktreeでの作業が完了したら、以下の手順を必ず実行すること。

### 1. 差分の確認

作業内容をユーザーに提示するため、以下のコマンドで差分を表示する:

```bash
git log main..HEAD --oneline
git diff main...HEAD --stat
```

### 2. マージ方針の確認

AskUserQuestionを使い、以下の4択でユーザーにマージ方針を確認する:

1. PRを作成する - 仕事の実装やレビューが必要な変更向け
2. メインにマージする - 軽微な修正で、レビュー不要な場合
3. レポートのみ出力する - レビュー・調査目的。差分は破棄する
4. そのまま保持する - 後で継続作業する場合

### 3. 選択に応じた実行

- PRを作成する: `gh pr create` でPRを作成し、URLをユーザーに共有する
- メインにマージする: mainブランチにマージし、worktreeをクリーンアップする
- レポートのみ: 分析結果をユーザーに報告し、worktreeをクリーンアップする（変更は破棄）
- そのまま保持: worktreeのパスをユーザーに伝え、後続作業に備える

## subagentへの委譲時の注意

subagent（Agent(isolation: "worktree")）に作業を委譲する場合、以下を厳守すること。

### subagentへの指示に含めるべき内容

- 「コミットまで行い、マージやpushは行わないこと」を必ず明記する
- 作業完了後はコミットログと変更概要を報告させる

### subagent完了後のオーケストレーターの責務

1. subagentの成果物（差分・コミットログ）を確認する
2. 品質に問題がないか検証する
3. 上記「worktree完了後のフロー」に従い、ユーザーにマージ方針を確認する

オーケストレーターが独自判断でマージやpushを行ってはならない。

## 依存関係の管理

worktree作成時、以下のディレクトリは元リポジトリから自動的にsymlinkされる（settings.jsonのworktree.symlinkDirectories設定による）:

- .claude（プロジェクトレベルのスキル・設定を共有）
- node_modules
- .next
- dist
- .turbo
- .nuxt
- .output
- .vite
- build
- .svelte-kit
- .parcel-cache

### .claude symlinkの効果

- プロジェクトレベルのスキル・settings.jsonがworktreeでも利用可能になる
- Claude設定がないブランチのレビュー時もスキルが動作する
- worktree側での`.claude/`への変更はメインに即反映される（symlinkのため）

### package.jsonを変更した場合

package.jsonを変更した場合（パッケージの追加・削除・更新など）、symlinkのままだとメインworktreeのnode_modulesを破壊する。以下の手順を実行すること:

1. `rm node_modules` でsymlinkを削除する
2. `ni` コマンドで依存関係をインストールする

niはパッケージマネージャーを自動検出するツール（npm/yarn/pnpm/bunを判別してくれる）。

## PRレビュー用worktreeの作成

引数としてPRのURLまたはPR番号が渡された場合、そのPRのブランチでworktreeを作成する。

以下のスクリプトを実行すること:
```
bash ${CLAUDE_SKILL_DIR}/scripts/create-pr-worktree.sh <PR URLまたはPR番号>
```

スクリプトは以下を自動的に行う:
- PRのブランチ名を取得（gh pr view）
- リモートからブランチをfetch
- worktreeを作成（メインworktreeのブランチは変更されない）

作成されたworktreeのパスが標準出力に出力されるので、そのディレクトリに移動して作業を開始すること。

## 注意事項

- worktreeでの開発サーバー起動は不要（起動しない）
- worktreeから直接メインworktreeのファイルを参照・変更しない
- worktree完了後、ユーザーの承認なくメインブランチへマージしない
- Agent(isolation: "worktree")の完了後も、マージ方針は必ずユーザーに確認する
