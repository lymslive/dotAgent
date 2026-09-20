#!/bin/bash

CWD=$(pwd)
[ -z "$CWD" ] && exit 0

# Get the latest commit hash
HASH=$(cd "$CWD" && git log -1 --format="%H" 2>/dev/null)
[ -z "$HASH" ] && exit 0

# Check if task_log.md exists in cwd
LOG_FILE="$CWD/task_log.md"
[ -f "$LOG_FILE" ] || exit 0

# Avoid duplicate: skip if this hash is already the last COMMIT entry
LAST=$(grep -o 'COMMIT: [a-f0-9]*' "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $2}')
[ "$HASH" = "$LAST" ] && exit 0

# Append commit hash (matching existing task_log.md format)
printf '\n### COMMIT: %s\n' "$HASH" >> "$LOG_FILE"
