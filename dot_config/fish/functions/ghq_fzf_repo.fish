# ghqリポジトリをfzfで選択して移動
function ghq_fzf_repo -d 'ghqリポジトリをfzfで選択して移動'
    set -l repo (ghq list | fzf --height 40% --layout=reverse --border --preview 'bat --color=always --style=header,grid --line-range :80 (ghq root)/{}/README.md 2>/dev/null; or eza --icons --tree --level=2 (ghq root)/{}')
    if test -n "$repo"
        cd (ghq root)/$repo
        commandline -f repaint
    end
end
