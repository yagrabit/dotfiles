-- NeoVim設定のエントリーポイント

-- 基本設定の読み込み
require("config.options")
require("config.keymaps")

-- プラグインマネージャー（lazy.nvim）のセットアップ
require("config.lazy")
