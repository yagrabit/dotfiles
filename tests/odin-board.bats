#!/usr/bin/env bats
# odin-board テスト

SCRIPT="$BATS_TEST_DIRNAME/../dot_config/tmux/private_executable_odin-board.sh"

setup() {
    export ODIN_BOARD_DIR="$(mktemp -d)"
    export TASKS_DIR="${ODIN_BOARD_DIR}/tasks"
    export ARCHIVE_DIR="${ODIN_BOARD_DIR}/archive"
    mkdir -p "$TASKS_DIR" "$ARCHIVE_DIR"
}

teardown() {
    rm -rf "$ODIN_BOARD_DIR"
}

# テスト用タスクファイルを作成するヘルパー
create_test_task() {
    local id="${1:-20260402-2030-a1b2}"
    local file="${TASKS_DIR}/${id}.md"
    cat > "$file" <<EOF
---
id: ${id}
title: "テストタスク"
status: inbox
priority: medium
assignee: human
odin-pane: ""
project: "yagrabit/myapp"
branch: "fix/GH-123-error-handling"
created: "2026-04-02T20:30:00"
updated: "2026-04-02T20:30:00"
tags: [pr, fix]
---

テスト用の説明文です。
複数行のボディを持つタスク。
EOF
    echo "$file"
}

# --- init テスト ---

@test "init: ディレクトリが作成される" {
    rm -rf "$ODIN_BOARD_DIR"
    run bash "$SCRIPT" init
    [ "$status" -eq 0 ]
    [ -d "$TASKS_DIR" ]
    [ -d "$ARCHIVE_DIR" ]
    [[ "$output" == *"初期化しました"* ]]
}

@test "init: 既存ディレクトリがあれば何もしない" {
    run bash "$SCRIPT" init
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# --- read_field テスト ---

@test "read_field: idを読み取れる" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' id"
    [ "$status" -eq 0 ]
    [ "$output" = "20260402-2030-a1b2" ]
}

@test "read_field: titleを読み取れる（クォート除去）" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' title"
    [ "$status" -eq 0 ]
    [ "$output" = "テストタスク" ]
}

@test "read_field: statusを読み取れる" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' status"
    [ "$status" -eq 0 ]
    [ "$output" = "inbox" ]
}

@test "read_field: priorityを読み取れる" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' priority"
    [ "$status" -eq 0 ]
    [ "$output" = "medium" ]
}

@test "read_field: assigneeを読み取れる" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' assignee"
    [ "$status" -eq 0 ]
    [ "$output" = "human" ]
}

@test "read_field: odin-paneを読み取れる（空文字）" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' odin-pane"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "read_field: projectを読み取れる（クォート除去）" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' project"
    [ "$status" -eq 0 ]
    [ "$output" = "yagrabit/myapp" ]
}

@test "read_field: branchを読み取れる（クォート除去）" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' branch"
    [ "$status" -eq 0 ]
    [ "$output" = "fix/GH-123-error-handling" ]
}

@test "read_field: createdを読み取れる" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' created"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-04-02T20:30:00" ]
}

@test "read_field: tagsを読み取れる" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' tags"
    [ "$status" -eq 0 ]
    [ "$output" = "[pr, fix]" ]
}

# --- write_field テスト ---

@test "write_field: statusを更新できる" {
    local file
    file=$(create_test_task)
    bash -c "source '$SCRIPT' 2>/dev/null; write_field '$file' status human"
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' status"
    [ "$output" = "human" ]
}

@test "write_field: titleを更新できる（クォート付き）" {
    local file
    file=$(create_test_task)
    bash -c "source '$SCRIPT' 2>/dev/null; write_field '$file' title '新しいタイトル'"
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' title"
    [ "$output" = "新しいタイトル" ]
}

@test "write_field: priorityを更新できる" {
    local file
    file=$(create_test_task)
    bash -c "source '$SCRIPT' 2>/dev/null; write_field '$file' priority high"
    run bash -c "source '$SCRIPT' 2>/dev/null; read_field '$file' priority"
    [ "$output" = "high" ]
}

# --- read_body テスト ---

