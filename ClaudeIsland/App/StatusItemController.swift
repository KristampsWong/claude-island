//
//  StatusItemController.swift
//  ClaudeIsland
//
//  Owns a small NSStatusItem in the system menu bar that gives users a
//  permanent escape hatch — independent of the notch panel and the
//  CGEventTap-driven hover/click pipeline.
//
//  Why this exists:
//
//  Without this, a user who denies (or simply hasn't yet decided on) the
//  Input Monitoring TCC prompt on first launch has *no* way to reach the
//  in-notch Quit button. The only ways to open the notch panel are:
//
//    1. Hover or click the notch — both driven by CGEventTap, which
//       requires Input Monitoring and silently no-ops without it.
//    2. The boot animation, which auto-opens the notch for ~1 second on
//       launch and then auto-closes itself.
//    3. A pending PermissionRequest from a running Claude session.
//
//  None of those help a fresh user who just declined the system prompt
//  and has no Claude sessions running. Combined with `.accessory`
//  activation policy (no Dock icon) and the absence of any other
//  NSStatusItem, the user is fully locked out and has to discover the
//  process in Activity Monitor to kill it.
//
//  This status item is the always-available rescue path: clicking it
//  works regardless of TCC state, and its Quit menu item lets the user
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
    func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            // capsule.fill visually echoes the notch / island shape and is a
            // template image so it adapts to light/dark menu bar automatically.
            let image = NSImage(
                systemSymbolName: "capsule.fill",
                accessibilityDescription: "Claude Island"
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Claude Island"
        }

        let menu = NSMenu()

        let openItem = menu.addItem(
            withTitle: "Open Claude Island",
            action: #selector(openNotch),
            keyEquivalent: ""
        )
        openItem.target = self

        let settingsItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        menu.addItem(NSMenuItem.separator())

        let quitItem = menu.addItem(
            withTitle: "Quit Claude Island",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self

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
        // then force the content view to the settings menu so the user lands
        // on the same panel that hosts Input Monitoring / Accessibility / Quit.
        // This is the documented recovery path when the global event tap is
        // dead and the in-notch hamburger button is unreachable.
        viewModel.notchOpen(reason: .click)
        if viewModel.contentType != .menu {
            viewModel.toggleMenu()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
