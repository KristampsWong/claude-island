# Changelog

All notable changes to this fork are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