@test "read_body: ボディ部分を取得できる" {
    local file
    file=$(create_test_task)
    run bash -c "source '$SCRIPT' 2>/dev/null; read_body '$file'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"テスト用の説明文です"* ]]
    [[ "$output" == *"複数行のボディ"* ]]
}

# --- generate_id テスト ---

@test "generate_id: YYYYMMDD-HHMM-XXXX形式のIDが生成される" {
    run bash -c "source '$SCRIPT' 2>/dev/null; generate_id"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{8}-[0-9]{4}-[0-9a-f]{4}$ ]]
}

@test "generate_id: 2回実行すると異なるIDが生成される" {
    local id1 id2
    id1=$(bash -c "source '$SCRIPT' 2>/dev/null; generate_id")
    id2=$(bash -c "source '$SCRIPT' 2>/dev/null; generate_id")
    [ "$id1" != "$id2" ]
}

# --- find_task テスト ---

@test "find_task: 完全IDでタスクを見つけられる" {
    create_test_task "20260402-2030-a1b2"
    run bash -c "source '$SCRIPT' 2>/dev/null; find_task '20260402-2030-a1b2'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"20260402-2030-a1b2.md" ]]
}

@test "find_task: 短縮IDでタスクを見つけられる" {
    create_test_task "20260402-2030-a1b2"
    run bash -c "source '$SCRIPT' 2>/dev/null; find_task 'a1b2'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"20260402-2030-a1b2.md" ]]
}

@test "find_task: 存在しないIDでエラーになる" {
    run bash -c "source '$SCRIPT' 2>/dev/null; find_task 'xxxx'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"見つかりません"* ]]
}

# --- usage テスト ---

# --- add テスト ---

@test "add: タスクファイルが生成される" {
    run bash "$SCRIPT" add "テスト追加"
    [ "$status" -eq 0 ]
    [[ "$output" == *"タスクを追加しました"* ]]
    # タスクファイルが存在する
    local count
    count=$(find "$TASKS_DIR" -name "*.md" -type f | wc -l | tr -d ' ')
    [ "$count" -eq 1 ]
}

@test "add: デフォルト値が正しい（status=inbox, assignee=human, priority=medium）" {
    bash "$SCRIPT" add "デフォルトテスト"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    run bash -c "source '$SCRIPT'; read_field '$file' status"
    [ "$output" = "inbox" ]
    run bash -c "source '$SCRIPT'; read_field '$file' assignee"
    [ "$output" = "human" ]
    run bash -c "source '$SCRIPT'; read_field '$file' priority"
    [ "$output" = "medium" ]
}

@test "add: オプション指定（-p, --pri, -t）が反映される" {
    bash "$SCRIPT" add "オプションテスト" -p "owner/repo" --pri high -t "tag1,tag2"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    run bash -c "source '$SCRIPT'; read_field '$file' project"
    [ "$output" = "owner/repo" ]
    run bash -c "source '$SCRIPT'; read_field '$file' priority"
    [ "$output" = "high" ]
    run bash -c "source '$SCRIPT'; read_field '$file' tags"
    [ "$output" = "[tag1,tag2]" ]
}

@test "add: タイトル未指定でエラーになる" {
    run bash "$SCRIPT" add
    [ "$status" -eq 1 ]
    [[ "$output" == *"タイトルを指定"* ]]
}

@test "add: ID形式がYYYYMMDD-HHMM-XXXXパターン" {
    bash "$SCRIPT" add "ID確認"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    local id
    id=$(bash -c "source '$SCRIPT'; read_field '$file' id")
    [[ "$id" =~ ^[0-9]{8}-[0-9]{4}-[0-9a-f]{4}$ ]]
}

# --- memo テスト ---

@test "memo: 生テキストからタスクが生成される" {
    run bash "$SCRIPT" memo "これはメモテスト"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inboxに追加しました"* ]]
    local count
    count=$(find "$TASKS_DIR" -name "*.md" -type f | wc -l | tr -d ' ')
    [ "$count" -eq 1 ]
}

@test "memo: 長いテキストのタイトルが30文字に切り詰められる" {
    bash "$SCRIPT" memo "これは非常に長いテキストで三十文字を超えるメモのテストです確認"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    local title
    title=$(bash -c "source '$SCRIPT'; read_field '$file' title")
    # タイトルが30文字 + "..." で切り詰められていること
    [[ "$title" == *"..."* ]]
}

