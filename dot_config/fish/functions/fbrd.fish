# ブランチをfzfで複数選択して削除（worktree対応）
function fbrd -d 'ブランチをfzfで選択して削除'
    set -l force ""
    if contains -- -f $argv
        set force "-f"
    end

    for branch_line in (git branch -vv | fzf -m --tmux 90%,80%)
        set -l branch (echo $branch_line | awk '{print $1}')

        if test "$branch" = "*" -o -z "$branch"
            continue
        end

        if test "$branch" = "+"
            # worktreeの場合、worktree削除してからブランチ削除
            set branch (echo $branch_line | awk '{print $2}')
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
