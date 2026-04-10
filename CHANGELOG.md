# Changelog

All notable changes to this fork are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-04-09

### Fixed
- Notch no longer "pops" with the boot animation on display unplug, power
  cable plug/unplug, or wake from sleep. `WindowManager` now caches the notch
  screen's identity, frame, and backing scale, and short-circuits
  `didChangeScreenParametersNotification` when nothing notch-relevant has
  changed. When a rebuild is genuinely required, the boot animation is
  suppressed so the migration is silent. Fixes #3 (inherited from upstream
  farouqaldori/claude-island#22).
- Notification sound and notch alert no longer fire every time a `Task`
  subagent finishes. The bundled `claude-island-state.py` hook script now
  reports `processing` (not `waiting_for_input`) on `SubagentStop`, since the
  main session continues working immediately after a subagent returns. The
  alert sound now plays only on the real `Stop` event, when the main session
  is actually waiting for the next user prompt. Fixes #4 (inherited from
  upstream farouqaldori/claude-island#36).
- Notification sound could silently fail to play when the `Notification
  (idle_prompt)` hook arrived before the `Stop` hook. The session phase would
  transition from `.processing` → `.idle` (via `idle_prompt`), and then the
  `Stop` event's `.idle` → `.waitingForInput` transition was rejected by the
  state machine as invalid. Added the missing `.idle → .waitingForInput`
  transition so `Stop` can always complete regardless of hook arrival order.

### Changed
- The version label in the "Check for Updates" row now shows the short git
  commit hash (e.g. `v1.0.2 (5334094)`) instead of the monotonic build
  number. The build number (`CFBundleVersion`) is kept as-is for Sparkle
  comparison; the commit hash is stored in a new `CommitHash` Info.plist key
  and passed via the `COMMIT_HASH` build setting in both `build.sh` and
  `dev-run.sh`.

## [1.0.1] - 2026-04-07

### Fixed
- Notch overlay no longer appears frozen on installs that did not grant Input
  Monitoring. The underlying CGEventTap migration that introduced the implicit
  Input Monitoring requirement has been reverted; the global mouse pipeline is
  back on `NSEvent.addGlobalMonitorForEvents`, which needs no TCC grant.

### Removed
- **All macOS Privacy & Security permission requirements.** This fork now needs
  zero TCC grants to function — no Accessibility, no Input Monitoring, no
  Screen Recording, no Apple Events. Clicking outside the open notch panel
  dismisses the panel without synthesizing a click-through to the window
  underneath (matching `NSMenu` / `NSPopover` / Spotlight semantics), which
  removes the last reason the app needed Accessibility.

### Added
- A persistent menu bar status item as an escape hatch for any case where the
  notch overlay misbehaves — Open Claude Island, Settings…, and Quit are
  reachable from the system menu bar regardless of the overlay's state. The
  icon is the brand crab mascot, drawn from a shared `ClaudeCrabIcon` so the
  notch header and the menu bar status item render from one source.
- Developer convenience scripts: `scripts/dev-run.sh` (one-shot Debug build +
  launch without DerivedData globbing) and `scripts/reset-tcc.sh` (resets only
  this app's macOS TCC grants for reproducing first-launch flows; leaves
  preferences, hooks, and caches untouched).

## [1.0.0] - 2026-04-07

### Added
- Initial fork release based on upstream
  [farouqaldori/claude-island v1.2](https://github.com/farouqaldori/claude-island/commit/0c92dfccf0c3d7356aff0f5cbd8b02a5ff613fcf).

### Removed
- Mixpanel SDK and all telemetry from upstream — this fork ships zero
  analytics, no per-machine identifiers, and no outbound network calls other
  than the Sparkle update check.

### Changed
- Sparkle update feed repointed from upstream's GitHub Releases to this fork's
  GitHub Releases.

### Known issues
- The in-app menu does not include an Input Monitoring permission row, so the
  app cannot guide users through granting that permission. Without Input
  Monitoring, the global mouse event tap never installs and the notch overlay
  will not respond to hover or clicks — the app will look frozen.

  **Manual workaround:** Quit Claude Island, open *System Settings → Privacy &
  Security → Input Monitoring*, click **+**, select `Claude Island.app` from
  `/Applications`, ensure the toggle is on, and relaunch.

  Fixed in v1.0.1 by reverting the underlying CGEventTap migration so the
  notch input pipeline no longer needs Input Monitoring at all.
