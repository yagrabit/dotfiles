# git stashをfzfで管理（apply/pop/drop/ファイル選択checkout）
function fstash -d 'git stashをfzfで管理'
    if test (git stash list | count) -eq 0
        echo "stashが空です"
        return
    end

    set -l out (git stash list | while read -l line
        set -l idx (string replace -r 'stash@\{(\d+)\}.*' '$1' $line)
        echo "$idx $line"
    end | fzf --tmux 90%,80% \
        --header '⏎:apply  ^P:pop  ^D:drop  ^F:ファイル選択checkout' \
        --expect 'ctrl-p,ctrl-d,ctrl-f' \
        --preview 'git stash show -p --color=always stash@\{$(echo {} | cut -d" " -f1)\}' \
        --preview-window 'right:60%')

    if test -z "$out"
        commandline -f repaint
        return
    end

    set -l key $out[1]
    set -l selection $out[2]

    if test -z "$selection"
        commandline -f repaint
        return
    end

    set -l idx (echo $selection | cut -d' ' -f1)
    set -l stash_ref "stash@{$idx}"

    switch $key
        case 'ctrl-p'
            git stash pop $stash_ref
        case 'ctrl-d'
            git stash drop $stash_ref
        case 'ctrl-f'
            set -l files (git stash show --name-only $stash_ref | \
                fzf --tmux 90%,80% -m \
                    --header '選択したファイルをstashからcheckout（TABで複数選択）' \
                    --preview "git diff --color=always $stash_ref -- {}")
            if test -n "$files"
                for file in $files
                    git checkout $stash_ref -- $file
                end
            end
        case '*'
            git stash apply $stash_ref
    end

    commandline -f repaint
end
