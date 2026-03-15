# dotfiles

chezmoi管理のdotfilesリポジトリ。macOS / Linux対応。

## ツール構成

| カテゴリ | ツール |
|---|---|
| ターミナル | Ghostty |
| マルチプレクサ | tmux |
| シェル | fish + starship |
| エディタ | Neovim (lazy.nvim) |
| リポジトリ管理 | ghq + fzf |
| モダンCLI | eza, bat, fd, rg, zoxide |
| ツールバージョン管理 | mise |
| キーバインド | Karabiner-Elements |
| AI | Claude Code |

## インストール

```sh
sh -c "$(curl -fsLS get.chezmoi.io)"
chezmoi init --apply <github-username>
```

chezmoi初期化スクリプトにより、Homebrew・mise・各ツールのインストールとシェル設定が自動で行われる。

## 操作リファレンス

### fish shell

#### エイリアス

コマンドが存在する場合のみ置換する tool-if-exists 方式。

| 入力 | 実行されるコマンド |
|---|---|
| `ls` | `eza --icons --git` |
| `cat` | `bat --paging=never` |
| `find` | `fd` |
| `grep` | `rg` |
| `vim` / `vi` | `nvim` |

#### 省略展開 (abbr)

| 入力 | 展開後 |
|---|---|
| `ll` | `eza --icons --git -l` |
| `la` | `eza --icons --git -la` |
| `tree` | `eza --icons --tree` |

#### キーバインド

| キー | 動作 |
|---|---|
| `/` | スラッシュコマンド（空バッファ時のみ、dotfiles関数一覧をfzfで選択・実行） |
| `Ctrl+G Ctrl+G` | ghqリポジトリをfzfで選択して移動 |
| `Ctrl+G Ctrl+R` | ローカルブランチをfzfで切り替え |
| `Ctrl+G Ctrl+M` | リモートブランチをfzfで切り替え |
| `Ctrl+G Ctrl+S` | git stashをfzfで管理 |

#### 関数

| 関数名 | 説明 |
|---|---|
| `slash_command` | dotfiles関数一覧をfzfで選択・実行（`$SLASH_COMMANDS`変数で対象を管理） |
| `ghq_fzf_repo` | ghqリポジトリをfzfで選択して移動（READMEプレビュー付き） |
| `fbr` | ローカルブランチをfzfで切り替え（worktree対応） |
| `fbrd` | ブランチをfzfで複数選択して削除（`-f`で強制削除） |
| `fbrclean` | マージ済み（gone状態）のブランチをfzfで選択してまとめて削除 |
| `fbrm` | リモートブランチをfzfで切り替え |
| `fstash` | git stashをfzfで管理（下表参照） |
| `ghq_pull_all` | ghq管理下の全リポジトリを `git pull --ff-only` |
| `groot` | Gitリポジトリのルートディレクトリへ移動 |
| `gwroot` | Git worktreeの親ディレクトリへ移動 |
| `cd` | ディレクトリ移動後に自動で `eza -la` を表示 |

fstash の操作:

| キー | 動作 |
|---|---|
| `Enter` | 選択したstashをapply |
| `Ctrl+P` | 選択したstashをpop |
| `Ctrl+D` | 選択したstashをdrop |
| `Ctrl+F` | stash内のファイルを選択してcheckout |

#### その他

- tmux自動起動: インタラクティブシェルかつtmux未起動時に自動アタッチ（macOSではGhosttyクイックターミナル除外）
- cd後にeza自動表示
- zoxide, fzf, mise, starship の初期化

### Neovim

リーダーキー: スペース

#### グローバルキーマップ

