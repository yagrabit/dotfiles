-- Markdownプレビュー（glowをターミナルバッファで表示）

vim.keymap.set("n", "<leader>mp", "<cmd>split | terminal glow %<cr>", { desc = "Markdownプレビュー" })

return {}
