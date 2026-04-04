---
name: update-readme
description: 設定変更に応じてREADME.mdを更新する
user-invocable: true
allowed-tools: Read, Edit, Bash, Grep, Glob, Agent
---

# README.md 更新

設定ファイルの変更内容に基づいて、README.mdの記述を実態に合わせて更新します。

## 1. 変更の把握

以下のコマンドで変更されたファイルを特定する:

```sh
git diff HEAD --name-only
git diff --cached --name-only
git status --short
```

変更がない場合は「変更が検出されませんでした」と報告して終了する。

## 2. 対応セクションの特定

変更されたファイルパスから、更新が必要なREADMEセクションを特定する。

| READMEセクション | 対応ファイル |
|---|---|
| ツール構成 | 全体（新ツール追加時） |
| fish shell | dot_config/fish/** |
| Neovim | dot_config/nvim/** |
| tmux | dot_tmux.conf |
| Git | dot_gitconfig.tmpl |
| Ghostty | dot_config/ghostty/** |
| Claude Code | dot_claude/** |
| ディレクトリ構成 | ルート直下のファイル追加/削除、dot_config/直下の変更 |
| Docker検証 | Dockerfile |
| macOS / Linux の差異 | .tmplファイルの条件分岐変更 |

該当セクションがない場合は「README更新不要です」と報告して終了する。

## 3. 現状の確認と比較

- README.mdの現在の内容を読み込む
- 変更された設定ファイルの実際の内容を読み込む
- READMEの記述と実態を比較し、乖離がある箇所を特定する

乖離の例:
- 新しいエイリアスやキーバインドが追加されたがREADMEに記載がない
- プラグインが追加/削除されたがREADMEに反映されていない
- 設定値（フォント、テーマ等）が変更されたがREADMEが古い値のまま
- ディレクトリ構成が変わったがツリー表示が古い

## 4. README.mdの更新

乖離がある場合、Editツールで該当セクションのみ更新する。

記述ルール:
- 日本語で記述する
- 太字を使わない
- シンプルで簡潔に書く
- コードブロックはコマンド例とツリー表示のみに使う
- 絵文字を使わない
- 既存のREADMEのフォーマットやスタイルに合わせる

## 5. 結果の報告

更新した場合:
- 変更したセクション名と更新内容の概要を報告する

更新不要の場合:
- 「README更新不要です」と報告する
