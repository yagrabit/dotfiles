---
name: docker-test
description: Dockerコンテナでdotfilesの動作検証を行う
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Docker検証

dotfilesの変更をDockerコンテナ内で検証します。

## 手順

1. `docker build -t dotfiles-test .` でイメージをビルド
2. `docker run --rm dotfiles-test -c '<検証コマンド>'` で動作確認
3. 結果を報告

$ARGUMENTS が指定された場合、その項目を重点的に検証します。
