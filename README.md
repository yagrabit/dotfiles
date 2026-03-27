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
| `cd` | ディレクトリ移動後に自動で `eza -la --icons` を表示 |
| `gall` | 指定ファイルの内容をMarkdown形式でクリップボードにコピー（AI向けコンテキスト共有用） |

fstash の操作:

| キー | 動作 |
|---|---|
| `Enter` | 選択したstashをapply |
| `Ctrl+P` | 選択したstashをpop |
| `Ctrl+D` | 選択したstashをdrop |
| `Ctrl+F` | stash内のファイルを選択してcheckout |

#### その他

- tmux自動起動: インタラクティブシェルかつtmux未起動時に自動アタッチ（macOSではGhosttyクイックターミナル除外）
- cd後にeza --icons自動表示
- zoxide, fzf, mise, starship の初期化

### Neovim

リーダーキー: スペース

#### グローバルキーマップ

| キー | 動作 |
|---|---|
| `<leader>w` | 保存 |
| `<leader>q` | 終了 |
| `<leader>ff` | ファイル検索 (telescope) |
| `<leader>fg` | 文字列検索 (telescope) |
| `<leader>mp` | Markdownプレビュー (glow) |
| `<leader>fm` | Markdownファイル検索（.gitignore無視、telescope） |
| `<leader>cp` | 絶対パスをクリップボードにコピー |
| `<leader>cr` | 相対パスをクリップボードにコピー |
| `<leader>cf` | ファイル名をクリップボードにコピー |
| `<leader>o` / `<leader>O` | 下/上に空行を挿入（インサートモードに入らない） |
| `Ctrl+a` | 全選択 |
| `<leader>sv` | 縦分割 |
| `<leader>sh` | 横分割 |
| `-` | 親ディレクトリを開く (oil.nvim) |
| `Ctrl+h/j/k/l` | ウィンドウ移動 |
| `Tab` / `Shift+Tab` | 次/前のバッファ |
| `V` + `J/K` | 選択行を下/上に移動 |
| `V` + `</>` | インデント減/増 |
| `Esc` | 検索ハイライトクリア |

#### oil.nvim（バッファ型ファイラー）

`vim .` または `-` で起動。通常のVim編集操作でファイル操作を行い、`:w` で確定する。

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

基本操作（Vim編集方式）:

| 操作 | 方法 |
|---|---|
| ファイルを開く | `Enter` |
| 親ディレクトリへ | `-` |
| 新規作成 | `o` で新行追加しファイル名を入力（末尾 `/` でディレクトリ） |
| 削除 | ファイル名の行を `dd` で削除 |
| リネーム | ファイル名を `cw` 等で直接編集 |
| 移動 | `dd` → 移動先で `p` |
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
| telescope.nvim | ファジーファインダー |
| plenary.nvim | Lua関数ライブラリ（telescope依存） |
| nvim-web-devicons | アイコン表示（oil依存） |
| tokyonight.nvim | カラースキーム |
| oil.nvim | バッファ型ファイラー（隠しファイルはデフォルトで表示: `show_hidden = true`） |

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

テンプレート付きウィンドウ（Prefix C）の構成: まず上下50%分割し、次に上段ペインを左70%右30%に分割した3ペインレイアウト。

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
| `Prefix E` | fzf+glowによるMarkdownプレビューア（Claude編集履歴+プロジェクトMD統合検索） |

#### プラグイン

| プラグイン | 機能 |
|---|---|
| tpm | プラグインマネージャー |
| tmux-fzf | fzfによるウィンドウ・セッション操作 |
| tmux-rename-window-project | Gitリポジトリ名で自動ウィンドウ命名 |

#### 空きキー（Prefixキーバインド）

tmux本体・プラグインのデフォルトバインドを含めて未使用のキー: `b`, `u`, `v`, `y`（v/yはコピーモードでは使用済み。このテーブルはPrefixキーバインドでの未使用を示す）

注: Prefix+eとPrefix+Eは別キー（Shift有無で区別）

### Git

~/.gitconfigはchezmoi管理外（手動管理）。新環境セットアップ時は別途設定が必要。

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
- グローバルgitignore: `~/.config/git/ignore`（chezmoi管理）

### Ghostty

