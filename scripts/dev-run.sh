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

# Derive a meaningful Debug version from git so the in-app menu shows
# something like "v1.0.0-dev.5 (13)" instead of the "0.0.0-dev (0)" placeholder
# baked into project.pbxproj. This mirrors what scripts/build.sh does for
# release builds: marketing version comes from the most recent tag, build
# number is the total commit count (monotonically increasing). Using a build
# number that's always ≥ the latest published Sparkle build also stops the
# "Download Update" prompt from firing on dev builds, since Sparkle would
# otherwise see CFBundleVersion=0 and try to "upgrade" us to the public release.
RAW_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [ -n "$RAW_TAG" ]; then
    LAST_VERSION="${RAW_TAG#v}"
    COMMITS_AHEAD=$(git rev-list "${RAW_TAG}..HEAD" --count 2>/dev/null || echo "0")
    if [ "$COMMITS_AHEAD" -eq 0 ]; then
        DEV_VERSION="${LAST_VERSION}-dev"
    else
        DEV_VERSION="${LAST_VERSION}-dev.${COMMITS_AHEAD}"
    fi
else
    DEV_VERSION="0.0.0-dev"
fi
DEV_BUILD=$(git rev-list --count HEAD 2>/dev/null || echo "0")
DEV_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")

echo "=== Building Claude Island (Debug) ==="
echo "  Version: $DEV_VERSION (build $DEV_BUILD)"
xcodebuild -scheme ClaudeIsland -configuration Debug \
    MARKETING_VERSION="$DEV_VERSION" \
    CURRENT_PROJECT_VERSION="$DEV_BUILD" \
    COMMIT_HASH="$DEV_COMMIT" \
    build

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
