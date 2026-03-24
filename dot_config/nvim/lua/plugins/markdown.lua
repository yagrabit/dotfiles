-- Markdownプレビュー・検索

-- glowでプレビュー
vim.keymap.set("n", "<leader>mp", "<cmd>split | terminal glow %<cr>", { desc = "Markdownプレビュー" })

-- Markdownファイル検索（.gitignore無視、.claude/配下も検索対象）
vim.keymap.set("n", "<leader>fm", function()
  require("telescope.builtin").find_files({
    prompt_title = "Markdownファイル検索",
    find_command = { "fd", "--type", "f", "--extension", "md", "--no-ignore", "--exclude", "node_modules", "--exclude", ".git" },
  })
end, { desc = "Markdownファイル検索" })

return {}