| 項目 | 値 |
|---|---|
| テーマ | tokyonight |
| フォント | PlemolJP Console NF (14pt) |
| フォント太め | `font-thicken = true` |
| 背景透過 | 85%、ブラー有効 |
| ウィンドウ起動時 | 最大化 |
| タイトルバー | tabs (macOS) |
| シェル統合 | fish (`shell-integration = fish`) |
| 選択時コピー | クリップボードに自動コピー (`copy-on-select = clipboard`) |

### Karabiner-Elements

- Ghostty内で `Ctrl+q` 押下時にIMEを英数モードへ自動切替
- tmuxプレフィックスキーが日本語入力中でも確実に動作

### starship

| セグメント | 表示内容 |
|---|---|
| directory | カレントディレクトリ（深さ3まで、`fish_style_pwd_dir_length = 1`でfish風の短縮パス表示） |
| git_branch | ブランチ名 |
| git_status | 変更状態（ahead_behind含む） |
| cmd_duration | 2秒以上の実行時間 |
| character | 成功: 緑の❯ / エラー: 赤の❯ |

### Claude Code

#### コマンド・スキル

| カテゴリ | 名前 | 説明 |
|---|---|---|
| odin | `/odin` | 最強の開発ワークフロー司令塔。配下21スキルをオーケストレーションし、あらゆる開発シーンに対応する自己進化型スキル |
| odin/think系 | `/odin-think-research`, `-requirements`, `-design`, `-plan`, `-investigate`, `-analyze` | 調査・要件分析・設計・タスク分解・バグ調査・品質分析の6種 |
| odin/do系 | `/odin-do-commit`, `-implement`, `-test`, `-refactor`, `-pr`, `-merge` | コミット・実装・テスト・リファクタ・PR作成・マージの6種 |
| odin/talk系 | `/odin-talk-clarify`, `-propose`, `-review`, `-explain` | 要件ヒアリング・提案・コードレビュー・説明の4種 |
| odin/auto系 | `/odin-auto-quality`, `-review`, `-verify`, `-improve`, `-evolve` | 品質チェック・セルフレビュー・完了検証・自己改善・スキル自己進化の5種 |
| PR/Git | `/pr-1-worktree` | worktreeでの隔離作業 |
| PR/Git | `/pr-2-commit` | 変更確認→セキュリティチェック→コミット実行 |
| PR/Git | `/pr-3-review` | ベースブランチ差分の複数観点レビュー |
| PR/Git | `/pr-4-create` | ブランチ作成→コミット→レビュー→Draft PR作成 |
| PR/Git | `/pr-5-coderabbit-fix` | CodeRabbitレビュー指摘の分析・修正 |
| PR/Git | `/pr-6-merge` | PRマージ→ブランチ削除→クリーンアップ |
| 品質 | `/qa-quality-check` | lint/型チェック/テスト/セキュリティスキャン一括実行 |
| 品質 | `/qa-harness-audit` | Claude Code設定品質のスコアリング |
| 品質 | `/qa-next-analyze` | Next.jsバンドルサイズ分析 |
| ドキュメント | `/doc-blog-memo` | 会話内容をブログ記事の骨組みに変換 |
| ドキュメント | `/doc-interview` | Confluenceページをヒアリングで完成 |
| ドキュメント | `/doc-drawio` | draw.io図の生成 |
| UX/デザイン | `/ux-1-brand` | ブランドアイデンティティ管理 |
| UX/デザイン | `/ux-2-tokens` | デザイントークン設計（3層: primitive→semantic→component） |
| UX/デザイン | `/ux-3-core` | UI/UXデザインインテリジェンス（スタイル・カラー・タイポグラフィ） |
| UX/デザイン | `/ux-4-styling` | shadcn/ui + Tailwind CSSによるUIスタイリング |
| UX/デザイン | `/ux-5-design` | ロゴ生成・CIPモックアップ・アイコン・ソーシャルフォト生成（Gemini AI活用） |
| UX/デザイン | `/ux-6-banner` | バナーデザイン（SNS・広告・Webヒーロー・印刷向け、22スタイル対応） |
| UX/デザイン | `/ux-7-slides` | HTMLプレゼンテーション作成 |
| 設定 | `/sync-claude-config` | Claude設定をchezmoiテンプレートとして同期 |

#### hooks

