#!/usr/bin/env bash
# Claude Code status line — Tokyo Night theme

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
raw_model=$(echo "$input" | jq -r '.model.display_name // empty')
# Shorten model name
case "$raw_model" in
  *opus*)   model="opus" ;;
  *sonnet*) model="sonnet" ;;
  *haiku*)  model="haiku" ;;
  *)        model="$raw_model" ;;
esac
cost=$(echo "$input" | jq -r '.cost.total // empty')

# Tokyo Night ANSI 256-color palette
C_DIR="\033[38;5;111m"      # blue      #7aa2f7 — directory
C_GIT="\033[38;5;141m"      # purple    #bb9af7 — git branch
C_DIRTY="\033[38;5;215m"    # orange    #e0af68 — dirty/untracked flags
C_MODEL="\033[38;5;146m"    # gray-blue #a9b1d6 — model name
C_COST="\033[38;5;79m"      # teal      #73daca — cost
C_CTX="\033[38;5;117m"      # cyan      #7dcfff — context %
C_TIME="\033[38;5;60m"      # dark gray #565f89 — time
C_SEP="\033[38;5;237m"      # separator
C_RESET="\033[0m"

# Directory: if inside a worktree show worktree name, otherwise full path (~ shortened)
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  wt_path=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  main_path=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
  main_path="${main_path%/.git}"
  if [ -n "$main_path" ] && [ "$wt_path" != "$main_path" ]; then
    dir="${wt_path##*/}"
  else
    dir="${cwd/#$HOME/~}"
  fi
else
  dir="${cwd/#$HOME/~}"
fi

# Git branch and status
git_info=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.fsmonitor=false symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" -c core.fsmonitor=false rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    flags=""
    if ! git -C "$cwd" -c core.fsmonitor=false diff --quiet 2>/dev/null || \
       ! git -C "$cwd" -c core.fsmonitor=false diff --cached --quiet 2>/dev/null; then
      flags="*"
    fi
    untracked=$(git -C "$cwd" -c core.fsmonitor=false ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    [ "$untracked" -gt 0 ] && flags="${flags}?"
    if [ -n "$flags" ]; then
      git_info="  ${C_GIT}${branch}${C_DIRTY}${flags}${C_RESET}"
    else
      git_info="  ${C_GIT}${branch}${C_RESET}"
    fi
  fi
fi

# Time
time_str=$(date +%H:%M)

# Context usage
ctx_str=""
if [ -n "$used" ]; then
  ctx_str=" ${C_CTX}ctx:$(printf '%.0f' "$used")%${C_RESET}"
fi

# Model
model_str=""
[ -n "$model" ] && model_str=" ${C_MODEL}${model}${C_RESET}"

# Cost
cost_str=""
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
  cost_str=" ${C_COST}\$$(printf '%.2f' "$cost")${C_RESET}"
fi

# Output
echo -e "${C_DIR}${dir}${C_RESET}${git_info}${model_str}${cost_str}${ctx_str}  ${C_TIME}${time_str}${C_RESET}"
