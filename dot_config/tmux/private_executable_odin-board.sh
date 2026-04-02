#!/usr/bin/env bash
# odin-board: タスク管理カンバンシステム
# 人間のタスクとodin（Claude Code）のタスクを一元管理する
set -euo pipefail

# --- 定数 ---
BOARD_DIR="${ODIN_BOARD_DIR:-${HOME}/.local/share/odin-board}"
TASKS_DIR="${BOARD_DIR}/tasks"
ARCHIVE_DIR="${BOARD_DIR}/archive"

# --- ヘルパー関数 ---

# ディレクトリの初期化（存在しなければ作成）
ensure_init() {
    if [[ ! -d "$TASKS_DIR" ]]; then
        mkdir -p "$TASKS_DIR"
        mkdir -p "$ARCHIVE_DIR"
        echo "odin-boardを初期化しました: ${TASKS_DIR}"
    fi
}

# タスクIDの生成（YYYYMMDD-HHMM-XXXX形式）
generate_id() {
    echo "$(date '+%Y%m%d-%H%M')-$(openssl rand -hex 2)"
}

# YAML FMから指定フィールドの値を読み取る
# 使い方: read_field <file> <field>
read_field() {
    local file="$1"
    local field="$2"
    # FMの---で囲まれた範囲内から、指定フィールドの値を取得
    # LC_ALL=Cで不正バイト列によるsedエラーを防ぐ
    LC_ALL=C sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | LC_ALL=C sed "s/^${field}: *//" | LC_ALL=C sed 's/^"//' | LC_ALL=C sed 's/"$//'
}

# YAML FMの指定フィールドを更新する
# 使い方: write_field <file> <field> <value>
write_field() {
    local file="$1"
    local field="$2"
    local value="$3"
    # フィールドが文字列値の場合はダブルクォートで囲む
    # tags（配列）やステータス等のシンプルな値はそのまま
    if [[ "$field" == "title" || "$field" == "created" || "$field" == "updated" || "$field" == "project" || "$field" == "branch" ]]; then
        LC_ALL=C sed -i '' "s|^${field}: .*|${field}: \"${value}\"|" "$file"
    else
        LC_ALL=C sed -i '' "s|^${field}: .*|${field}: ${value}|" "$file"
    fi
}

# FMの---以降のボディ部分を取得する
# 使い方: read_body <file>
read_body() {
    local file="$1"
    # 2つ目の---以降を出力（先頭の空行を除く）
    awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$file"
}

