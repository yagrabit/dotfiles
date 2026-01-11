# dotfiles

macOS向けのdotfiles設定リポジトリ。[chezmoi](https://www.chezmoi.io/)で管理。

## 含まれる設定

- Ghostty（ターミナルエミュレータ）
- fish（シェル）

## セットアップ

### 前提条件

Homebrewがインストールされていること。

### インストール

```bash
# chezmoiをインストール
brew install chezmoi

# dotfilesを適用
chezmoi init --apply yagrabit
```

## Ghostty

高速でGPUアクセラレーションに対応したモダンターミナルエミュレータ。

### テーマと外観

- テーマ: TokyoNight
- フォント: PlemolJP Console NF（日本語対応Nerd Font）
- 背景: 半透明（85%）+ ぼかし効果
- 起動時に最大化

### キーバインド

#### 画面分割の移動（vim風）

| キー | 動作 |
|------|------|
| `Ctrl + h` | 左のペインへ移動 |
| `Ctrl + l` | 右のペインへ移動 |
| `Ctrl + j` | 下のペインへ移動 |
| `Ctrl + k` | 上のペインへ移動 |

#### よく使う標準キーバインド

| キー | 動作 |
|------|------|
| `Cmd + d` | 画面を縦分割 |
| `Cmd + Shift + d` | 画面を横分割 |
| `Cmd + Enter` | 分割を解除して最大化 |
| `Cmd + t` | 新しいタブを開く |
| `Cmd + w` | 現在のペイン/タブを閉じる |
| `Cmd + Shift + ]` | 次のタブへ |
| `Cmd + Shift + [` | 前のタブへ |

#### クイックターミナル

| キー | 動作 |
|------|------|
| `Cmd + Shift + t` | クイックターミナルの表示/非表示 |

画面右側からスライドインするオーバーレイターミナル。他の作業中に素早くコマンドを実行したいときに便利。

### 設定ファイルの場所

```
~/.config/ghostty/config
```

## fish

ユーザーフレンドリーなシェル。

### エイリアス

モダンなCLIツールをデフォルトで使用。

| コマンド | 実行されるツール | 説明 |
|----------|-----------------|------|
| `ls` | eza | アイコン・Git状態付きファイル一覧 |
| `ll` | eza -lh | 詳細表示 |
| `la` | eza -lha | 隠しファイル含む詳細表示 |
| `tree` | eza --tree | ツリー表示 |
| `cat` | bat | シンタックスハイライト付き表示 |
| `find` | fd | 高速ファイル検索 |
| `grep` | rg | 高速テキスト検索 |
| `vim`, `v` | nvim | Neovim |

### ディレクトリ移動

zoxideによるスマートなディレクトリジャンプ。

```bash
# 過去に訪問したディレクトリへジャンプ
z foo        # "foo"を含むディレクトリへ

# インタラクティブ選択
zi
```

### プラグイン

[fisher](https://github.com/jorgebucaran/fisher)で管理。

- fzf.fish: fzfによるファジー検索統合
- autopair.fish: 括弧やクォートの自動補完

### 設定ファイルの場所

```
~/.config/fish/config.fish
~/.config/fish/fish_plugins
```

## 必要なツール

以下のツールを事前にインストールしておくことを推奨。

```bash
brew install fish eza bat fd ripgrep zoxide fzf neovim
brew install --cask ghostty
```

フォントのインストール:

```bash
brew install --cask font-plemol-jp-nf
```

## ライセンス

MIT
