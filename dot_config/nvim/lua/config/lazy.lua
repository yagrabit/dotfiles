-- lazy.nvim プラグインマネージャーのセットアップ

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- lazy.nvimが存在しない場合は自動インストール
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

-- プラグインを読み込む
require("lazy").setup("plugins", {
  change_detection = {
    notify = false, -- 変更検知の通知を無効化
  },
})