| キー | 動作 |
|---|---|
| `<leader>w` | 保存 |
| `<leader>q` | 終了 |
| `<leader>e` | ファイルツリー開閉 (nvim-tree) |
| `<leader>ff` | ファイル検索 (telescope) |
| `<leader>fg` | 文字列検索 (telescope) |
| `<leader>sv` | 縦分割 |
| `<leader>sh` | 横分割 |
| `<leader>aa` | Claude Code Toggle (sidekick) |
| `-` | 親ディレクトリを開く (oil.nvim) |
| `Ctrl+h/j/k/l` | ウィンドウ移動 |
| `Tab` / `Shift+Tab` | 次/前のバッファ |
| `V` + `J/K` | 選択行を下/上に移動 |
| `V` + `</>` | インデント減/増 |
| `Esc` | 検索ハイライトクリア |

#### nvim-tree（ファイルツリー）

`<leader>e` で開閉。ツリー内で `g?` を押すとヘルプ表示。

ファイルを開く:

| キー | 動作 |
|---|---|
| `<CR>` / `o` | ファイルを開く / ディレクトリ展開 |
| `<Tab>` | プレビュー（カーソルはツリーに残る） |
| `<C-v>` | 垂直分割で開く |
| `<C-x>` | 水平分割で開く |
| `<C-t>` | 新しいタブで開く |

ファイル操作:

| キー | 動作 |
|---|---|
| `a` | 新規作成（末尾 `/` でディレクトリ） |
| `d` | 削除 |
| `r` | リネーム |
| `x` | カット |
| `c` | コピー |
| `p` | ペースト |
| `y` | ファイル名コピー |
| `Y` | 相対パスコピー |
| `gy` | 絶対パスコピー |

ナビゲーション:

| キー | 動作 |
|---|---|
| `P` | 親ディレクトリに移動 |
| `<BS>` | ディレクトリを折りたたみ |
| `<C-]>` | カーソル位置をルートに設定 |
| `E` | すべて展開 |
| `W` | すべて折りたたみ |
| `H` | 隠しファイル表示切替 |
| `I` | .gitignore対象の表示切替 |
| `f` | ライブフィルタ |
| `F` | フィルタクリア |
| `S` | ノード検索 |
| `R` | 再読み込み |
| `q` | ツリーを閉じる |

#### oil.nvim（バッファ型ファイラー）

`-` で起動。通常のVim編集操作でファイル操作を行い、`:w` で確定する。

キーバインド:

| キー | 動作 |
|---|---|
| `<CR>` | ファイルを開く / ディレクトリに入る |
| `-` | 親ディレクトリへ戻る |
| `<C-p>` | プレビュー |
| `<C-s>` | 垂直分割で開く |
| `<C-h>` | 水平分割で開く |
| `<C-t>` | 新しいタブで開く |
| `g.` | 隠しファイル表示切替 |
| `gs` | ソート順変更 |
| `<C-c>` | oilバッファを閉じる |
| `<C-l>` | 表示を再読み込み |
| `g?` | ヘルプ表示 |

ファイル操作（Vim編集方式）:

| 操作 | 方法 |
|---|---|
| 新規作成 | `o` で新行追加しファイル名を入力（末尾 `/` でディレクトリ） |
| 削除 | ファイル名の行を `dd` で削除 |
| リネーム | ファイル名を `cw` 等で直接編集 |
| 確定 | `:w` で全変更を実行 |
| 破棄 | `:e!` で変更を取り消し |

#### telescope.nvim（ファジーファインダー）

`<leader>ff` でファイル検索、`<leader>fg` で文字列検索。インサートモードで `Ctrl+/`、ノーマルモードで `?` を押すとヘルプ表示。

結果の移動:

| キー | モード | 動作 |
|---|---|---|
| `<C-n>` / `<Down>` | インサート | 次の項目 |
| `<C-p>` / `<Up>` | インサート | 前の項目 |
| `j` / `k` | ノーマル | 次/前の項目 |

ファイルを開く:

| キー | 動作 |
|---|---|
| `<CR>` | ファイルを開く |
| `<C-x>` | 水平分割で開く |
| `<C-v>` | 垂直分割で開く |
| `<C-t>` | 新しいタブで開く |

プレビュー操作:

