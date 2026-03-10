---
name: add-tool
description: 新しいツールの設定をdotfilesに追加する
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
---

# ツール設定追加

新しいツールの設定をdotfilesに追加します。

## 手順

1. $ARGUMENTS で指定されたツールの設定ファイルを調査
2. 既存設定（dot_config/等）との整合性を確認
3. 設定ファイルを作成（chezmoi形式: dot_プレフィックス）
4. 必要に応じてconfig.fish.tmplにエイリアスや初期化を追加
5. Dockerコンテナで動作検証
6. .chezmoiignoreの更新が必要か確認
