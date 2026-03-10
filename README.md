# dotfiles

chezmoi管理のdotfilesリポジトリ。macOS / Linux対応。

## ツール構成

| カテゴリ | ツール |
|---|---|
| ターミナル | Ghostty |
| マルチプレクサ | tmux |
| シェル | fish + starship |
| エディタ | Neovim |
| リポジトリ管理 | ghq + fzf |
| モダンCLI | eza, bat, fd, rg |
| キーバインド | Karabiner-Elements |
| AI | Claude Code |

## インストール

```sh
sh -c "$(curl -fsLS get.chezmoi.io)"
chezmoi init --apply yagrabit
```

## 設定の概要

### fish shell

- エイリアス: ls→eza, cat→bat, find→fd, grep→rg, vim→nvim（tool-if-exists方式）
- キーバインド: Ctrl+G Ctrl+G（ghqリポジトリ移動）、Ctrl+G Ctrl+R（ブランチ切替）、Ctrl+G Ctrl+M（リモートブランチ切替）
- プラグイン: fisher管理。fzf.fish, autopair.fish
- tmux自動起動: インタラクティブかつtmux未起動時に自動アタッチ（macOSではGhosttyクイックターミナル除外）
- zoxide, fzf, starship の初期化

### Neovim

- プラグイン管理: lazy.nvim
- リーダーキー: スペース
- 主要プラグイン: nvim-tree（ファイルツリー）、telescope.nvim（ファジーファインダー）、tokyonight.nvim（カラースキーム）
- 基本操作: `<leader>w`保存、`<leader>q`終了、`<leader>e`ファイルツリー、`<leader>ff`ファイル検索、`<leader>fg`文字列検索

### tmux

- プレフィックス: Ctrl+q
- ペイン移動: h/j/k/l（Vim風）
- ウィンドウ分割: | （横）、- （縦）
- コピーモード: viキーバインド
- プラグイン: tpm, tmux-fzf（Ctrl+fで検索）、tmux-rename-window-project
- ポップアップ: Prefix+g（tig）、Prefix+t（fzf）

### Git

- エイリアス: st, co, br, cm, df, pl, ps, lg（グラフ付きログ）
- pull時にrebaseを使用
- push時に上流ブランチを自動設定
- デフォルトブランチ: main

### Ghostty

- テーマ: tokyonight
- フォント: PlemolJP Console NF（14pt）
- 背景透過: 85%、ブラー有効

### Karabiner-Elements

- Ghostty内でCtrl+q押下時にIMEを英数モードへ自動切替
- tmuxプレフィックスキーが日本語入力中でも確実に動作

### Claude Code

- ユーザーレベルのCLAUDE.md、settings.json、カスタムスキルをchezmoi管理

## ディレクトリ構成

```
dot_config/
├── fish/           → ~/.config/fish/
│   ├── config.fish.tmpl
│   ├── fish_plugins
│   └── functions/
├── ghostty/        → ~/.config/ghostty/
├── karabiner/      → ~/.config/karabiner/
├── nvim/           → ~/.config/nvim/
│   ├── init.lua
│   └── lua/
│       ├── config/
│       └── plugins/
└── starship.toml   → ~/.config/starship.toml
dot_claude/          → ~/.claude/
dot_gitconfig.tmpl   → ~/.gitconfig
dot_tmux.conf        → ~/.tmux.conf
```

## Docker検証

Ubuntu 24.04ベースのDockerコンテナでchezmoiの適用結果を検証できる。

コンテナに含まれるツール: fish, git, fzf, eza, bat, fd, rg, tmux, neovim, chezmoi, starship

```sh
docker build -t dotfiles-test .
docker run --rm -it dotfiles-test
```

動作確認の例:

- fishシェルが起動し、starshipプロンプトが表示される
- `chezmoi diff` で差分がないことを確認
- nvim が正常起動する
- eza, bat, fd, rg 等のエイリアスが動作する
- tmux が起動しVim風キーバインドが使える

## macOS / Linux の差異

| 項目 | macOS | Linux |
|---|---|---|
| PATH | /opt/homebrew/bin を追加 | 追加なし |
| Git user | tairano | test（テスト用） |
| コマンド名 | bat, fd | batcat, fdfind（エイリアスで吸収済み） |
| tmux自動起動 | Ghosttyクイックターミナル内で無効化 | 常に有効 |