# 短縮IDまたは完全IDからタスクファイルパスを解決する
# 使い方: find_task <id>
find_task() {
    local id="$1"
    local matches=()

    # 完全ID一致を先に試す
    if [[ -f "${TASKS_DIR}/${id}.md" ]]; then
        echo "${TASKS_DIR}/${id}.md"
        return 0
    fi

    # 短縮ID（末尾4文字）で検索
    while IFS= read -r f; do
        matches+=("$f")
    done < <(find "$TASKS_DIR" -name "*${id}.md" -type f 2>/dev/null)

    if [[ ${#matches[@]} -eq 0 ]]; then
        echo "エラー: タスク ${id} が見つかりません" >&2
        return 1
    elif [[ ${#matches[@]} -gt 1 ]]; then
        echo "エラー: ID ${id} は複数のタスクにマッチします。完全IDを指定してください" >&2
        return 1
    fi

    echo "${matches[0]}"
}

# ghqプロジェクトの自動検出（pwdとghq listの最長前方一致）
# 使い方: detect_project [dir]
detect_project() {
    local dir="${1:-$(pwd)}"
    if ! command -v ghq &>/dev/null; then
        return 0
    fi
    local best=""
    local best_len=0
    while IFS= read -r repo_path; do
        # dirがrepo_pathから始まるか確認（前方一致）
        if [[ "$dir" == "$repo_path"* ]]; then
            local len=${#repo_path}
            if (( len > best_len )); then
                best="$repo_path"
                best_len=$len
            fi
        fi
    done < <(ghq list --full-path 2>/dev/null)
    if [[ -n "$best" ]]; then
        # owner/repo形式に変換（github.com/以降を取得）
        echo "$best" | sed 's|.*/github\.com/||'
    fi
}

# 現在のgitブランチを自動検出
detect_branch() {
    local dir="${1:-$(pwd)}"
    git -C "$dir" branch --show-current 2>/dev/null || true
}

# タスクMarkdownファイルを生成する
# 使い方: create_task <id> <title> <body> <status> <priority> <assignee> <project> <branch> <tags>
create_task() {
    local id="$1" title="$2" body="$3" status="$4" priority="$5"
    local assignee="$6" project="$7" branch="$8" tags="$9"
    local now
    now="$(date '+%Y-%m-%dT%H:%M:%S')"
    local file="${TASKS_DIR}/${id}.md"

    cat > "$file" <<EOF
---
id: ${id}
title: "${title}"
status: ${status}
priority: ${priority}
assignee: ${assignee}
odin-pane: ""
project: "${project}"
branch: "${branch}"
created: "${now}"
updated: "${now}"
tags: [${tags}]
---

${body}
EOF
    echo "$file"
}

# addサブコマンド: タスクを追加する
cmd_add() {
    ensure_init
    local title="" body="" project="" branch="" priority="medium" tags=""

    # 第1引数がタイトル
    if [[ $# -gt 0 && "$1" != -* ]]; then
        title="$1"
        shift
    fi

    # オプション解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p) project="$2"; shift 2 ;;
            -b) branch="$2"; shift 2 ;;
            --pri) priority="$2"; shift 2 ;;
            -t) tags="$2"; shift 2 ;;
            --body) body="$2"; shift 2 ;;
            *) title="${title:-$1}"; shift ;;
        esac
    done

    if [[ -z "$title" ]]; then
        echo "エラー: タイトルを指定してください" >&2
        return 1
    fi

    # プロジェクト・ブランチの自動検出
    [[ -z "$project" ]] && project="$(detect_project)"
    [[ -z "$branch" ]] && branch="$(detect_branch)"

    local id
    id="$(generate_id)"
    local file
    file="$(create_task "$id" "$title" "$body" "inbox" "$priority" "human" "$project" "$branch" "$tags")"
    echo "タスクを追加しました: #${id##*-} ${title}"
    echo "$file"
}

# memoサブコマンド: 生テキストをInboxに投入する
cmd_memo() {
    ensure_init
    local text="$*"

    if [[ -z "$text" ]]; then
        echo "エラー: テキストを指定してください" >&2
        return 1
    fi

    # タイトル: 先頭30文字（改行除去）
    local title
    title="$(echo "$text" | tr '\n' ' ' | cut -c1-30)"
    # 30文字超えの場合は末尾に...を追加
    if [[ ${#text} -gt 30 ]]; then
        title="${title}..."
    fi

    local id
    id="$(generate_id)"
    local file
    file="$(create_task "$id" "$title" "$text" "inbox" "medium" "human" "" "" "")"
    echo "メモをInboxに追加しました: #${id##*-} ${title}"
    echo "$file"
}

# listサブコマンド: タスク一覧を表示する
cmd_list() {
    ensure_init
    local filter_status="" filter_project="" filter_tag=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status) filter_status="$2"; shift 2 ;;
            --project) filter_project="$2"; shift 2 ;;
            --tag) filter_tag="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local found=0
    for file in "$TASKS_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        local s p t id title pri
        s="$(read_field "$file" status)"
        p="$(read_field "$file" project)"
        t="$(read_field "$file" tags)"
        id="$(read_field "$file" id)"
        title="$(read_field "$file" title)"
        pri="$(read_field "$file" priority)"

        # フィルタ適用
        [[ -n "$filter_status" && "$s" != "$filter_status" ]] && continue
        [[ -n "$filter_project" && "$p" != *"$filter_project"* ]] && continue
        [[ -n "$filter_tag" && "$t" != *"$filter_tag"* ]] && continue

        printf "%-5s #%-4s %-6s %s [%s]\n" "[$s]" "${id##*-}" "($pri)" "$title" "$p"
        found=1
    done

    if [[ $found -eq 0 ]]; then
        echo "タスクがありません"
    fi
}

# showサブコマンド: タスクの詳細を表示する
cmd_show() {
    local id="${1:?エラー: IDを指定してください}"
    local file
    file="$(find_task "$id")"
    if command -v glow &>/dev/null; then
        glow -s dark "$file"
    else
        cat "$file"
    fi
}

# moveサブコマンド: タスクのステータスを変更する
cmd_move() {
    local id="${1:?エラー: IDを指定してください}"
    local new_status="${2:?エラー: ステータスを指定してください（inbox/human/odin/done）}"
    local file
    file="$(find_task "$id")"

    # ステータスの妥当性チェック
    case "$new_status" in
        inbox|human|odin|done) ;;
        *) echo "エラー: 不正なステータス '${new_status}'（inbox/human/odin/done）" >&2; return 1 ;;
    esac

    write_field "$file" "status" "$new_status"
    write_field "$file" "updated" "$(date '+%Y-%m-%dT%H:%M:%S')"
    local title
    title="$(read_field "$file" title)"
    echo "#${id##*-} を ${new_status} に移動しました: ${title}"
}

# doneサブコマンド: タスクを完了にする
cmd_done() {
    local id="${1:?エラー: IDを指定してください}"
    cmd_move "$id" "done"
}

# rmサブコマンド: タスクを削除する
cmd_rm() {
    local id="${1:?エラー: IDを指定してください}"
    local file
    file="$(find_task "$id")"
    local title
    title="$(read_field "$file" title)"
    rm "$file"
    echo "タスクを削除しました: #${id##*-} ${title}"
}

# editサブコマンド: タスクを$EDITORで編集する
cmd_edit() {
    local id="${1:?エラー: IDを指定してください}"
    local file
    file="$(find_task "$id")"
    "${EDITOR:-vi}" "$file"
}

# statusサブコマンド: ステータスバー用のサマリー文字列を出力する
cmd_status() {
    ensure_init
    local h=0 o=0 i=0

    for file in "$TASKS_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        local s
        s="$(read_field "$file" status)"
        case "$s" in
            human) h=$((h + 1)) ;;
            odin)
                # odinペインの孤児検出
                local pane
                pane="$(read_field "$file" odin-pane)"
                if [[ -n "$pane" ]] && ! tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q "^${pane}$"; then
                    # ペインが消滅している場合、humanに戻す
                    write_field "$file" "status" "human"
                    write_field "$file" "odin-pane" '""'
                    write_field "$file" "updated" "$(date '+%Y-%m-%dT%H:%M:%S')"
                    h=$((h + 1))
                else
                    o=$((o + 1))
                fi
                ;;
            inbox) i=$((i + 1)) ;;
        esac
    done

    # 完了後30日経過したタスクをアーカイブ
    _archive_old_tasks

    # タスクがなければ空文字
    if (( h + o + i == 0 )); then
        return 0
    fi

    printf "H:%d O:%d I:%d" "$h" "$o" "$i"
}

