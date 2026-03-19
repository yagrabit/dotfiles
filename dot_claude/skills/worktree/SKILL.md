---
name: worktree
description: コード変更を伴う作業（実装、リファクタ、バグ修正、設定変更など）を開始する前に必ず参照すること。ファイルの編集、新規作成、削除を伴うタスクではworktreeで作業する。package.json変更時の依存関係再インストール手順も提供する。コードを書き換える、修正する、追加する、リネームする、削除する、といったタスクでは常にこのスキルを使用すること。
user-invocable: true
---

# Worktree運用ガイド

人間の開発者がメインworktreeで開発しているため、Claude Codeの変更がメインworktreeのファイルや状態に干渉することを防ぐ必要がある。
コード変更を伴う作業は、必ず新規worktreeで実施すること。

## worktreeで作業すべきケース

コード変更を伴う作業（実装、リファクタ、修正など）は新規worktreeで実施する。

- 対話的に作業する場合: EnterWorktreeで新規worktreeを作成する
- subagentに実装を委譲する場合: Agent(isolation: "worktree")を使用する

## メインworktreeで作業して良いケース

以下のようなコード変更を伴わない作業は、メインworktreeで直接実施してよい。

- 調査・分析（コードリーディング、依存関係の調査など）
- ドキュメント作成・レビュー
- コード分析・レポート作成
- git logやgit diffの確認

## 依存関係の管理

worktree作成時、以下のディレクトリは元リポジトリから自動的にsymlinkされる（settings.jsonのworktree.symlinkDirectories設定による）:

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
