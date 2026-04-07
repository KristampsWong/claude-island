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

Download the latest build from the [Releases page](https://github.com/KristampsWong/claude-island/releases/latest), or build from source:

```bash
xcodebuild -scheme ClaudeIsland -configuration Release build
```

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
