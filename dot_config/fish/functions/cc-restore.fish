# Claude Codeセッションをtmuxで復元
function cc-restore -d 'Claude Codeセッションをtmuxで復元'
    if not set -q TMUX
        echo "tmuxセッション内で実行してください"
        return 1
    end

    set -l backup_file ~/.claude/tmux-sessions-backup.txt

    if not test -f $backup_file
        echo "バックアップファイルが見つかりません: $backup_file"
        return 1
    end

    set -l restore_count 0
    set -l used_names

    while read -l line
        # コメント行・空行をスキップ
        if string match -qr '^\s*#' -- $line; or string match -qr '^\s*$' -- $line
            continue
        end

        set -l parts (string split \t $line)
        if test (count $parts) -lt 2
            continue
        end

        set -l sid $parts[1]
        set -l cwd (string replace '~' $HOME $parts[2])

        # CWDが存在するか確認
        if not test -d $cwd
            echo "スキップ: ディレクトリが存在しません: $parts[2]"
            continue
        end

        # ウィンドウ名を生成（CWDの末尾ディレクトリ名）
        set -l base_name (basename $cwd)
        set -l wname $base_name

        # 同名ウィンドウの重複処理
        set -l counter 1
        while contains $wname $used_names
            set counter (math $counter + 1)
            set wname "$base_name-$counter"
        end
        set -a used_names $wname

        tmux new-window -n $wname -c $cwd "claude -r $sid"
        set restore_count (math $restore_count + 1)
    end <$backup_file

    echo "$restore_count セッションを復元しました"
end
