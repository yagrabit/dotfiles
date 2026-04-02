#!/usr/bin/env bash
# dotfiles メトリクス収集スクリプト
# git履歴から週次データを自動構築する
#
# 使い方:
#   ./scripts/collect-metrics.sh            # 全履歴を再構築 + 現在のメトリクス
#   ./scripts/collect-metrics.sh --current  # 現在のメトリクスのみ（履歴は既存を保持）
#
# 前提: jq, git

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
METRICS_FILE="$REPO_ROOT/docs/data/metrics.json"
MAX_HISTORY=52

# === 日付ユーティリティ（macOS/Linux互換） ===

add_days() {
  local base="$1" days="$2"
  if date -v+0d &>/dev/null 2>&1; then
    date -v+"${days}d" -j -f %Y-%m-%d "$base" +%Y-%m-%d
  else
    date -d "$base + $days days" +%Y-%m-%d
  fi
}

day_of_week() {
  local d="$1"
  if date -v+0d &>/dev/null 2>&1; then
    date -j -f %Y-%m-%d "$d" +%u
  else
    date -d "$d" +%u
  fi
}

# === git ls-tree ベースのメトリクス収集 ===

skills_json_at() {
  local commit="$1"
  local entries
  entries=$(git -C "$REPO_ROOT" ls-tree --name-only "$commit" -- dot_claude/skills/ 2>/dev/null | sed 's|.*/||') || true
  if [[ -z "$entries" ]]; then
    echo '{"total":0,"categories":{"think":0,"do":0,"talk":0,"auto":0,"learn":0,"design":0,"ux":0,"tooling":0}}'
    return
  fi
  local total think do_c talk auto learn design ux tooling
  total=$(echo "$entries" | wc -l | tr -d ' ')
  think=$(echo "$entries" | grep -c "^odin-think-" || true)
  do_c=$(echo "$entries" | grep -c "^odin-do-" || true)
  talk=$(echo "$entries" | grep -c "^odin-talk-" || true)
  auto=$(echo "$entries" | grep -c "^odin-auto-" || true)
  learn=$(echo "$entries" | grep -c "^odin-learn" || true)
  design=$(echo "$entries" | grep -c "^odin-design-" || true)
  ux=$(echo "$entries" | grep -c "^ux-" || true)
  tooling=$((total - think - do_c - talk - auto - learn - design - ux))
  [[ $tooling -lt 0 ]] && tooling=0
  echo "{\"total\":$total,\"categories\":{\"think\":$think,\"do\":$do_c,\"talk\":$talk,\"auto\":$auto,\"learn\":$learn,\"design\":$design,\"ux\":$ux,\"tooling\":$tooling}}"
}

count_at() {
  local commit="$1" path="$2" pattern="${3:-.}"
  git -C "$REPO_ROOT" ls-tree --name-only "$commit" -- "$path" 2>/dev/null \
    | sed 's|.*/||' | grep -c "$pattern" || echo 0
}

count_tree_at() {
  local commit="$1" pattern="$2"
  git -C "$REPO_ROOT" ls-tree -r --name-only "$commit" 2>/dev/null \
    | grep -cE "$pattern" || echo 0
}

commits_between() {
  local since="$1" until="$2"
  git -C "$REPO_ROOT" log --after="${since}T00:00:00" --before="${until}T23:59:59" \
    --oneline 2>/dev/null | wc -l | tr -d ' '
}

commit_types_between() {
  local since="$1" until="$2"
  local logs
  logs=$(git -C "$REPO_ROOT" log --after="${since}T00:00:00" --before="${until}T23:59:59" \
    --format="%s" 2>/dev/null) || true
  local feat=0 fix=0 chore=0 refactor=0 docs=0 other=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in
      feat*) feat=$((feat + 1)) ;;
      fix*) fix=$((fix + 1)) ;;
      chore*) chore=$((chore + 1)) ;;
      refactor*) refactor=$((refactor + 1)) ;;
      docs*) docs=$((docs + 1)) ;;
      *) other=$((other + 1)) ;;
    esac
  done <<< "$logs"
  echo "{\"feat\":$feat,\"fix\":$fix,\"chore\":$chore,\"refactor\":$refactor,\"docs\":$docs,\"other\":$other}"
}

# === 1週分のスナップショット ===

collect_week() {
  local week_start="$1" commit="$2"
  local week_end
  week_end=$(add_days "$week_start" 6)

  local sk_json hooks managed tmpl fish_c nvim_c commits_c types_c sk_total
  sk_json=$(skills_json_at "$commit")
  sk_total=$(echo "$sk_json" | jq '.total')
  hooks=$(count_at "$commit" "dot_claude/hooks/" "^private_executable_")
  managed=$(count_tree_at "$commit" "^(dot_|private_|run_)")
  tmpl=$(count_tree_at "$commit" "\.tmpl$")
  fish_c=$(count_at "$commit" "dot_config/fish/functions/" "\.fish$")
  nvim_c=$(count_at "$commit" "dot_config/nvim/lua/plugins/" "\.lua$")
  commits_c=$(commits_between "$week_start" "$week_end")
  types_c=$(commit_types_between "$week_start" "$week_end")

  jq -n \
    --arg date "$week_start" \
    --argjson st "$sk_total" --argjson hooks "$hooks" \
    --argjson managed "$managed" --argjson tmpl "$tmpl" \
    --argjson fish "$fish_c" --argjson nvim "$nvim_c" \
    --argjson commits "$commits_c" --argjson types "$types_c" \
    '{date:$date, harness_score:null, skills_total:$st, hooks:$hooks,
      managed_files:$managed, template_files:$tmpl, fish_functions:$fish,
      nvim_plugins:$nvim, commits:$commits, commit_types:$types}'
}

