-- 必須プラグイン

return {
  -- ファジーファインダー
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "ファイル検索" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "文字列検索" })
    end,
  },
}
