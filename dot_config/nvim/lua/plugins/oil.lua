-- バッファ型ファイラー（Oil.nvim）

return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("oil").setup({
      -- 隠しファイルを表示
      view_options = {
        show_hidden = true,
      },
    })
    -- `-` キーで親ディレクトリを開く
    vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "親ディレクトリを開く" })
  end,
}
