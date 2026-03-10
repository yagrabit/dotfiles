# ローカルブランチをfzfで切り替え（worktree対応）
function fbr -d 'ローカルブランチをfzfで切り替え'
    set -l branch_line (git branch -vv | fzf --tmux 90%,80% +m)
    if test -z "$branch_line"
        return
    end

    set -l branch (echo $branch_line | awk '{print $1}')

    if test "$branch" = "*"
        return
    end

    # worktreeの場合（+マーク）はそのディレクトリへ移動
    if test "$branch" = "+"
        set branch (echo $branch_line | awk '{print $2}')
        set -l worktree (git worktree list | grep -F "[$branch]" | awk '{print $1}')
        if test -n "$worktree"
            cd $worktree
            commandline -f repaint
        end
        return
    end

    # 変更をstashして切り替え
    set -l res (git stash 2>&1)
    git switch $branch
    if not string match -q "No local changes*" $res
        git stash pop
    end
    commandline -f repaint
end
