# リモートでマージ済み（gone状態）のローカルブランチをfzfで確認しながらまとめて削除
function fbrclean -d 'マージ済みブランチをまとめて削除'
    set -l force ""
    if contains -- -f $argv
        set force "-f"
    end

    # リモート状態を最新化
    echo "リモート状態を取得中..."
    git fetch --prune 2>/dev/null

    # gone状態のブランチを抽出
    set -l gone_branches
    for line in (git branch -vv)
        # 現在のブランチ（* マーク）はスキップ
        if string match -q '\* *' -- $line
            continue
        end

        # goneを含まない行はスキップ
        if not string match -q '*gone]*' -- $line
            continue
        end

        # ブランチ名を抽出（除外判定用）
        set -l branch_name (echo $line | string trim | awk '{print $1}')

        # main, master, develop は除外（完全一致）
        if test "$branch_name" = "main" -o "$branch_name" = "master" -o "$branch_name" = "develop"
            continue
        end

        # epic/* は前方一致で除外
        if string match -q 'epic/*' -- $branch_name
            continue
        end

        set -a gone_branches $line
    end

    # 候補がなければ終了
    if test (count $gone_branches) -eq 0
        echo "削除対象のブランチはありません"
        return
    end

    # fzfで複数選択
    set -l selected (printf '%s\n' $gone_branches | fzf -m --tmux 90%,80% \
        --header 'マージ済みブランチ削除（TABで選択/解除 Ctrl-A:全選択）' \
        --bind 'ctrl-a:select-all' \
        --preview 'git log --oneline -20 --color=always $(echo {} | sed "s/^[[:space:]]*[+*]*//" | awk "{print \$1}")' \
        --preview-window 'right:50%')

    # 未選択ならキャンセル
    if test -z "$selected"
        commandline -f repaint
        return
    end

    # 選択されたブランチをループ削除
    for branch_line in $selected
        set -l branch (echo $branch_line | string trim | awk '{print $1}')

        # * や空のブランチはスキップ
        if test "$branch" = "*" -o -z "$branch"
            continue
        end

        if test "$branch" = "+"
            # worktreeの場合、worktree削除してからブランチ削除
            set branch (echo $branch_line | string trim | awk '{print $2}')
            set -l worktree (git worktree list | grep -F "[$branch]" | awk '{print $1}')
            if test -n "$worktree"
                if test -n "$force"
                    git worktree remove -f $worktree
                else
                    git worktree remove $worktree
                end
            end
        end

        if test -n "$force"
            git branch -D $branch
        else
            git branch -d $branch
        end
    end
    commandline -f repaint
end
