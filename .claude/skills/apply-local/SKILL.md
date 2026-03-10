---
name: apply-local
description: dotfilesをローカルマシンに適用する
user-invocable: true
allowed-tools: Bash, Read, AskUserQuestion
---

# ローカル適用

dotfilesをローカルマシン（macOS）に適用します。

## 手順

1. `chezmoi diff` で変更差分を確認
2. ユーザーに差分を提示して確認を取る
3. 承認後 `chezmoi apply` で適用
4. 適用結果を検証

## 注意

- 必ず差分確認してからユーザーの承認を得ること
- `chezmoi apply --dry-run` で事前確認可能
