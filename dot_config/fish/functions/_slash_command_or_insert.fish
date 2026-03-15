# スラッシュキーのディスパッチャー
function _slash_command_or_insert -d 'スラッシュキーのディスパッチャー'
    if test -z (commandline)
        slash_command
    else
        commandline -i /
    end
end
