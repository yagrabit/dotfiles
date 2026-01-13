-- 軽量表示用の必須プラグイン

return {
  -- ファイルツリー（軽く見るのに便利）
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>e", ":NvimTreeToggle<CR>", desc = "ファイルツリー" },
    },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 30,
        },
      })
    end,
  },

  -- ファジーファインダー（ファイル検索）
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", ":Telescope find_files<CR>", desc = "ファイル検索" },
      { "<leader>fg", ":Telescope live_grep<CR>", desc = "文字列検索" },
    },
  },
}

