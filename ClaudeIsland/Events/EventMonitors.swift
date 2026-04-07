//
//  EventMonitors.swift
//  ClaudeIsland
//
//  Singleton that aggregates NSEvent global + local monitors. Subscribers
//  consume `mouseLocation` (CGPoint) and `mouseDown` (Void trigger) via
//  Combine — see `NotchViewModel.setupEventHandlers`.
//
//  Why NSEvent rather than CGEventTap:
//
//  CGEvent.tapCreate requires the Input Monitoring TCC permission. On
//  ad-hoc signed Debug builds the bundle frequently fails to register in
//  System Settings → Privacy & Security → Input Monitoring at all (the
//  user has to add it via the +/- button), and even when it does the tap
//  silently no-ops until the grant flips, leaving the user with a
//  notch-only app they cannot reach. NSEvent global monitors for mouse
//  events do not require any TCC grant on modern macOS, so the only
//  remaining TCC dependency is Accessibility — needed solely by
//  `NotchViewModel.repostClickAt`'s `CGEvent.post(tap: .cghidEventTap)`.
//
//  The terminal-lag bug that originally motivated the CGEventTap
//  migration (KristampsWong/whisper-island#1) is fixed at its root by
//  the SwiftUI diff cost reductions still in place in `SessionStore`
//  (`publishState` throttle/debounce) and `ChatHistoryItem` (monotonic
//  version counter for O(1) Equatable). Those layers stay; only the
//  defensive event-delivery layer is being removed.
//
//  See: docs/superpowers/plans/2026-04-07-revert-cgevent-tap.md
//

import AppKit
import Combine

class EventMonitors {
    static let shared = EventMonitors()

    let mouseLocation = CurrentValueSubject<CGPoint, Never>(.zero)
    let mouseDown = PassthroughSubject<Void, Never>()

    private var mouseMoveMonitor: EventMonitor?
    private var mouseDownMonitor: EventMonitor?
    private var mouseDraggedMonitor: EventMonitor?

    private init() {
        setupMonitors()
    }

    private func setupMonitors() {
        mouseMoveMonitor = EventMonitor(mask: .mouseMoved) { [weak self] _ in
            self?.mouseLocation.send(NSEvent.mouseLocation)
        }
        mouseMoveMonitor?.start()

        mouseDownMonitor = EventMonitor(mask: .leftMouseDown) { [weak self] _ in
            self?.mouseDown.send()
        }
        mouseDownMonitor?.start()

        mouseDraggedMonitor = EventMonitor(mask: .leftMouseDragged) { [weak self] _ in
            self?.mouseLocation.send(NSEvent.mouseLocation)
        }
        mouseDraggedMonitor?.start()
    }

    /// Stop all event monitors. Singletons never `deinit`, so termination
    /// must call this explicitly to release the global / local NSEvent
    /// monitors that would otherwise keep the run loop alive after Quit.
    /// Wired into `AppDelegate.applicationWillTerminate`.
    func stop() {
        mouseMoveMonitor?.stop()
        mouseMoveMonitor = nil
        mouseDownMonitor?.stop()
        mouseDownMonitor = nil
        mouseDraggedMonitor?.stop()
        mouseDraggedMonitor = nil
    }

    deinit { stop() }
}