# === git履歴から全週次データを構築 ===

build_history() {
  echo "--- git履歴からデータを構築中 ---" >&2

  local first_date today cursor
  first_date=$(git -C "$REPO_ROOT" log --reverse --format=%ad --date=short | head -1)
  today=$(date +%Y-%m-%d)

  # 最初の月曜に揃える
  cursor="$first_date"
  while [[ "$(day_of_week "$cursor")" != "1" ]]; do
    cursor=$(add_days "$cursor" 1)
  done

  local entries="[]"
  local count=0

  while [[ ! "$cursor" > "$today" ]]; do
    local week_end commit
    week_end=$(add_days "$cursor" 6)
    commit=$(git -C "$REPO_ROOT" log --before="${week_end}T23:59:59" --format=%H -1 2>/dev/null) || true

    if [[ -n "$commit" ]]; then
      local entry
      entry=$(collect_week "$cursor" "$commit")
      entries=$(echo "$entries" | jq --argjson e "$entry" '. + [$e]')
      count=$((count + 1))
      echo "  $cursor: スキル=$(echo "$entry" | jq '.skills_total') コミット=$(echo "$entry" | jq '.commits')" >&2
    fi

    cursor=$(add_days "$cursor" 7)
  done

  echo "  ${count}週分のデータを構築" >&2
  echo "$entries" | jq --argjson max "$MAX_HISTORY" 'sort_by(.date) | .[-$max:]'
}

# === 現在のスナップショット（ツールバージョン含む） ===

collect_current() {
  local sk_json hooks agents managed tmpl fish_c nvim_c md_lines
  sk_json=$(skills_json_at HEAD)
  hooks=$(count_at HEAD "dot_claude/hooks/" "^private_executable_")
  agents=$(git -C "$REPO_ROOT" ls-tree --name-only HEAD -- "dot_claude/agents/" 2>/dev/null \
    | sed 's|.*/||' | grep -v "^common$" | grep -c . || echo 0)
  managed=$(count_tree_at HEAD "^(dot_|private_|run_)")
  tmpl=$(count_tree_at HEAD "\.tmpl$")
  fish_c=$(count_at HEAD "dot_config/fish/functions/" "\.fish$")
  nvim_c=$(count_at HEAD "dot_config/nvim/lua/plugins/" "\.lua$")
  md_lines=$(git -C "$REPO_ROOT" show HEAD:CLAUDE.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)

  local tools
  tools=$(jq -n \
    --arg git "$(git --version 2>/dev/null | sed 's/git version //' | sed 's/ .*//' || echo unknown)" \
    --arg fish "$(fish --version 2>/dev/null | sed 's/fish, version //' || echo unknown)" \
    --arg nvim "$(nvim --version 2>/dev/null | head -1 | sed 's/NVIM v//' || echo unknown)" \
    --arg chezmoi "$(chezmoi --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo unknown)" \
    --arg starship "$(starship --version 2>/dev/null | head -1 | sed 's/starship //' || echo unknown)" \
    --arg node "$(node --version 2>/dev/null | sed 's/v//' || echo unknown)" \
    --arg mise "$(mise --version 2>/dev/null | awk '{print $1}' || echo unknown)" \
    '{git:$git,fish:$fish,neovim:$nvim,chezmoi:$chezmoi,starship:$starship,node:$node,mise:$mise}')

  jq -n \
    --argjson skills "$sk_json" --argjson hooks "$hooks" \
    --argjson agents "$agents" --argjson managed "$managed" \
    --argjson tmpl "$tmpl" --argjson fish "$fish_c" \
    --argjson nvim "$nvim_c" --argjson md "$md_lines" \
    --argjson tools "$tools" \
    '{harness_score:null, skills:$skills, hooks:$hooks, agents:$agents,
      chezmoi:{managed_files:$managed, template_files:$tmpl},
      fish_functions:$fish, nvim_plugins:$nvim, claude_md_lines:$md, tools:$tools}'
}

# === メイン ===

MODE="${1:---full}"
echo "=== dotfiles メトリクス収集 ==="

echo "--- 現在のメトリクスを収集中 ---"
current=$(collect_current)
echo "  スキル: $(echo "$current" | jq '.skills.total') / フック: $(echo "$current" | jq '.hooks') / ファイル: $(echo "$current" | jq '.chezmoi.managed_files')"

if [[ "$MODE" == "--current" ]]; then
  history=$(jq '.history // []' "$METRICS_FILE" 2>/dev/null || echo '[]')
else
  history=$(build_history)
fi

jq -n \
  --arg name "yagrabit/dotfiles" \
  --arg url "https://github.com/yagrabit/dotfiles" \
  --arg desc "chezmoi管理のdotfilesリポジトリ" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson current "$current" \
  --argjson history "$history" \
  '{repository:{name:$name,url:$url,description:$desc},collected_at:$ts,current:$current,history:$history}' \
  > "$METRICS_FILE"

echo ""
echo "=== 完了: $METRICS_FILE ==="
echo "  履歴: $(echo "$history" | jq 'length')週分"
