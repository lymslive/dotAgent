#!/bin/bash
input=$(cat)
cwd=$(echo "$input" | jq -r 'if .workspace.current_dir and (.workspace.current_dir != "") then .workspace.current_dir elif .cwd and (.cwd != "") then .cwd else "" end')
[ -z "$cwd" ] && cwd="$(pwd)"
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
suffix=""
if [ -n "$model" ] && [ -n "$used" ]; then
  suffix=$(printf " \033[00;37m[%s %.0f%%]\033[00m" "$model" "$used")
elif [ -n "$model" ]; then
  suffix=$(printf " \033[00;37m[%s]\033[00m" "$model")
fi
printf "\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m%s" "$(whoami)" "$(hostname -s)" "$cwd" "$suffix"
