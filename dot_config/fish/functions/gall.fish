function gall
    # 渡された引数が空なら使い方を表示
    if not set -q argv[1]
        echo "Usage: gall <files...>"
        echo "Example: gall *.js src/*.css"
        return 1
    end
    begin
        echo "## Source Code Context"
        echo "---"

        for file in $argv
            # ディレクトリはスキップ、存在するファイルのみ処理
            if test -f "$file"
                echo "### File: $file"
                echo '```'
                cat "$file"
                echo '```'
                echo ""
            end
        end
    end | pbcopy
    echo "✅ "(count $argv)" 個のファイルをGemini用フォーマットでコピーしました！"
    echo "💡 ブラウザで Command + V してください。"
end