| フック | タイミング | 動作 |
|---|---|---|
| pipe-stage-permissions | PreToolUse | パイプ繋ぎコマンドを分割して各ステージを自動承認判定 |
| notification-tracker | Notification | 状態（許可待ち・入力待ち等）をjsonに記録 |
| md-preview-tracker | PostToolUse | MDファイル編集時にパスを記録（Prefix+Eで表示） |
| auto-format | PostToolUse | .ts/.tsx/.js/.jsx/.css/.scss/.jsonファイル編集後にBiome/Prettierで自動フォーマット |
| block-defer-phrases | PreToolUse | PRコメント・コミットメッセージ内の「後で対応」等の先送り表現をブロック |
| block-no-verify | PreToolUse | `git commit --no-verify` によるプリコミットフックのバイパスをブロック |
| check-ci-coderabbit | （外部呼出） | PRのCI check runsとCodeRabbitコメントの状態をJSON形式で確認 |
| doc-update-reminder | PostToolUse | git commit後にソースコード変更のみでドキュメント未更新の場合にリマインド |
| git-push-reminder | PreToolUse | git push（特にforce push）を検出して警告を表示（ブロックはしない） |
| memory-ingest | Stop | セッション終了時に会話ログをyb-memoryに自動取り込み |
| post-push-monitor | PostToolUse | git push成功後にCI/CodeRabbit監視の指示をadditionalContextで返す |
| pre-compact-log | PreCompact | コンパクション発生をログファイルに記録 |
| pre-edit-guard | PreToolUse | lint設定・hooks・CI設定などの重要ファイルへの不正な改竄をブロック |
| pre-push-review-gate | PreToolUse | `/pr-3-review` 未完了のブランチからのpushをブロック |
| prompt-recall-memory | UserPromptSubmit | ユーザープロンプトで過去の会話を検索し、関連記憶をコンテキストに注入 |
| session-start-check | SessionStart | セッション開始時に環境チェックを実行し、結果をadditionalContextで提供 |
| typecheck | PostToolUse | .ts/.tsxファイル編集後にtscで型チェックし、関連エラーを抽出して表示 |

#### tmux監視システム

複数ウィンドウで起動したClaude Codeの状態をステータスバーに集計表示。`Prefix+a` で一覧表示し、ペイン内容のプレビュー付きでウィンドウに移動可能。Shift+Rで一覧をリフレッシュ。

#### statusline

3行表示: モデル名・コンテキスト使用率、5h/7dレートリミット進捗バー。

#### インストール済みプラグイン

| プラグイン | 機能 |
|---|---|
| coderabbit | PRコードレビュー |
| frontend-design | UI/UXデザイン |
| code-review | コードレビュー支援 |
| skill-creator | スキル作成支援 |
| context7 | ライブラリドキュメント検索 |
| atlassian | Jira/Confluence連携 |
| superpowers | ワークフロー強化（計画・TDD・ブレスト等） |

## ディレクトリ構成

```
dot_config/
├── fish/             → ~/.config/fish/
│   ├── config.fish.tmpl
│   ├── fish_plugins
│   └── functions/
├── ghostty/          → ~/.config/ghostty/
├── git/              → ~/.config/git/ (グローバルgitignore)
├── karabiner/        → ~/.config/karabiner/
├── nvim/             → ~/.config/nvim/
│   ├── init.lua
│   └── lua/
│       ├── config/   (keymaps, options, lazy)
│       └── plugins/  (essentials, colorscheme, oil, markdown)
├── tmux/             → ~/.config/tmux/ (Claude Code監視スクリプト)
├── mise/             → ~/.config/mise/
└── starship.toml     → ~/.config/starship.toml
dot_claude/            → ~/.claude/
├── CLAUDE.md
├── settings.json.tmpl
├── agents/            カスタムエージェント定義（architecture-analyst, code-reviewer等）
├── hooks/             PreToolUse / PostToolUse / Notification / Stop等のフック
├── rules/             共通ルール定義（common/配下に各種ルールファイル）
├── skills/            カスタムスキル（odin系22個・ux系7個・wf系・pr系等）
├── tools/             カスタムツール（yb-memory等）
├── private_plugins/   プラグイン設定
└── private_executable_statusline-command.py  ステータスライン表示スクリプト
dot_tmux.conf          → ~/.tmux.conf
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
| glow |
| lefthook |
| neovim |
| node |
| npm:@antfu/ni |
| npm:@secretlint/secretlint-rule-preset-recommend |
| npm:secretlint |
| python (3.12) |
| ripgrep |
| starship |
| uv |
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
