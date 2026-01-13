-- 基本設定

local opt = vim.opt

-- 行番号
opt.number = true           -- 行番号を表示
opt.relativenumber = false  -- 相対行番号を表示

-- インデント
opt.tabstop = 2             -- タブの幅
opt.shiftwidth = 2          -- インデントの幅
opt.expandtab = true        -- タブをスペースに変換
opt.smartindent = true      -- 自動インデント

-- 検索
opt.ignorecase = true       -- 検索時に大文字小文字を区別しない
opt.smartcase = true        -- 大文字が含まれる場合は区別する

-- 表示
opt.termguicolors = true    -- 24bitカラーを有効化
opt.signcolumn = "yes"      -- サイン列を常に表示
opt.cursorline = true       -- カーソル行をハイライト
opt.wrap = false            -- 行の折り返しを無効化

-- ファイル
opt.swapfile = false        -- スワップファイルを作成しない
opt.backup = false          -- バックアップファイルを作成しない
opt.undofile = true         -- アンドゥ履歴を保存

-- その他
opt.mouse = "a"             -- マウス操作を有効化
opt.clipboard = "unnamedplus" -- システムクリップボードを使用
opt.updatetime = 300        -- 更新時間を短縮
opt.completeopt = "menu,menuone,noselect" -- 補完メニューの設定
