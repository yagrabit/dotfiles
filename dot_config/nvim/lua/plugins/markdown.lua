-- Markdown表示強化（render-markdown.nvim + treesitter）

return {
  -- シンタックスハイライト基盤
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "markdown", "markdown_inline" },
        highlight = { enable = true },
      })
    end,
  },

  -- Markdownレンダリング
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown" },
    opts = {},
  },
}
