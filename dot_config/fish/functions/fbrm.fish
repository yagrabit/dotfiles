# リモートブランチをfzfで選択してcheckout
function fbrm -d 'リモートブランチをfzfで切り替え'
    set -l branch (git branch -r | fzf --tmux 90%,80% +m | sed 's#^ *origin/##' | string trim)
    if test -z "$branch"
        return
    end

    # stash前後のカウントで判定（locale非依存）
    set -l stash_count_before (git stash list 2>/dev/null | count)
    git stash 2>/dev/null
    git switch $branch
    set -l stash_count_after (git stash list 2>/dev/null | count)
    if test "$stash_count_after" -gt "$stash_count_before"
        git stash pop
    end
    commandline -f repaint
end
