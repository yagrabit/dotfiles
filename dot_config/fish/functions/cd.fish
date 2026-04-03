# ディレクトリ移動後に自動でファイル一覧を表示（対話シェルのみ）
function cd -d 'ディレクトリ移動後にeza -la --iconsを実行'
    builtin cd $argv; or return
    if status is-interactive; and type -q eza
        eza -la --icons
    end
end
