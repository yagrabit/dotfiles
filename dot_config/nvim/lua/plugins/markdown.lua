-- Markdownプレビュー・検索
-- lazy.nvimのkeys/configで遅延ロード時にキーマップを登録する

return {
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      {
        "<leader>mp",
        "<cmd>split | terminal glow %<cr>",
        desc = "Markdownプレビュー",
      },
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
