-- Markdownプレビュー（glowによるプレビューはtelescope不要）
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.keymap.set("n", "<leader>mp", "<cmd>split | terminal glow %<cr>", { buffer = true, desc = "Markdownプレビュー" })
  end,
})

-- Markdownファイル検索（telescope依存、遅延ロード）
return {
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      {
        "<leader>fm",
        function()
          require("telescope.builtin").find_files({
            prompt_title = "Markdownファイル検索",
            find_command = { "fd", "--type", "f", "--extension", "md", "--no-ignore", "--exclude", "node_modules", "--exclude", ".git" },
          })
        end,
        desc = "Markdownファイル検索",
      },
    },
  },
}