@test "memo: ボディに全文が保存される" {
    local text="これはボディ全文保存のテスト"
    bash "$SCRIPT" memo "$text"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    run bash -c "source '$SCRIPT'; read_body '$file'"
    [[ "$output" == *"$text"* ]]
}

@test "memo: テキスト未指定でエラーになる" {
    run bash "$SCRIPT" memo
    [ "$status" -eq 1 ]
    [[ "$output" == *"テキストを指定"* ]]
}

# --- list テスト ---

@test "list: 全タスクを表示する" {
    bash "$SCRIPT" add "タスク1" -p "owner/repo"
    bash "$SCRIPT" add "タスク2" -p "owner/repo"
    run bash "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"タスク1"* ]]
    [[ "$output" == *"タスク2"* ]]
}

@test "list: ステータスフィルタが動作する" {
    bash "$SCRIPT" add "inboxタスク"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    local id
    id=$(bash -c "source '$SCRIPT'; read_field '$file' id")
    bash "$SCRIPT" move "$id" human
    bash "$SCRIPT" add "もう1つ"

    run bash "$SCRIPT" list --status human
    [ "$status" -eq 0 ]
    [[ "$output" == *"inboxタスク"* ]]
    [[ "$output" != *"もう1つ"* ]]
}

@test "list: タスクがない場合のメッセージ" {
    run bash "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"タスクがありません"* ]]
}

# --- move テスト ---

@test "move: ステータスが変更される" {
    bash "$SCRIPT" add "移動テスト"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    local id
    id=$(bash -c "source '$SCRIPT'; read_field '$file' id")

    run bash "$SCRIPT" move "$id" human
    [ "$status" -eq 0 ]
    [[ "$output" == *"human に移動"* ]]

    local new_status
    new_status=$(bash -c "source '$SCRIPT'; read_field '$file' status")
    [ "$new_status" = "human" ]
}

@test "move: 不正なステータスでエラーになる" {
    bash "$SCRIPT" add "エラーテスト"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    local id
    id=$(bash -c "source '$SCRIPT'; read_field '$file' id")

    run bash "$SCRIPT" move "$id" invalid
    [ "$status" -eq 1 ]
    [[ "$output" == *"不正なステータス"* ]]
}

# --- done テスト ---

@test "done: ステータスがdoneに変わる" {
    bash "$SCRIPT" add "完了テスト"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    local id
    id=$(bash -c "source '$SCRIPT'; read_field '$file' id")

    run bash "$SCRIPT" done "$id"
    [ "$status" -eq 0 ]

    local new_status
    new_status=$(bash -c "source '$SCRIPT'; read_field '$file' status")
    [ "$new_status" = "done" ]
}

# --- rm テスト ---

@test "rm: タスクファイルが削除される" {
    bash "$SCRIPT" add "削除テスト"
    local file
    file=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    local id
    id=$(bash -c "source '$SCRIPT'; read_field '$file' id")

    run bash "$SCRIPT" rm "$id"
    [ "$status" -eq 0 ]
    [[ "$output" == *"削除しました"* ]]
    [ ! -f "$file" ]
}

# --- status テスト ---

@test "status: ステータス別カウントを出力する" {
    bash "$SCRIPT" add "タスク1"
    bash "$SCRIPT" add "タスク2"
    local file1 file2
    file1=$(find "$TASKS_DIR" -name "*.md" -type f | head -1)
    local id1
    id1=$(bash -c "source '$SCRIPT'; read_field '$file1' id")
    bash "$SCRIPT" move "$id1" human

    run bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"H:1"* ]]
    [[ "$output" == *"I:1"* ]]
}

@test "status: タスクなしで空文字" {
    run bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# --- usage テスト ---

@test "help: ヘルプメッセージが表示される" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"odin-board"* ]]
    [[ "$output" == *"add"* ]]
    [[ "$output" == *"dispatch"* ]]
}

# --- docs ヘルパー テスト ---

