#!/bin/bash
# Build Claude Island in Debug configuration and launch the resulting .app.
#
# This is the day-to-day "I changed some code, see the effect" command.
# It uses ad-hoc local signing (no Apple Developer account needed) — anyone
# can run this on a fresh checkout with zero setup.
#
# The built-products directory is read from xcodebuild itself rather than
# globbing ~/Library/Developer/Xcode/DerivedData/ClaudeIsland-*/, which would
# accidentally match sibling clones of the project at other paths.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=== Building Claude Island (Debug) ==="
xcodebuild -scheme ClaudeIsland -configuration Debug build

BUILT_PRODUCTS_DIR=$(xcodebuild -scheme ClaudeIsland -configuration Debug -showBuildSettings 2>/dev/null \
    | awk -F'= ' '/^[[:space:]]*BUILT_PRODUCTS_DIR =/{print $2; exit}')

APP_PATH="$BUILT_PRODUCTS_DIR/Claude Island.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Built app not found at $APP_PATH" >&2
    exit 1
fi

echo ""
echo "=== Launching ==="
echo "  $APP_PATH"
open "$APP_PATH"
