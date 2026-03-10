-- キーマップ設定

-- リーダーキー
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = vim.keymap.set

-- 基本操作
keymap("n", "<leader>w", "<cmd>w<cr>", { desc = "保存" })
keymap("n", "<leader>q", "<cmd>q<cr>", { desc = "終了" })

-- ウィンドウ移動
keymap("n", "<C-h>", "<C-w>h", { desc = "左のウィンドウへ" })
keymap("n", "<C-j>", "<C-w>j", { desc = "下のウィンドウへ" })
keymap("n", "<C-k>", "<C-w>k", { desc = "上のウィンドウへ" })
keymap("n", "<C-l>", "<C-w>l", { desc = "右のウィンドウへ" })

-- ウィンドウ分割
keymap("n", "<leader>sv", "<cmd>vsplit<cr>", { desc = "縦分割" })
keymap("n", "<leader>sh", "<cmd>split<cr>", { desc = "横分割" })

-- バッファ移動
keymap("n", "<Tab>", "<cmd>bnext<cr>", { desc = "次のバッファ" })
keymap("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "前のバッファ" })

-- Visualモードで行移動
keymap("v", "J", ":m '>+1<cr>gv=gv", { desc = "行を下に移動" })
keymap("v", "K", ":m '<-2<cr>gv=gv", { desc = "行を上に移動" })

-- Visualモードでインデント調整
keymap("v", "<", "<gv", { desc = "インデント減" })
keymap("v", ">", ">gv", { desc = "インデント増" })

-- 検索ハイライトクリア
keymap("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "ハイライトクリア" })
