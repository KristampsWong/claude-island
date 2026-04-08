//
//  StatusItemController.swift
//  ClaudeIsland
//
//  Owns a small NSStatusItem in the system menu bar that gives users a
//  permanent escape hatch — independent of the notch panel and the
//  global event monitor pipeline.
//
//  Why this exists:
//
//  The notch is the only primary UI surface for the app: activation
//  policy is `.accessory` (no Dock icon) and there is no other status
//  item. Hover and click on the notch are driven by global NSEvent
//  monitors. If hover detection wedges, or the notch becomes
//  unresponsive for any other reason, the only ways to recover from
//  inside the app are:
//
//    1. The boot animation, which auto-opens the notch for ~1 second
//       on launch and then auto-closes itself.
//    2. A pending PermissionRequest from a running Claude session.
//
//  Neither helps a fresh user who has no Claude sessions running.
//  Force-quitting via Activity Monitor is the only fallback without
//  this status item.
//
//  This status item is the always-available rescue path: it works
//  regardless of notch state, and its Quit menu item lets the user
//  recover even if the notch is completely unresponsive.
//

import AppKit
import os.log

final class StatusItemController {
    static let shared = StatusItemController()

    private static let logger = Logger(subsystem: "com.claudeisland", category: "StatusItem")

    private var statusItem: NSStatusItem?

    private init() {}

    /// Install the status item. Must be called on the main thread, after
    /// `WindowManager.setupNotchWindow()` has run, so that menu actions can
    /// reach the notch view model via `AppDelegate.shared?.windowController`.
    @MainActor
    func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            // Brand crab mascot — full color (not a template image), so it
            // keeps its orange body + black eyes against both light and
            // dark menu bars. Drawn from the same source as the notch
            // header crab via `ClaudeCrabIcon.nsImage(...)`. 14pt height
            // leaves comfortable padding inside the ~22pt status item.
            let crab = ClaudeCrabIcon.nsImage(size: 14)
            crab?.accessibilityDescription = "Claude Island"
            button.image = crab
            button.toolTip = "Claude Island"
        }

        let menu = NSMenu()

        let openItem = menu.addItem(
            withTitle: "Open Claude Island",
            action: #selector(openNotch),
            keyEquivalent: ""
        )
        openItem.target = self
        openItem.image = ClaudeCrabIcon.nsImage(size: 13)

        let settingsItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        menu.addItem(NSMenuItem.separator())

        let quitItem = menu.addItem(
            withTitle: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = Self.menuIcon(systemSymbolName: "power")

        item.menu = menu
        statusItem = item

        Self.logger.info("Status item installed in menu bar")
    }

    /// Tear down the status item. Wired into `AppDelegate.applicationWillTerminate`
    /// alongside the other long-lived singletons so the icon doesn't briefly
    /// linger in the menu bar during shutdown.
    func uninstall() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - Menu Actions

    // AppKit guarantees NSMenu actions fire on the main thread, so it's safe
    // to touch `NotchViewModel` (which is `@MainActor`-isolated) from here.

    @objc private func openNotch() {
        guard let viewModel = AppDelegate.shared?.windowController?.viewModel else { return }
        viewModel.notchOpen(reason: .click)
    }

    @objc private func openSettings() {
        guard let viewModel = AppDelegate.shared?.windowController?.viewModel else { return }
        // Open the panel first (which may restore a saved chat session) and
        // then force the content view to the settings menu. This is the
        // documented recovery path when the in-notch hamburger button is
        // unreachable for any reason (e.g. hover detection wedged).
        viewModel.notchOpen(reason: .click)
        if viewModel.contentType != .menu {
            viewModel.toggleMenu()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    /// Build a small template SF Symbol image sized for an NSMenuItem leading
    /// icon. Template images pick up the menu's text color automatically so
    /// they look right in light and dark menu bars.
    private static func menuIcon(systemSymbolName name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }
}