# 完了後30日経過したタスクをarchiveに移動する
_archive_old_tasks() {
    local now_epoch
    now_epoch="$(date '+%s')"
    local threshold=$((30 * 86400))

    for file in "$TASKS_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        local s
        s="$(read_field "$file" status)"
        [[ "$s" != "done" ]] && continue

        local updated
        updated="$(read_field "$file" updated)"
        # ISO 8601形式をepochに変換（macOS date対応）
        local updated_epoch
        updated_epoch="$(date -j -f '%Y-%m-%dT%H:%M:%S' "$updated" '+%s' 2>/dev/null || echo 0)"

        if (( now_epoch - updated_epoch > threshold )); then
            mkdir -p "$ARCHIVE_DIR"
            mv "$file" "$ARCHIVE_DIR/"
        fi
    done
}

# --- TUI関連 (Wave 4) ---

# ステータスアイコンを返す
_status_icon() {
    case "$1" in
        inbox) echo "○" ;;
        odin)  echo "●" ;;
        human) echo "★" ;;
        done)  echo "✓" ;;
        *)     echo "?" ;;
    esac
}

# 優先度アイコンを返す
_priority_icon() {
    case "$1" in
        high)   echo "!!!" ;;
        medium) echo "!!" ;;
        low)    echo "!" ;;
        *)      echo "" ;;
    esac
}

# ソートキーを返す（odin=1, inbox=2, human=3, done=4）
_sort_key() {
    case "$1" in
        odin)  echo "1" ;;
        inbox) echo "2" ;;
        human) echo "3" ;;
        done)  echo "4" ;;
        *)     echo "9" ;;
    esac
}