| キー | 動作 |
|---|---|
| `<C-u>` | プレビューを上にスクロール |
| `<C-d>` | プレビューを下にスクロール |

選択・その他:

| キー | 動作 |
|---|---|
| `<Tab>` | 選択をトグルして次へ |
| `<C-q>` | 全項目をquickfixリストに送る |
| `<C-c>` / `<Esc>` | 閉じる |

#### プラグイン

| プラグイン | 機能 |
|---|---|
| nvim-tree.lua | ファイルツリー |
| telescope.nvim | ファジーファインダー |
| tokyonight.nvim | カラースキーム |
| oil.nvim | バッファ型ファイラー |
| sidekick.nvim | Claude Code連携 |

### tmux

プレフィックスキー: `Ctrl+q`

#### キーバインド

| キー | 動作 |
|---|---|
| `Prefix r` | 設定リロード |
| `Prefix \|` | 右に水平分割 |
| `Prefix -` | 下に垂直分割 |
| `Prefix c` | 新しいウィンドウ |
| `Prefix C` | テンプレート付きウィンドウ（3ペイン） |
| `Prefix h/j/k/l` | ペイン移動（Vim風） |
| `Prefix H/J/K/L` | ペインリサイズ（5単位） |
| `Prefix n` / `Prefix p` | 次/前のウィンドウ |

テンプレート付きウィンドウ（Prefix C）の構成: 上下50%分割、上段を左70%右30%に分割した3ペインレイアウト。

#### コピーモード

viキーバインドで操作。

| キー | 動作 |
|---|---|
| `Prefix [` | コピーモード開始 |
| `v` | 選択開始 |
| `Ctrl+v` | 矩形選択 |
| `y` | コピーして終了 |

#### ポップアップ

| キー | 動作 |
|---|---|
| `Prefix g` | tig（差分確認・コミット） |
| `Prefix t` | fzf（ファイル検索） |
| `Prefix f` | tmux-fzf（ウィンドウ切り替え） |
| `Prefix a` | Claude Code監視一覧（ペインプレビュー付き、Shift+Rでリフレッシュ） |
| `Prefix e` | ポップアップターミナル（単発コマンド実行・ファイル編集用） |

#### プラグイン

| プラグイン | 機能 |
|---|---|
| tpm | プラグインマネージャー |
| tmux-fzf | fzfによるウィンドウ・セッション操作 |
| tmux-rename-window-project | Gitリポジトリ名で自動ウィンドウ命名 |

#### 空きキー（Prefixキーバインド）

tmux本体・プラグインのデフォルトバインドを含めて未使用のキー: `b`, `u`, `v`, `y`

### Git

#### エイリアス

| エイリアス | コマンド |
|---|---|
| `st` | `status` |
| `co` | `checkout` |
| `br` | `branch` |
| `cm` | `commit` |
| `df` | `diff` |
| `pl` | `pull --rebase` |
| `ps` | `push --set-upstream` |
| `lg` | `log --graph`（グラフ付きログ） |

#### 設定

- pull時にrebaseを使用
- push時に上流ブランチを自動設定
- デフォルトブランチ: main

### Ghostty

| 項目 | 値 |
|---|---|
| テーマ | tokyonight |
| フォント | PlemolJP Console NF (14pt) |
| 背景透過 | 85%、ブラー有効 |
| ウィンドウ起動時 | 最大化 |
| タイトルバー | tabs (macOS) |

### Karabiner-Elements

- Ghostty内で `Ctrl+q` 押下時にIMEを英数モードへ自動切替
- tmuxプレフィックスキーが日本語入力中でも確実に動作

### starship

| セグメント | 表示内容 |
|---|---|
| directory | カレントディレクトリ（深さ3まで） |
| git_branch | ブランチ名 |
| git_status | 変更状態 |
| cmd_duration | 2秒以上の実行時間 |
| character | 成功: 緑の❯ / エラー: 赤の❯ |

### Claude Code

#### コマンド・スキル

