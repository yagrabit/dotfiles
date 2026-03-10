# リモートブランチをfzfで選択してcheckout
function fbrm -d 'リモートブランチをfzfで切り替え'
    set -l branch (git branch -r | fzf --tmux 90%,80% +m | sed 's#^ *origin/##' | string trim)
    if test -z "$branch"
        return
    end

    set -l res (git stash 2>&1)
    git switch $branch
    if not string match -q "No local changes*" $res
        git stash pop
    end
    commandline -f repaint
end