# カンバンヘッダーを生成する
board_header() {
    local i=0 h=0 o=0 d=0
    for file in "$TASKS_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        local s
        s="$(read_field "$file" status)"
        case "$s" in
            inbox) i=$((i + 1)) ;;
            human) h=$((h + 1)) ;;
            odin)  o=$((o + 1)) ;;
            done)  d=$((d + 1)) ;;
        esac
    done
    printf "Inbox(%d)  Human(%d)  Odin(%d)  Done(%d)\n" "$i" "$h" "$o" "$d"
    echo "[d]委譲 [m]移動 [a]追加 [x]完了 [D]削除 [e]編集 [R]更新 [q]閉じる"
}

# タスク一覧をfzf用のフォーマットで生成する
generate_list() {
    ensure_init
    for file in "$TASKS_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        local id s pri title proj icon pri_icon sk short_proj
        id="$(read_field "$file" id)"
        s="$(read_field "$file" status)"
        pri="$(read_field "$file" priority)"
        title="$(read_field "$file" title)"
        proj="$(read_field "$file" project)"
        icon="$(_status_icon "$s")"
        pri_icon="$(_priority_icon "$pri")"
        sk="$(_sort_key "$s")"
        # プロジェクト名を短縮（owner/repoのrepo部分のみ���
        short_proj="${proj##*/}"

        # sort_key\t表示テキスト\tid
        printf "%s\t%s #%s [%s]  %s  %s  %s\t%s\n" \
            "$sk" "$icon" "${id##*-}" "$s" "$title" "$pri_icon" "$short_proj" "$id"
    done
}

# tuiサブコマンド: fzfベースのカンバンTUIを起動する
cmd_tui() {
    ensure_init
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

    # --listモード: generate_listの出力を返す（自己reload用）
    if [[ "${1:-}" == "--list" ]]; then
        generate_list | sort -t$'\t' -k1,1 | sed 's/^[^\t]*\t//'
        return 0
    fi

    generate_list | sort -t$'\t' -k1,1 | sed 's/^[^\t]*\t//' | \
        fzf \
            --ansi \
            --header="$(board_header)" \
            --no-sort \
            --reverse \
            --delimiter=$'\t' \
            --with-nth=1 \
            --preview "glow -s dark ${TASKS_DIR}/{2}.md 2>/dev/null || cat ${TASKS_DIR}/{2}.md" \
            --preview-window "right:45%:wrap" \
            --bind "d:execute-silent(${script_path} dispatch {2})+reload(${script_path} tui --list)" \
            --bind "m:execute(${script_path} _move-interactive {2})+reload(${script_path} tui --list)" \
            --bind "a:execute(${script_path} _add-interactive)+reload(${script_path} tui --list)" \
            --bind "x:execute-silent(${script_path} done {2})+reload(${script_path} tui --list)" \
            --bind "e:execute(${script_path} edit {2})+reload(${script_path} tui --list)" \
            --bind "D:execute(${script_path} _rm-interactive {2})+reload(${script_path} tui --list)" \
            --bind "enter:execute(${script_path} _jump-or-show {2})" \
            --bind "R:reload(${script_path} tui --list)" \
        || true
}

# _move-interactive: TUI内でステータス移動先を選択する
cmd__move_interactive() {
    local id="${1:?}"
    local new_status
    new_status=$(printf "inbox\nhuman\nodin\ndone" | fzf --prompt="移動先> " --height=6 --reverse) || return 0
    cmd_move "$id" "$new_status"
}

