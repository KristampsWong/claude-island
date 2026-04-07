#!/bin/bash
# Reset all macOS TCC (privacy) permissions for Claude Island.
#
# Useful when testing the first-launch permission prompts (Accessibility,
# Screen Recording, Apple Events, etc.) — after running this, the next launch
# will re-prompt for every permission as if the app had just been installed.
#
# Does NOT touch app preferences, caches, hooks installed into ~/.claude/, or
# any other state — only the system-level TCC grants. If you also want to
# wipe app data, do that separately.
set -e

BUNDLE_ID="com.oceanai.claude-island-fork"

# Quit Claude Island first if it's running, otherwise it can re-cache the
# old TCC state into its in-memory representation before the reset takes effect.
if pgrep -f "Claude Island" >/dev/null 2>&1; then
    echo "Quitting running Claude Island..."
    osascript -e 'tell application "Claude Island" to quit' 2>/dev/null \
        || pkill -f "Claude Island" \
        || true
    sleep 1
fi

echo "Resetting all TCC permissions for $BUNDLE_ID..."
tccutil reset All "$BUNDLE_ID"

echo ""
echo "Done. The next launch of Claude Island will re-prompt for all permissions."
