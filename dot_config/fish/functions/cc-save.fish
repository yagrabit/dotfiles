# Claude Codeセッション情報を保存
function cc-save -d 'Claude Codeセッション情報を保存'
    set -l sessions_dir ~/.claude/sessions
    set -l backup_file ~/.claude/tmux-sessions-backup.txt

    if not test -d $sessions_dir
        echo "セッションディレクトリが見つかりません: $sessions_dir"
        return 1
    end

    if not type -q jq
        echo "jqが必要です: brew install jq"
        return 1
    end

    # 全セッションを抽出（同一sessionIdは重複除外）
    set -l entries
    set -l seen_ids
    for f in $sessions_dir/*.json
        test -f $f; or continue
        set -l entry (jq -r '
            [.sessionId, .cwd, (.startedAt / 1000 | strflocaltime("%Y-%m-%d %H:%M"))] |
            @tsv
        ' $f 2>/dev/null)
        if test -n "$entry"
            set -l sid (string split \t $entry)[1]
            if not contains $sid $seen_ids
                set -a seen_ids $sid
                set -a entries $entry
            end
        end
    end

    if test (count $entries) -eq 0
        echo "保存対象のセッションがありません"
        return 0
    end

    # ヘッダコメント（人間向けの一覧）
    set -l now (date "+%Y-%m-%d %H:%M")

    echo "# Claude Code Sessions" >$backup_file
    echo "# $now" >>$backup_file
    echo "#" >>$backup_file
    echo "# セッション一覧:" >>$backup_file
    printf "# %-17s %-38s %s\n" Started SessionID CWD >>$backup_file

    for entry in $entries
        set -l parts (string split \t $entry)
        set -l sid $parts[1]
        set -l cwd (string replace $HOME '~' $parts[2])
        set -l started $parts[3]
        printf "# %-17s %-38s %s\n" $started $sid $cwd >>$backup_file
    end

    echo "#" >>$backup_file
    echo "# 復元: claude -r <SessionID> (対応するCWDで実行すること)" >>$backup_file
    echo "" >>$backup_file

    # データ行（TSV: SessionID, CWD, Started）
    for entry in $entries
        set -l parts (string split \t $entry)
        set -l sid $parts[1]
        set -l cwd (string replace $HOME '~' $parts[2])
        set -l started $parts[3]
        printf "%s\t%s\t%s\n" $sid $cwd $started >>$backup_file
    end

    echo (count $entries)" セッションを保存しました: $backup_file"
end