# _add-interactive: TUI内でタスクを追加する（エディタベース）
# fzf execute内のreadはUTF-8マルチバイト文字を壊すため、エディタで入力する
cmd__add_interactive() {
    # 1. プロジェクト選択（ghq list + fzf）
    local project=""
    if command -v ghq &>/dev/null; then
        project=$(ghq list 2>/dev/null | fzf \
            --prompt="プロジェクト> " \
            --height=40% \
            --reverse \
            --header="プロジェクトを選択（Escでスキップ）" \
            --preview 'bat --color=always --style=header,grid --line-range :30 $(ghq root)/{}/README.md 2>/dev/null || eza --icons --tree --level=2 $(ghq root)/{}' \
        ) || true
    fi

    # 2. 優先度選択
    local priority=""
    priority=$(printf "medium\nhigh\nlow" | fzf \
        --prompt="優先度> " \
        --height=6 \
        --reverse \
        --header="優先度を選択" \
    ) || priority="medium"

    # 3. テンプレートファイルを作成し、エディタで入力
    local tmpfile
    tmpfile="$(mktemp /tmp/odin-board-add-XXXXXX.md)"
    cat > "$tmpfile" <<'TEMPLATE'

<!-- 1行目: タイトル（この行を消してタイトルを入力） -->
<!-- 4行目以降: 説明（不要ならそのまま保存） -->
TEMPLATE

    "${EDITOR:-vi}" "$tmpfile"

    # エディタ終了後: 1行目をタイトル、コメント行以外をボディとして読み取る
    local title body
    title="$(head -1 "$tmpfile" | sed 's/^[[:space:]]*//')"
    # コメント行とテンプレート行を除いたボディ
    body="$(sed '1d; /^<!-- .* -->$/d' "$tmpfile" | sed '/./,$!d')"
    rm -f "$tmpfile"

    # タイトルが空 or コメント行のままなら中止
    if [[ -z "$title" ]] || [[ "$title" == "<!--"* ]]; then
        echo "追加をキャンセルしました"
        return 0
    fi

    # 4. タスク追加
    local args=("$title" --pri "$priority")
    [[ -n "$project" ]] && args+=(-p "$project")
    [[ -n "$body" ]] && args+=(--body "$body")
    cmd_add "${args[@]}"
}

# _rm-interactive: TUI内でタスクを削除する（確認付き）
cmd__rm_interactive() {
    local id="${1:?}"
    local file
    file="$(find_task "$id")"
    local title
    title="$(read_field "$file" title)"
    local confirm
    confirm=$(printf "いいえ\nはい（削除する）" | fzf \
        --prompt="「${title}」を削除しますか？> " \
        --height=5 \
        --reverse \
    ) || return 0
    if [[ "$confirm" == "はい（削除する）" ]]; then
        cmd_rm "$id"
    fi
}

# _jump-or-show: odinペインにジャンプ or タスク詳細表示
cmd__jump_or_show() {
    local id="${1:?}"
    local file
    file="$(find_task "$id")"
    local pane
    pane="$(read_field "$file" odin-pane)"

    # odinペインが設定済みかつ存在する場合はジャンプ
    if [[ -n "$pane" ]] && tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q "^${pane}$"; then
        tmux switch-client -t "$pane" 2>/dev/null || true
        tmux select-window -t "$pane" 2>/dev/null || true
        tmux select-pane -t "$pane" 2>/dev/null || true
    else
        # タスク詳細を表示
        if command -v glow &>/dev/null; then
            glow -s dark "$file" -p
        else
            less "$file"
        fi
    fi
}

# --- Dispatch関連 (Wave 5) ---

# ghqプロジェクトパスを解決する
resolve_project_path() {
    local project="$1"
    if [[ -z "$project" ]]; then
        return 1
    fi
    ghq list --full-path 2>/dev/null | grep "/${project}$" | head -1
}

