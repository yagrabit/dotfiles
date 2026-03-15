# fish関数をスラッシュコマンドとしてfzfで選択・実行
function slash_command -d 'スラッシュコマンド一覧をfzfで選択・実行'
    # $SLASH_COMMANDSが未定義なら終了
    if not set -q SLASH_COMMANDS; or test (count $SLASH_COMMANDS) -eq 0
        echo "スラッシュコマンドが登録されていません"
        commandline -f repaint
        return
    end

    # 関数名の最大長を取得（縦線の位置を揃えるため）
    set -l max_len 0
    for name in $SLASH_COMMANDS
        set -l len (string length $name)
        if test $len -gt $max_len
            set max_len $len
        end
    end

    # 登録された関数の一覧を収集（関数名 │ 説明 の形式）
    set -l entries
    for name in $SLASH_COMMANDS
        set -l desc (string match -rg -- "^function\\s+\\S+.*-d\\s+'([^']+)'" < ~/.config/fish/functions/$name.fish 2>/dev/null)
        if test -z "$desc"
            set desc "$name"
        end
        set -a entries (printf '%-'$max_len's │ %s' $name $desc)
    end

    # fzfで選択（インライン表示、FZF_DEFAULT_OPTSが適用される）
    set -l selection (printf '%s\n' $entries | fzf \
        --header '/ スラッシュコマンド' \
        --prompt '/ ' \
        --no-multi)

    if test -n "$selection"
        # 選択結果から関数名を抽出して実行（│ の前の部分）
        set -l cmd (string trim (string split '│' $selection)[1])
        eval $cmd
    end

    commandline -f repaint
end
