-- Claude Code連携（Sidekick.nvim）

return {
  "folke/sidekick.nvim",
  event = "VeryLazy",
  opts = {
    nes = { enabled = true },
    cli = {
      name = "claude",
      mux = { enabled = false },
    },
  },
  keys = {
    { "<leader>aa", function() require("sidekick.cli").toggle({ name = "claude", focus = true }) end, desc = "Claude Code" },
  },
}
