-- キーマップ設定

local keymap = vim.keymap.set

-- リーダーキーをスペースに設定
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 基本操作
keymap("n", "<leader>w", ":w<CR>", { desc = "保存" })
keymap("n", "<leader>q", ":q<CR>", { desc = "終了" })

-- ウィンドウ移動（Ctrl + hjkl）
keymap("n", "<C-h>", "<C-w>h", { desc = "左のウィンドウへ" })
keymap("n", "<C-j>", "<C-w>j", { desc = "下のウィンドウへ" })
keymap("n", "<C-k>", "<C-w>k", { desc = "上のウィンドウへ" })
keymap("n", "<C-l>", "<C-w>l", { desc = "右のウィンドウへ" })

-- ウィンドウ分割
keymap("n", "<leader>sv", ":vsplit<CR>", { desc = "縦分割" })
keymap("n", "<leader>sh", ":split<CR>", { desc = "横分割" })

-- タブ移動
keymap("n", "<Tab>", ":bnext<CR>", { desc = "次のバッファ" })
keymap("n", "<S-Tab>", ":bprevious<CR>", { desc = "前のバッファ" })

-- 行の移動（Visualモード）
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "行を下に移動" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "行を上に移動" })

-- インデント調整（Visualモード）
keymap("v", "<", "<gv", { desc = "インデントを減らす" })
keymap("v", ">", ">gv", { desc = "インデントを増やす" })

-- 検索結果のハイライトをクリア
keymap("n", "<Esc>", ":noh<CR>", { desc = "検索ハイライトをクリア" })
