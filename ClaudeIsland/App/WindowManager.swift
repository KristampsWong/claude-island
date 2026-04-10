//
//  WindowManager.swift
//  ClaudeIsland
//
//  Manages the notch window lifecycle
//

import AppKit
import os.log

/// Logger for window management
private let logger = Logger(subsystem: "com.claudeisland", category: "Window")

/// Snapshot of the inputs that determine the notch window's geometry. We
/// rebuild the window only when one of these actually changes — see
/// `WindowManager.handleScreenChange()` and KristampsWong/claude-island#3.
private struct NotchScreenLayout: Equatable {
    let displayID: CGDirectDisplayID?
    let frame: NSRect
    let backingScaleFactor: CGFloat

    init(screen: NSScreen) {
        self.displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        self.frame = screen.frame
        self.backingScaleFactor = screen.backingScaleFactor
    }
}

class WindowManager {
    private(set) var windowController: NotchWindowController?
    private var lastLayout: NotchScreenLayout?

    /// Set up or recreate the notch window. By default the boot animation
    /// plays — pass `playBootAnimation: false` for screen-reconfiguration
    /// rebuilds where the user did not just launch the app.
    @discardableResult
    func setupNotchWindow(playBootAnimation: Bool = true) -> NotchWindowController? {
        // Use ScreenSelector for screen selection
        let screenSelector = ScreenSelector.shared
        screenSelector.refreshScreens()

        guard let screen = screenSelector.selectedScreen else {
            logger.warning("No screen found")
            return nil
        }

        if let existingController = windowController {
            existingController.window?.orderOut(nil)
            existingController.window?.close()
            windowController = nil
        }

        windowController = NotchWindowController(screen: screen, playBootAnimation: playBootAnimation)
        windowController?.showWindow(nil)
        lastLayout = NotchScreenLayout(screen: screen)

        return windowController
    }

    /// Called from `AppDelegate` on `didChangeScreenParametersNotification`.
    /// Short-circuits when the notch's target screen identity, frame, and
    /// backing scale are all unchanged — wake-from-sleep, power plug/unplug,
    /// and unrelated display reconfigurations all fire that notification but
    /// usually leave the notch screen alone, and rebuilding in those cases
    /// caused the notch to "pop" with the boot animation
    /// (KristampsWong/claude-island#3, upstream farouqaldori/claude-island#22).
    func handleScreenChange() {
        let screenSelector = ScreenSelector.shared
        screenSelector.refreshScreens()

        guard let screen = screenSelector.selectedScreen else {
            logger.warning("Screen change: no screen available")
            return
        }

        let newLayout = NotchScreenLayout(screen: screen)
        if let last = lastLayout, last == newLayout, windowController != nil {
            // Notch's target screen is unchanged — nothing to do.
            return
        }

        logger.info("Screen layout changed — rebuilding notch window without boot animation")
        setupNotchWindow(playBootAnimation: false)
    }
}
