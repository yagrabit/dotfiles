# tmux起動時にClaude Codeセッションの復元を提案
if status is-interactive; and set -q TMUX
    set -l _cc_backup ~/.claude/tmux-sessions-backup.txt

    if test -f $_cc_backup
        # tmuxウィンドウが1つ（起動直後）の場合のみ
        if test (tmux list-windows 2>/dev/null | wc -l | string trim) = 1
            # データ行（UUIDで始まる行）をカウント
            set -l _cc_count (grep -cE '^[0-9a-f]' $_cc_backup 2>/dev/null)

            if test "$_cc_count" -gt 0
                echo ""
                echo "前回のClaude Codeセッション ($_cc_count 件) が見つかりました"
                read -P "復元しますか？ [y/N] " -l _cc_answer

                if string match -qir '^y' -- $_cc_answer
                    cc-restore
                    # 復元後にバックアップをアーカイブ（再プロンプト防止）
                    mv $_cc_backup $_cc_backup.restored
                end
            end
        end
    end
end
