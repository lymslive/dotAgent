#!/bin/bash

# link.sh - Create soft links from dot directories to dotAgent subdirectories
# This script should be executed from the parent directory of dotAgent
# Usage: dotAgent/link.sh

set -e

# Get the script's directory (dotAgent)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Define the mappings: dot directory name -> dotAgent subdirectory
declare -A MAPPINGS=(
    [".tool"]="tool"
    [".claude"]="claude"
    [".codebuddy"]="codebuddy"
    [".iflow"]="iflow"
)

echo "Creating soft links in current directory..."
echo

# Iterate through each mapping
for DOT_DIR in "${!MAPPINGS[@]}"; do
    SUBDIR="${MAPPINGS[$DOT_DIR]}"
    DOT_PATH="./$DOT_DIR"
    SUBDIR_PATH="$SCRIPT_DIR/$SUBDIR"

    echo -n "Creating link $DOT_PATH -> dotAgent/$SUBDIR ... "

    # Check if the source directory exists in dotAgent
    if [ ! -d "$SUBDIR_PATH" ]; then
        echo "FAILED (source directory dotAgent/$SUBDIR not found)"
        continue
    fi

    # Check if the dot directory already exists
    if [ -e "$DOT_PATH" ]; then
        if [ -L "$DOT_PATH" ]; then
            # It's already a symlink, check if it points to the right place
            CURRENT_TARGET="$(readlink "$DOT_PATH")"
            if [ "$CURRENT_TARGET" = "dotAgent/$SUBDIR" ]; then
                echo "SKIPPED (already correctly linked)"
            else
                echo "SKIPPED (exists but points elsewhere: $CURRENT_TARGET)"
            fi
        else
            # It's a regular directory
            echo "SKIPPED (regular directory already exists)"
        fi
    else
        # Create the symlink
        ln -s "dotAgent/$SUBDIR" "$DOT_PATH"
        echo "OK"
    fi
done

echo
echo "Done!"