# dispatchサブコマンド: タスクをodinにディスパッチする
cmd_dispatch() {
    local id="${1:?エラー: IDを指定してくだ��い}"
    local file
    file="$(find_task "$id")"

    local title project branch
    title="$(read_field "$file" title)"
    project="$(read_field "$file" project)"
    branch="$(read_field "$file" branch)"
    local body
    body="$(read_body "$file")"

    # プロジェクトパスの解決
    local project_path=""
    if [[ -n "$project" ]]; then
        project_path="$(resolve_project_path "$project")"
    fi
    # プロジェクト未指定 or 解決失敗 → TUI内でghq選択を促す
    if [[ -z "$project_path" ]] && command -v ghq &>/dev/null; then
        local selected
        selected=$(ghq list 2>/dev/null | fzf \
            --prompt="プロジェクト> " \
            --height=40% \
            --reverse \
            --header="dispatch先を選択（Escで現在のディレクトリを使用）" \
            --preview 'bat --color=always --style=header,grid --line-range :30 $(ghq root)/{}/README.md 2>/dev/null || eza --icons --tree --level=2 $(ghq root)/{}' \
        ) || true
        if [[ -n "$selected" ]]; then
            project="$selected"
            project_path="$(ghq list --full-path 2>/dev/null | grep "/${selected}$" | head -1)"
            write_field "$file" "project" "$project"
        fi
    fi
    if [[ -z "$project_path" ]]; then
        project_path="$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || pwd)"
    fi

    # ワーキングツリーのダーティチェック
    if [[ -n "$branch" ]] && git -C "$project_path" status --porcelain 2>/dev/null | grep -q .; then
        echo "エラー: ${project_path} に未コミットの変更があります。stashまたはcommitしてからdispatchしてください" >&2
        return 1
    fi

    # ブランチ操作コマンドの決定
    local git_cmd=""
    if [[ -n "$branch" ]]; then
        if git -C "$project_path" branch --list "$branch" 2>/dev/null | grep -q .; then
            git_cmd="git checkout ${branch}"
        else
            git_cmd="git checkout -b ${branch}"
        fi
    fi

    # プロンプトファイルとランチャースクリプトを書き出し
    local promptfile="/tmp/odin-board-prompt-${id}.md"
    local launcher="/tmp/odin-board-launch-${id}.sh"

    cat > "$promptfile" <<PROMPT_EOF
/odin ${title}

${body}
PROMPT_EOF

    # ランチャースクリプト（変数展開をエスケープして安全に生成）
    cat > "$launcher" <<LAUNCH_SCRIPT
#!/usr/bin/env bash
cd "${project_path}" || exit 1
${git_cmd:+${git_cmd} || exit 1}
prompt=\$(cat "${promptfile}")
rm -f "${promptfile}" "${launcher}"
exec claude "\$prompt"
LAUNCH_SCRIPT
    chmod +x "$launcher"

    local new_pane
    new_pane="$(tmux split-window -h -p 50 -P -F '#{pane_id}' "${launcher}" 2>/dev/null)" || {
        echo "エラー: tmuxペインの作成に失敗しました" >&2
        rm -f "$launcher" "$promptfile"
        return 1
    }

    # ペイン起動成功: ステータス更新
    write_field "$file" "status" "odin"
    write_field "$file" "assignee" "odin"
    write_field "$file" "odin-pane" "$new_pane"
    write_field "$file" "updated" "$(date '+%Y-%m-%dT%H:%M:%S')"

    echo "#${id##*-} をodinにディスパッチしました: ${title}"
    echo "ペイン: ${new_pane} @ ${project_path}"
}

# 使い方を表示する
usage() {
    cat <<'EOF'
使い方: odin-board <subcommand> [args]

サブコマンド:
  init                           データディレクトリを初期化する
  add <title> [options]          タスクを追加する
  memo <text>                    生テキストをInboxに投入する
  list [options]                 タスク一覧を表示する
  show <id>                      タスクの詳細を表示する
  move <id> <status>             タスクのステータスを変更する
  edit <id>                      タスクを編集する
  dispatch <id>                  タスクをodinにディスパッチする
  done <id>                      タスクを完了にする
  rm <id>                        タスクを削除する
  tui                            カンバンTUIを起動する
  status                         ステータスバー用サマリーを出力する

オプション (add):
  -p <project>                   プロジェクト（owner/repo形式）
  -b <branch>                    ブランチ名
  --pri <high|medium|low>        優先度（デフォルト: medium）
  -t <tag1,tag2>                 タグ（カンマ区切り）
EOF
}

# --- サブコマンドルーター ---
# sourceされた場合は関数定義のみ提供し、ルーターを実行しない
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0 2>/dev/null || true
fi

cmd="${1:-}"
shift 2>/dev/null || true

case "$cmd" in
    init)
        ensure_init
        ;;
    add)
        cmd_add "$@"
        ;;
    memo)
        cmd_memo "$@"
        ;;
    list)
        cmd_list "$@"
        ;;
    show)
        cmd_show "$@"
        ;;
    move)
        cmd_move "$@"
        ;;
    done)
        cmd_done "$@"
        ;;
    rm)
        cmd_rm "$@"
        ;;
    edit)
        cmd_edit "$@"
        ;;
    status)
        cmd_status "$@"
        ;;
    tui)
        cmd_tui "$@"
        ;;
    dispatch)
        cmd_dispatch "$@"
        ;;
    _move-interactive)
        cmd__move_interactive "$@"
        ;;
    _add-interactive)
        cmd__add_interactive "$@"
        ;;
    _jump-or-show)
        cmd__jump_or_show "$@"
        ;;
    _rm-interactive)
        cmd__rm_interactive "$@"
        ;;
    -h|--help|help|"")
        usage
        ;;
    *)
        echo "エラー: 不明なサブコマンド '${cmd}'" >&2
        usage >&2
        exit 1
        ;;
esac