@test "docs: _docs_indexがindex.jsonのパスを返す" {
    source "$SCRIPT"
    run _docs_index "20260404-1200-a1b2"
    [ "$status" -eq 0 ]
    [[ "$output" == "${ODIN_BOARD_DIR}/docs/20260404-1200-a1b2/index.json" ]]
}

@test "docs: add_docでリンクが追加される" {
    source "$SCRIPT"
    add_doc "20260404-1200-a1b2" "API設計" "https://example.com/api" "web"
    local index="${DOCS_DIR}/20260404-1200-a1b2/index.json"
    [ -f "$index" ]
    run jq -r '.links[0].title' "$index"
    [ "$output" = "API設計" ]
    run jq -r '.links[0].url' "$index"
    [ "$output" = "https://example.com/api" ]
    run jq -r '.links[0].type' "$index"
    [ "$output" = "web" ]
    run jq -r '.links[0].saved_path' "$index"
    [ "$output" = "null" ]
}

@test "docs: add_docで重複URLはスキップされる" {
    source "$SCRIPT"
    add_doc "20260404-1200-a1b2" "API設計" "https://example.com/api" "web"
    add_doc "20260404-1200-a1b2" "API設計v2" "https://example.com/api" "web"
    local index="${DOCS_DIR}/20260404-1200-a1b2/index.json"
    run jq '.links | length' "$index"
    [ "$output" = "1" ]
}

@test "docs: add_docでtype省略時はwebがデフォルト" {
    source "$SCRIPT"
    add_doc "20260404-1200-a1b2" "テスト" "https://example.com"
    local index="${DOCS_DIR}/20260404-1200-a1b2/index.json"
    run jq -r '.links[0].type' "$index"
    [ "$output" = "web" ]
}

@test "docs: rm_docでURLの部分一致で削除される" {
    source "$SCRIPT"
    add_doc "20260404-1200-a1b2" "API設計" "https://example.com/api" "web"
    add_doc "20260404-1200-a1b2" "認証仕様" "jira:VIV-123" "jira"
    rm_doc "20260404-1200-a1b2" "example.com"
    local index="${DOCS_DIR}/20260404-1200-a1b2/index.json"
    run jq '.links | length' "$index"
    [ "$output" = "1" ]
    run jq -r '.links[0].title' "$index"
    [ "$output" = "認証仕様" ]
}

@test "docs: rm_docでタイトルの部分一致で削除される" {
    source "$SCRIPT"
    add_doc "20260404-1200-a1b2" "API設計" "https://example.com/api" "web"
    rm_doc "20260404-1200-a1b2" "API設計"
    local index="${DOCS_DIR}/20260404-1200-a1b2/index.json"
    run jq '.links | length' "$index"
    [ "$output" = "0" ]
}

@test "docs: rm_docでindex.jsonが存在しない場合エラー" {
    source "$SCRIPT"
    run rm_doc "nonexistent" "query"
    [ "$status" -eq 1 ]
}

@test "docs: read_docsがTSV形式でリンクを出力する" {
    source "$SCRIPT"
    add_doc "20260404-1200-a1b2" "API設計" "https://example.com/api" "web"
    add_doc "20260404-1200-a1b2" "認証仕様" "jira:VIV-123" "jira"
    run read_docs "20260404-1200-a1b2"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "${lines[0]}" == *"API設計"* ]]
    [[ "${lines[0]}" == *"https://example.com/api"* ]]
    [[ "${lines[1]}" == *"認証仕様"* ]]
    [[ "${lines[1]}" == *"jira:VIV-123"* ]]
}

@test "docs: read_docsでindex.jsonが存在しない場合は空出力" {
    source "$SCRIPT"
    run read_docs "nonexistent"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "docs: update_saved_pathでsaved_pathが更新される" {
    source "$SCRIPT"
    add_doc "20260404-1200-a1b2" "API設計" "https://example.com/api" "web"
    update_saved_path "20260404-1200-a1b2" "https://example.com/api" "web-example-com-20260404-1200.md"
    local index="${DOCS_DIR}/20260404-1200-a1b2/index.json"
    run jq -r '.links[0].saved_path' "$index"
    [ "$output" = "web-example-com-20260404-1200.md" ]
}
