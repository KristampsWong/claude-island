<div align="center">
  <img src="ClaudeIsland/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Logo" width="100" height="100">
  <h3 align="center">Claude Island</h3>
  <p align="center">
    A macOS menu bar app that brings Dynamic Island-style notifications to Claude Code CLI sessions.
    <br />
    <br />
    <a href="https://github.com/KristampsWong/claude-island/releases/latest" target="_blank" rel="noopener noreferrer">
      <img src="https://img.shields.io/github/v/release/KristampsWong/claude-island?style=rounded&color=white&labelColor=000000&label=release" alt="Release Version" />
    </a>
    <a href="https://github.com/KristampsWong/claude-island/releases" target="_blank" rel="noopener noreferrer">
      <img alt="GitHub Downloads" src="https://img.shields.io/github/downloads/KristampsWong/claude-island/total?style=rounded&color=white&labelColor=000000" />
    </a>
  </p>
</div>

## About this fork

This is an independently maintained fork of [farouqaldori/claude-island](https://github.com/farouqaldori/claude-island), the original project by [@farouqaldori](https://github.com/farouqaldori). Full credit for the original design, architecture, and the bulk of the codebase belongs to the upstream author — this fork exists to ship additional bug fixes and incremental improvements on top of that work.

This fork's **v1.0.0** uses upstream **v1.2** ([`0c92dfcc`](https://github.com/farouqaldori/claude-island/commit/0c92dfccf0c3d7356aff0f5cbd8b02a5ff613fcf) in [farouqaldori/claude-island](https://github.com/farouqaldori/claude-island)) as its source baseline — that is, the working tree of `0c92dfcc` is the starting point we built on top of. Our v1.0.0 is then equal to that baseline plus:

- removal of the Mixpanel SDK and all telemetry
- repointing of the Sparkle update feed to this fork's GitHub Releases
- the fork-specific bug fixes that have landed since (see the commit log)

The version line continues independently from v1.0.0 onward; we do not track upstream's version numbers. Note that this fork's git history is not a continuation of upstream's git history (it begins at its own root commit) — the relationship is by content, not by git ancestry.

If you want to see or compare the upstream project, please visit the [original repository](https://github.com/farouqaldori/claude-island).

## Features

- **Notch UI** — Animated overlay that expands from the MacBook notch
- **Live Session Monitoring** — Track multiple Claude Code sessions in real-time
- **Permission Approvals** — Approve or deny tool executions directly from the notch
- **Chat History** — View full conversation history with markdown rendering
- **Auto-Setup** — Hooks install automatically on first launch

## Requirements

- macOS 15.6+
- Claude Code CLI

## Install

Download the latest build from the [Releases page](https://github.com/KristampsWong/claude-island/releases/latest).

## Building from source

No Apple Developer account or extra setup required — `DEVELOPMENT_TEAM` is intentionally left empty in `project.pbxproj`, so Xcode falls back to ad-hoc local signing automatically.

```bash
git clone https://github.com/KristampsWong/claude-island.git
cd claude-island
xcodebuild -scheme ClaudeIsland -configuration Debug build
```

Or just open `ClaudeIsland.xcodeproj` in Xcode and ⌘R.

## Releasing (maintainers)

See [`CHANGELOG.md`](CHANGELOG.md) for the version history. `scripts/create-release.sh` reads the `## [<version>]` section for the current version out of `CHANGELOG.md` and uses it as the GitHub release body, so adding a new release means editing `CHANGELOG.md` first and then tagging.

Releases are version-driven by git tags. Both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are injected at build time from `git describe --tags` and `git rev-list --count HEAD` respectively, so `project.pbxproj` never has to be edited by hand.

One-time setup:

```bash
# 1. Save your Apple Developer Team ID locally (gitignored)
echo 'YOUR_TEAM_ID' > .signing-team-id

# 2. Generate a Sparkle EdDSA keypair and copy the printed public key
#    into Info.plist's SUPublicEDKey value
./scripts/generate-keys.sh

# 3. Set up notarytool credentials (one-time)
xcrun notarytool store-credentials "ClaudeIsland" \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

Per release:

```bash
git tag v1.0.1
./scripts/build.sh           # archive + export, version derived from tag
./scripts/create-release.sh  # notarize, sign, generate appcast, push GitHub release
```

The Sparkle feed in `Info.plist` points at
`https://github.com/KristampsWong/claude-island/releases/latest/download/appcast.xml`,
which GitHub redirects to whatever appcast was attached to the most recent release. No separate website or hosting is involved.

## How It Works

Claude Island installs hooks into `~/.claude/hooks/` that communicate session state via a Unix socket. The app listens for events and displays them in the notch overlay.

When Claude Code needs permission to run a tool, the notch expands with approve / deny buttons — no need to switch back to the terminal.

## Privacy

**This fork does not collect any analytics or telemetry.** No usage data, device identifiers, crash reports, or any other information is sent anywhere — Claude Island only talks to your local Claude Code CLI over a Unix socket on your machine.

> Note: the upstream project ([farouqaldori/claude-island](https://github.com/farouqaldori/claude-island)) ships with Mixpanel analytics. This fork has removed the Mixpanel SDK, all tracking calls, and the per-machine distinct ID generation entirely. You can verify this with `grep -r mixpanel` on the source tree.

The only outbound network connection Claude Island makes is to its own Sparkle update feed to check for new versions of the app itself.

## Credits

- Original project: [farouqaldori/claude-island](https://github.com/farouqaldori/claude-island) by [@farouqaldori](https://github.com/farouqaldori)
- This fork: maintained by [@KristampsWong](https://github.com/KristampsWong)

## License

Apache 2.0
