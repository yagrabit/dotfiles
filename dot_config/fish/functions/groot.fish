# Gitリポジトリのルートディレクトリへ移動
function groot -d 'Gitリポジトリルートへ移動'
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$root"
        cd $root
    else
        echo "Gitリポジトリ外です"
    end
end
