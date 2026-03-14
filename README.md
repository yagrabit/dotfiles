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
chezmoi init --apply <github-username>
```

## 設定の概要

### fish shell

- エイリアス: ls→eza, cat→bat, find→fd, grep→rg, vim→nvim（tool-if-exists方式）
- キーバインド: Ctrl+G Ctrl+G（ghqリポジトリ移動）、Ctrl+G Ctrl+R（ブランチ切替）、Ctrl+G Ctrl+M（リモートブランチ切替）、Ctrl+G Ctrl+S（stash管理）
- プラグイン: fisher管理。fzf.fish, autopair.fish
- tmux自動起動: インタラクティブかつtmux未起動時に自動アタッチ（macOSではGhosttyクイックターミナル除外）
- zoxide, fzf, starship の初期化
- cd後に自動でeza表示
- ghq管理下リポジトリの一括pull関数（ghq_pull_all）
- git stash管理: fzfでstash一覧を差分プレビュー付き表示し、apply/pop/drop/ファイル選択checkoutを操作（fstash）

### Neovim

- プラグイン管理: lazy.nvim
- リーダーキー: スペース
- 主要プラグイン: nvim-tree（ファイルツリー）、telescope.nvim（ファジーファインダー）、tokyonight.nvim（カラースキーム）、oil.nvim（バッファ型ファイラー）、sidekick.nvim（Claude Code連携）
- 基本操作: `<leader>w`保存、`<leader>q`終了、`<leader>e`ファイルツリー、`<leader>ff`ファイル検索、`<leader>fg`文字列検索

### tmux

- プレフィックス: Ctrl+q
- ペイン移動: h/j/k/l（Vim風）
- ウィンドウ分割: | （横）、- （縦）
- テンプレート付きウィンドウ作成: Prefix+C（上下50%、左上70%右上30%の3ペインレイアウト）
- コピーモード: viキーバインド
- プラグイン: tpm, tmux-fzf（Ctrl+fで検索）、tmux-rename-window-project
- ポップアップ: Prefix+g（tig）、Prefix+t（fzf）、Prefix+m（Claude Code監視）

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

- ユーザーレベルのCLAUDE.md、settings.json、カスタムスキル、プラグイン設定をchezmoi管理
- `/sync-claude-config` コマンドで設定変更をdotfilesに同期
- tmux監視システム: 複数ウィンドウで起動したClaude Codeの状態（許可待ち・入力待ち・実行中）をステータスバーに集計表示し、Prefix+mで一覧から移動

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
├── mise/           → ~/.config/mise/
├── tmux/           → ~/.config/tmux/ (Claude Code監視スクリプト)
└── starship.toml   → ~/.config/starship.toml
dot_claude/          → ~/.claude/
├── commands/        カスタムコマンド
├── hooks/           PreToolUse / Notification フック
├── private_plugins/ プラグイン設定
└── skills/          カスタムスキル
dot_tmux.conf        → ~/.tmux.conf
```

## chezmoi初期化スクリプト

chezmoiの `run_` スクリプトにより、初回適用時や設定変更時に自動セットアップが実行される。

| スクリプト | 内容 |
|---|---|
| run_once_before_01 | Homebrewインストール |
| run_once_before_03 | miseインストール |
| run_onchange_before_02 | Brewfileのパッケージインストール |
| run_onchange_after_01 | miseツール一括インストール |
| run_once_after_02 | fishをデフォルトシェルに設定 |
| run_once_after_04 | git hooks設定、gitエイリアス設定 |

## .hooks/

- pre-commitフック: テンプレート内の絶対ホームパスを自動的に`{{ .chezmoi.homeDir }}`に置換

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
| コマンド名 | bat, fd | batcat, fdfind（エイリアスで吸収済み） |
| tmux自動起動 | Ghosttyクイックターミナル内で無効化 | 常に有効 |
