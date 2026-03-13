# CLAUDE.md (dotfiles)

chezmoi管理のdotfilesリポジトリ。

## 構成

- `dot_config/` → `~/.config/` にデプロイ
- `dot_tmux.conf` → `~/.tmux.conf`
- `dot_gitconfig.tmpl` → `~/.gitconfig`（chezmoiテンプレート）
- `dot_claude/` → `~/.claude/` にデプロイ（ユーザーレベルClaude設定）
- `Dockerfile` → Docker検証環境（chezmoi管理対象外）

## ツール構成

Ghostty + tmux + Neovim + fish + starship + ghq + fzf + eza + bat + fd + rg

## 開発フロー

1. 設定ファイルを編集
2. `docker build -t dotfiles-test .` でビルド
3. `docker run --rm -it dotfiles-test` でコンテナ検証
4. 動作確認後コミット

## chezmoi テンプレート

- `.tmpl` 拡張子のファイルはchezmoiテンプレート
- `{{ if eq .chezmoi.os "darwin" }}` でmacOS/Linux分岐
- テンプレート変数: `.chezmoi.os`, `.chezmoi.arch`

## コーディング規約

- コメント・ドキュメント: 日本語
- コミットメッセージ: Conventional Commits形式（日本語）
- fish関数: `dot_config/fish/functions/` に1関数1ファイル

## 注意事項

- `~/.claude/` 内の動的ファイル（history.jsonl, projects/, todos/等）はchezmoi管理対象外
- `.chezmoiignore` でDockerfile, .claude/, .git/等を除外済み
- Neovimプラグインはlazy.nvimで管理（dot_config/nvim/lua/plugins/）
- このリポジトリはdotfilesリポジトリです。設定ファイルの内容を確認する際は、デプロイ先（`~/.claude/` や `~/.config/` など）ではなく、必ずこのリポジトリ内のファイル（`dot_claude/`、`dot_config/` など）を参照してください
