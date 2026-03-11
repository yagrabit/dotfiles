# ghq管理下の全リポジトリに対してgit pullを実行
function ghq_pull_all -d 'ghq管理下の全リポジトリをgit pull --ff-onlyで更新'
    set -l repos (ghq list --full-path)
    set -l total (count $repos)
    set -l success_count 0
    set -l fail_count 0
    set -l failed_repos

    echo "対象リポジトリ: $total 件"
    echo ""

    for repo in $repos
        # リポジトリ名を短縮表示（ghq root からの相対パス）
        set -l name (string replace (ghq root)/ '' $repo)
        printf '[%d/%d] %s ... ' (math $success_count + $fail_count + 1) $total $name

        # git pull --ff-only を実行（出力は抑制）
        if git -C $repo pull --ff-only 2>/dev/null 1>/dev/null
            set success_count (math $success_count + 1)
            set_color green
            echo "OK"
            set_color normal
        else
            set fail_count (math $fail_count + 1)
            set -a failed_repos $name
            set_color red
            echo "FAIL"
            set_color normal
        end
    end

    # サマリー表示
    echo ""
    echo "--- サマリー ---"
    set_color green
    echo "成功: $success_count 件"
    set_color normal
    if test $fail_count -gt 0
        set_color red
        echo "失敗: $fail_count 件"
        set_color normal
        echo ""
        echo "失敗したリポジトリ:"
        for name in $failed_repos
            set_color red
            echo "  - $name"
            set_color normal
        end
    else
        set_color green
        echo "失敗: 0 件"
        set_color normal
    end
end
