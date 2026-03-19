#!/bin/bash
# Claude Code statusline script
# Line 1: Model | Context% | +added/-removed | git branch

input=$(cat)

# ---------- ANSI Colors ----------
GREEN=$'\e[38;2;151;201;195m'
YELLOW=$'\e[38;2;229;192;123m'
RED=$'\e[38;2;224;108;117m'
GRAY=$'\e[38;2;74;88;92m'
RESET=$'\e[0m'

# ---------- Color by percentage ----------
color_for_pct() {
  local pct="$1"
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    printf '%s' "$GRAY"
    return
  fi
  local ipct
  ipct=$(printf "%.0f" "$pct" 2>/dev/null || echo "0")
  if [ "$ipct" -ge 80 ]; then
    printf '%s' "$RED"
  elif [ "$ipct" -ge 50 ]; then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$GREEN"
  fi
}

# ---------- Parse stdin (single jq call) ----------
eval "$(echo "$input" | jq -r '
  "model_name=" + (.model.display_name // "Unknown" | @sh),
  "used_pct=" + (.context_window.used_percentage // 0 | tostring),
  "cwd=" + (.cwd // "" | @sh),
  "lines_added=" + (.cost.total_lines_added // 0 | tostring),
  "lines_removed=" + (.cost.total_lines_removed // 0 | tostring)
' 2>/dev/null)"

# ---------- Git branch ----------
git_branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  git_branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || true)
fi

# ---------- Line stats from stdin ----------
git_stats=""
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
  git_stats="+${lines_added}/-${lines_removed}"
fi

# ---------- Format context used% ----------
ctx_pct_int=0
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ] && [ "$used_pct" != "0" ]; then
  ctx_pct_int=$(printf "%.0f" "$used_pct" 2>/dev/null || echo 0)
fi

# ---------- Line 1 ----------
SEP="${GRAY} │ ${RESET}"
ctx_color=$(color_for_pct "$ctx_pct_int")

line1="🤖 ${model_name}${SEP}${ctx_color}📊 ${ctx_pct_int}%${RESET}"

if [ -n "$git_stats" ]; then
  line1+="${SEP}✏️  ${GREEN}${git_stats}${RESET}"
fi

if [ -n "$cwd" ]; then
  dir_name=$(basename "$cwd")
  line1+="${SEP}📂 ${dir_name}"
fi

if [ -n "$git_branch" ]; then
  line1+="${SEP}🔀 ${git_branch}"
fi

# ---------- tmux監視: active状態の書き出し ----------
if [ -n "${TMUX_PANE:-}" ]; then
  _mon_pane_id="$TMUX_PANE"
  _mon_safe_id="${_mon_pane_id//%/pct}"
  _mon_dir="/tmp/claude-sessions"
  _mon_file="${_mon_dir}/${_mon_safe_id}.json"
  mkdir -p "$_mon_dir" 2>/dev/null
  _mon_ts=$(date +%s)
  # tmux情報取得
  _mon_tmux_info=$(tmux display-message -t "$_mon_pane_id" -p '#{window_name}||#{window_index}||#{session_name}' 2>/dev/null || true)
  if [ -n "$_mon_tmux_info" ]; then
    _mon_win_name="${_mon_tmux_info%%||*}"
    _mon_rest="${_mon_tmux_info#*||}"
    _mon_win_idx="${_mon_rest%%||*}"
    _mon_sess="${_mon_rest#*||}"
    _mon_tmp="${_mon_file}.tmp.$$"
    jq -n \
      --arg pid "$_mon_pane_id" \
      --arg st "active" \
      --arg wn "$_mon_win_name" \
      --arg wi "$_mon_win_idx" \
      --arg sn "$_mon_sess" \
      --arg pp "${cwd:-}" \
      --arg mn "${model_name:-}" \
      --arg cp "${ctx_pct_int:-0}" \
      --argjson ts "$_mon_ts" \
      '{pane_id:$pid, state:$st, window_name:$wn, window_index:$wi, session_name:$sn, pane_path:$pp, model:$mn, context_pct:$cp, timestamp:$ts}' \
      > "$_mon_tmp" 2>/dev/null && mv "$_mon_tmp" "$_mon_file" 2>/dev/null
  fi
fi || true

# ---------- Output ----------
printf '%s' "$line1"
