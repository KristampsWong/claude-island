#!/bin/bash
# Build Claude Island for release.
#
# Version, build number, and signing team ID are all derived at build time
# rather than being checked into project.pbxproj:
#
#   - MARKETING_VERSION       <- latest git tag (e.g. v1.0.0 -> 1.0.0)
#   - CURRENT_PROJECT_VERSION <- total commit count (monotonically increasing)
#   - COMMIT_HASH             <- short git commit hash (displayed in UI)
#   - DEVELOPMENT_TEAM        <- $CLAUDE_ISLAND_TEAM_ID env var,
#                                or contents of .signing-team-id (gitignored)
#
# This means project.pbxproj stays clean and any contributor can run a Debug
# build with no setup at all (Xcode falls back to ad-hoc signing when
# DEVELOPMENT_TEAM is empty).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/ClaudeIsland.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"

cd "$PROJECT_DIR"

# ============================================
# Resolve version + build number from git
# ============================================
RAW_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [ -z "$RAW_TAG" ]; then
    echo "ERROR: No git tag found."
    echo ""
    echo "Create one before releasing, e.g.:"
    echo "  git tag v1.0.0"
    echo ""
    exit 1
fi
# Strip leading 'v' if present (v1.0.0 -> 1.0.0)
VERSION="${RAW_TAG#v}"

# Warn if HEAD is not exactly at the tag — the build will still proceed but
# the resulting binary won't match the tag commit, which is usually a mistake.
TAG_COMMIT=$(git rev-list -n 1 "$RAW_TAG")
HEAD_COMMIT=$(git rev-parse HEAD)
if [ "$TAG_COMMIT" != "$HEAD_COMMIT" ]; then
    echo "WARNING: HEAD ($HEAD_COMMIT) is not at tag $RAW_TAG ($TAG_COMMIT)."
    echo "         The release will still be labeled $VERSION but may contain"
    echo "         additional uncommitted/untagged changes."
    echo ""
fi

# Build number: total commit count. Monotonically increases, satisfies Sparkle.
BUILD=$(git rev-list --count HEAD)

# Short commit hash for display in the UI (not used by Sparkle).
COMMIT_HASH=$(git rev-parse --short HEAD)

# ============================================
# Resolve signing team ID
# ============================================
TEAM_ID="${CLAUDE_ISLAND_TEAM_ID:-}"
if [ -z "$TEAM_ID" ] && [ -f "$PROJECT_DIR/.signing-team-id" ]; then
    TEAM_ID=$(tr -d '[:space:]' < "$PROJECT_DIR/.signing-team-id")
fi
if [ -z "$TEAM_ID" ]; then
    echo "ERROR: No Apple Developer Team ID configured."
    echo ""
    echo "Set one of the following before running this script:"
    echo "  echo 'YOUR_TEAM_ID' > .signing-team-id"
    echo "  export CLAUDE_ISLAND_TEAM_ID=YOUR_TEAM_ID"
    echo ""
    echo "Find your Team ID at https://developer.apple.com/account"
    echo "(10-character string in the membership details)."
    exit 1
fi

echo "=== Building Claude Island ==="
echo "  Tag:      $RAW_TAG"
echo "  Version:  $VERSION"
echo "  Build:    $BUILD"
echo "  Commit:   $COMMIT_HASH"
echo "  Team ID:  $TEAM_ID"
echo ""

# ============================================
# Clean previous builds
# ============================================
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ============================================
# Archive
# ============================================
echo "Archiving..."
xcodebuild archive \
    -scheme ClaudeIsland \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    COMMIT_HASH="$COMMIT_HASH" \
    | xcpretty || xcodebuild archive \
    -scheme ClaudeIsland \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    COMMIT_HASH="$COMMIT_HASH"

# ============================================
# Export
# ============================================
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
</dict>
</plist>
EOF

echo ""
echo "Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    | xcpretty || xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

echo ""
echo "=== Build Complete ==="
echo "  App:     $EXPORT_PATH/Claude Island.app"
echo "  Version: $VERSION ($COMMIT_HASH)"
echo ""
echo "Next: ./scripts/create-release.sh"
