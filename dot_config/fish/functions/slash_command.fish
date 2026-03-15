# fish関数をスラッシュコマンドとしてfzfで選択・実行
function slash_command -d 'スラッシュコマンド一覧をfzfで選択・実行'
    # $SLASH_COMMANDSが未定義なら終了
    if not set -q SLASH_COMMANDS; or test (count $SLASH_COMMANDS) -eq 0
        echo "スラッシュコマンドが登録されていません"
        commandline -f repaint
        return
    end

    # 登録された関数の一覧を収集
    set -l entries
    for name in $SLASH_COMMANDS
        # 関数ファイルからdescriptionを抽出
        set -l desc (string match -rg -- "^function\\s+\\S+.*-d\\s+'([^']+)'" < ~/.config/fish/functions/$name.fish 2>/dev/null)
        if test -z "$desc"
            set desc "$name"
        end
        set -a entries "$name\t$desc"
    end

    # fzfで選択
    set -l selection (printf '%s\n' $entries | fzf \
        --tmux 90%,80% \
        --header '/ スラッシュコマンド' \
        --prompt '/ ' \
        --delimiter '\t' \
        --with-nth '1..' \
        --preview 'functions {1}' \
        --preview-window 'right:50%:wrap' \
        --no-multi)

    if test -n "$selection"
        # 選択された関数名を取得して実行
        set -l cmd (string split \t $selection)[1]
        eval $cmd
    end

    commandline -f repaint
end
