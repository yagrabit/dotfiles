# dotfiles

macOS向けの個人用dotfilesリポジトリ。Fish、tmux、NeoVim、Ghosttyを中心としたモダンなターミナル環境を構築する。dotfilesの管理にはchezmoiを使用。

## 概要

- dotfiles管理: chezmoi
- シェル: Fish
- ターミナル: Ghostty
- マルチプレクサ: tmux
- エディタ: NeoVim
- プロンプト: Starship
- テーマ: TokyoNight

## 必要なツール

### パッケージマネージャ

- Homebrew

### dotfiles管理

- chezmoi

### コアツール

- Fish シェル
- tmux
- NeoVim
- Ghostty

### CLIツール

| コマンド | 置き換え対象 | 説明 |
|----------|--------------|------|
| eza | ls | モダンなファイル一覧表示 |
| bat | cat | シンタックスハイライト付きファイル表示 |
| fd | find | 高速なファイル検索 |
| ripgrep (rg) | grep | 高速なテキスト検索 |
| zoxide | cd | スマートなディレクトリジャンプ |
| fzf | - | ファジーファインダー |
| ghq | - | リポジトリ管理 |
| Starship | - | カスタマイズ可能なプロンプト |

## ディレクトリ構造

```
dotfiles/
├── dot_tmux.conf              # tmux設定
├── dot_config/
│   ├── fish/
│   │   ├── config.fish        # Fish設定
│   │   └── fish_plugins       # Fisherプラグイン
│   ├── ghostty/
│   │   └── config             # Ghostty設定
│   └── nvim/
│       ├── init.lua           # NeoVimエントリーポイント
│       └── lua/
│           ├── config/        # 基本設定
│           └── plugins/       # プラグイン設定
```

ファイル名の`dot_`プレフィックスはchezmoiの命名規則で、適用時に`.`に変換される（例: `dot_tmux.conf` → `~/.tmux.conf`）。

## tmux

### プレフィックスキー

`Ctrl + q`（デフォルトの`Ctrl + b`から変更）

### ペイン操作

| キー | 動作 |
|------|------|
| `prefix + \|` | 縦分割 |
| `prefix + -` | 横分割 |
| `prefix + h` | 左のペインへ移動 |
| `prefix + j` | 下のペインへ移動 |
| `prefix + k` | 上のペインへ移動 |
| `prefix + l` | 右のペインへ移動 |
| `prefix + H` | ペインを左にリサイズ |
| `prefix + J` | ペインを下にリサイズ |
| `prefix + K` | ペインを上にリサイズ |
| `prefix + L` | ペインを右にリサイズ |
| `prefix + x` | ペインを閉じる |

### ウィンドウ操作

| キー | 動作 |
|------|------|
| `prefix + c` | 新規ウィンドウ作成 |
| `prefix + n` | 次のウィンドウへ |
| `prefix + p` | 前のウィンドウへ |
| `prefix + w` | ウィンドウ一覧 |

### コピーモード（Vim風）

| キー | 動作 |
|------|------|
| `prefix + [` | コピーモード開始 |
| `v` | 選択開始 |
| `y` | コピー |
| `prefix + ]` | ペースト |

### その他

| キー | 動作 |
|------|------|
| `prefix + r` | 設定リロード |
| `prefix + d` | デタッチ |

### 設定の特徴

- ウィンドウ番号は1から開始
- マウス操作を有効化
- ステータスバーは上部に配置
- 256色対応
- Escキーの遅延を0に設定（Vim操作を快適に）

## Fish シェル

### エイリアス

| エイリアス | 実行コマンド |
|------------|--------------|
| `ls` | eza |
| `ll` | eza -l |
| `la` | eza -la |
| `cat` | bat |
| `find` | fd |
| `grep` | rg |
| `vim` / `v` | nvim |

### キーバインド

| キー | 動作 |
|------|------|
| `Ctrl + g` | ghqで管理しているリポジトリへfzfで移動 |
| `Ctrl + r` | コマンド履歴検索（fzf） |
| `Ctrl + f` | ファイル検索（fzf） |

### プラグイン（Fisher）

- fzf.fish: fzf統合
- autopair.fish: 括弧の自動ペアリング

### 自動起動

- tmuxが起動していない場合、シェル起動時にtmuxを自動起動
- Ghosttyのクイックターミナルでは自動起動しない

## NeoVim

### リーダーキー

`Space`

### 基本操作

| キー | 動作 |
|------|------|
| `Ctrl + h/j/k/l` | ウィンドウ間移動 |
| `Tab` | 次のバッファへ |
| `Shift + Tab` | 前のバッファへ |

### ファイル操作

| キー | 動作 |
|------|------|
| `Space + e` | ファイルツリーを開く/閉じる |
| `Space + ff` | ファイル検索（Telescope） |
| `Space + fg` | テキスト検索（Telescope） |

### プラグイン

- lazy.nvim: プラグインマネージャー
- nvim-tree.lua: ファイルツリー
- telescope.nvim: ファジーファインダー
- tokyonight.nvim: カラースキーム

## Ghostty

### 主な設定

- フォント: PlemolJP Console NF
- テーマ: TokyoNight
- 背景透明度: 85%
- 背景ブラー: 有効
- クイックターミナル: 右側に表示

### クイックターミナル

Ghosttyのクイックターミナル機能を使用して、ホットキーで素早くターミナルを呼び出せる。クイックターミナルではtmuxは自動起動しない設計になっている。

## セットアップ

1. chezmoiと必要なツールをHomebrewでインストール

```sh
brew install chezmoi
brew install fish tmux neovim ghostty
brew install eza bat fd ripgrep zoxide fzf ghq starship
```

2. Fishをデフォルトシェルに設定

```sh
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
```

3. Fisherをインストール

```sh
curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
```

4. chezmoiでdotfilesを適用

```sh
# 新しいマシンでの初期設定
chezmoi init https://github.com/yagrabit/dotfiles.git
chezmoi diff  # 変更内容を確認
chezmoi apply # dotfilesを適用
```

5. Fisherプラグインをインストール

```sh
fisher update
```

### chezmoiの基本コマンド

| コマンド | 説明 |
|----------|------|
| `chezmoi diff` | 適用される変更の差分を表示 |
| `chezmoi apply` | dotfilesをホームディレクトリに適用 |
| `chezmoi edit ~/.config/fish/config.fish` | ファイルを編集（ソースを更新） |
| `chezmoi cd` | chezmoiのソースディレクトリへ移動 |
| `chezmoi update` | リモートから最新を取得して適用 |

## ライセンス

MIT