| 名前 | 種類 | 説明 |
|---|---|---|
| `/sync-claude-config` | コマンド | Claude設定変更をdotfilesに同期 |
| `/blog-memo` | スキル | 会話内容をブログ記事形式のアウトラインに変換 |
| `/commit` | スキル | 変更確認→セキュリティチェック→コミット実行 |

#### hooks

| フック | タイミング | 動作 |
|---|---|---|
| pipe-stage-permissions | PreToolUse | パイプ繋ぎコマンドを分割して各ステージを自動承認判定 |
| notification-tracker | Notification | 状態（許可待ち・入力待ち等）をjsonに記録 |

#### tmux監視システム

複数ウィンドウで起動したClaude Codeの状態をステータスバーに集計表示。`Prefix+a` で一覧表示し、ペイン内容のプレビュー付きでウィンドウに移動可能。Shift+Rで一覧をリフレッシュ。

#### statusline

3行表示: モデル名・コンテキスト使用率、5h/7dレートリミット進捗バー。

#### インストール済みプラグイン

| プラグイン | 機能 |
|---|---|
| coderabbit | コードレビュー |
| frontend-design | UI/UXデザイン |
| code-simplifier | コード簡素化 |
| code-review | コードレビュー支援 |

## ディレクトリ構成

```
dot_config/
├── fish/             → ~/.config/fish/
│   ├── config.fish.tmpl
│   ├── fish_plugins
│   └── functions/
├── ghostty/          → ~/.config/ghostty/
├── karabiner/        → ~/.config/karabiner/
├── nvim/             → ~/.config/nvim/
│   ├── init.lua
│   └── lua/
│       ├── config/   (keymaps, options, lazy)
│       └── plugins/  (essentials, colorscheme, oil, sidekick)
├── tmux/             → ~/.config/tmux/ (Claude Code監視スクリプト)
├── mise/             → ~/.config/mise/
└── starship.toml     → ~/.config/starship.toml
dot_claude/            → ~/.claude/
├── CLAUDE.md
├── settings.json.tmpl
├── commands/          カスタムコマンド
├── hooks/             PreToolUse / Notification フック
├── skills/            カスタムスキル
└── private_plugins/   プラグイン設定
dot_tmux.conf          → ~/.tmux.conf
dot_gitconfig.tmpl     → ~/.gitconfig
```

## chezmoi初期化スクリプト

| スクリプト | タイミング | 内容 |
|---|---|---|
| run_once_before_01 | 初回 | Homebrewインストール |
| run_once_before_03 | 初回 | miseインストール |
| run_onchange_before_02 | Brewfile変更時 | パッケージインストール |
| run_onchange_after_01 | mise設定変更時 | miseツール一括インストール |
| run_once_after_02 | 初回 | fishをデフォルトシェルに設定 |
| run_once_after_04 | 初回 | gitフック設定 |

## Git hooks

- pre-commitフック: テンプレート内の絶対ホームパスを `{{ .chezmoi.homeDir }}` に自動置換

## mise管理ツール

| ツール |
|---|
| bat |
| eza |
| fd |
| fzf |
| ghq |
| neovim |
| ripgrep |
| starship |
| zoxide |

## Docker検証

Ubuntu 24.04ベースのコンテナでchezmoiの適用結果を検証できる。

```sh
docker build -t dotfiles-test .
docker run --rm -it dotfiles-test
```

確認項目:
- fishシェルが起動しstarshipプロンプトが表示される
- `chezmoi diff` で差分がないことを確認
- nvim が正常起動する
- エイリアス（eza, bat, fd, rg）が動作する
- tmux が起動しVim風キーバインドが使える

## macOS / Linux の差異

| 項目 | macOS | Linux |
|---|---|---|
| PATH | /opt/homebrew/bin を追加 | 追加なし |
| コマンド名 | bat, fd | batcat, fdfind（エイリアスで吸収） |
| tmux自動起動 | クイックターミナル内で無効化 | 常に有効 |
