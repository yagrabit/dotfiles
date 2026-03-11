# ディレクトリ移動後に自動でファイル一覧を表示
function cd -d 'ディレクトリ移動後にeza -la --iconsを実行'
    builtin cd $argv; or return
    eza -la --icons
end
