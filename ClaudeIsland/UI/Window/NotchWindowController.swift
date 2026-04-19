//
//  NotchWindowController.swift
//  ClaudeIsland
//
//  Controls the notch window positioning and lifecycle
//

import AppKit
import Combine
import SwiftUI

class NotchWindowController: NSWindowController {
    let viewModel: NotchViewModel
    private let screen: NSScreen
    private let playBootAnimation: Bool
    private var cancellables = Set<AnyCancellable>()
    /// The app that was frontmost before we opened the notch, so we can restore
    /// it on close. Must be strong: `NSWorkspace.frontmostApplication` returns an
    /// autoreleased instance, and a weak ref goes nil on the next pool drain —
    /// which is long before the user clicks to dismiss. Check `isTerminated` at
    /// restore time instead of relying on lifetime tricks.
    private var previousApp: NSRunningApplication?

    init(screen: NSScreen, playBootAnimation: Bool = true) {
        self.screen = screen
        self.playBootAnimation = playBootAnimation

        let screenFrame = screen.frame
        let notchSize = screen.notchSize

        // Window covers full width at top, tall enough for largest content (chat view)
        let windowHeight: CGFloat = 750
        let windowFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.width,
            height: windowHeight
        )

        // Device notch rect - positioned at center
        let deviceNotchRect = CGRect(
            x: (screenFrame.width - notchSize.width) / 2,
            y: 0,
            width: notchSize.width,
            height: notchSize.height
        )

        // Create view model
        self.viewModel = NotchViewModel(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenFrame,
            windowHeight: windowHeight,
            hasPhysicalNotch: screen.hasPhysicalNotch
        )

        // Create the window
        let notchWindow = NotchPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: notchWindow)

        // Create the SwiftUI view with pass-through hosting
        let hostingController = NotchViewController(viewModel: viewModel)
        notchWindow.contentViewController = hostingController

        notchWindow.setFrame(windowFrame, display: true)

        // Synchronous close callback — called by NotchViewModel.handleMouseDown
        // BEFORE status changes, so focus is released on the same runloop tick
        // as the user's click. The status sink below also resets these on close,
        // but it runs async (next runloop tick) and that gap is enough for the
        // global NSEvent mouse-down monitor to observe a phantom click from the
        // in-flight focus change.
        viewModel.onClosePanel = { [weak self, weak notchWindow] in
            notchWindow?.ignoresMouseEvents = true
            notchWindow?.resignKey()
            if let prev = self?.previousApp {
                prev.activate()
                self?.previousApp = nil
            }
        }

        // Track status transitions for focus-management side-effects only.
        // The window's `ignoresMouseEvents` is now driven by the pointer-in-
        // panel publisher below, not by status directly, so that clicks
        // landing in the window frame but outside the visible panel pass
        // through to the app underneath (fixes KristampsWong/claude-island#5).
        viewModel.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak notchWindow, weak viewModel] status in
                switch status {
                case .opened:
                    // Remember which app had focus before we (might) steal it,
                    // so we can hand focus back when the notch closes.
                    let frontmost = NSWorkspace.shared.frontmostApplication
                    if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
                        self?.previousApp = frontmost
                    }
                    // Don't steal app-level focus on open — just make the panel key
                    // so buttons work. NSApp.activate is deferred until the user
                    // actually interacts with a text field (see activateForInput).
                    if viewModel?.openReason != .notification {
                        notchWindow?.makeKey()
                    }
                case .closed, .popping:
                    notchWindow?.resignKey()
                    // Re-activate the app that was frontmost before we opened.
                    // A strong ref is required on previousApp — NSRunningApplication
                    // returned from frontmostApplication is autoreleased, so a weak
                    // ref goes nil before this runs.
                    if let prev = self?.previousApp {
                        prev.activate()
                        self?.previousApp = nil
                    }
                }
            }
            .store(in: &cancellables)

        // Drive `ignoresMouseEvents` from pointer location (when opened) so
        // clicks outside the visible panel rectangle pass through to the app
        // underneath instead of being absorbed by the full-width 750pt-tall
        // panel frame. When not opened, always ignore.
        viewModel.$mouseInsideOpenedPanel
            .receive(on: DispatchQueue.main)
            .sink { [weak notchWindow] inside in
                notchWindow?.ignoresMouseEvents = !inside
            }
            .store(in: &cancellables)

        // Start with ignoring mouse events (closed state)
        notchWindow.ignoresMouseEvents = true

        // Perform boot animation after a brief delay. Suppressed when the
        // window is being rebuilt in response to a screen reconfiguration —
        // see KristampsWong/claude-island#3 (the notch should not "pop" on
        // wake-from-sleep, display unplug, or power changes).
        if playBootAnimation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.viewModel.performBootAnimation()
            }
        }
    }

    /// Activate the app so keyboard input works. Called from ChatView when its
    /// text field gains focus — we defer NSApp.activate to this moment so the
    /// notch can be opened (and dismissed) without ever stealing app-level focus
    /// for the common case of just clicking a button.
    func activateForInput() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }
        NSApp.activate(ignoringOtherApps: false)
        window?.makeKey()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
