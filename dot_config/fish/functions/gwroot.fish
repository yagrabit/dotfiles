# Git worktreeの親ディレクトリ（.git共有元）へ移動
function gwroot -d 'Worktreeの親ディレクトリへ移動'
    set -l git_common_dir (git rev-parse --git-common-dir 2>/dev/null)
    if test -n "$git_common_dir"
        cd (dirname $git_common_dir)
    else
        echo "Gitリポジトリ外です"
    end
end
