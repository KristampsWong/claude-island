//
//  EventMonitor.swift
//  ClaudeIsland
//
//  Wraps NSEvent global + local monitors with explicit lifecycle management.
//  The terminal-lag bug that originally motivated a CGEventTap migration is
//  now addressed at its root by the SwiftUI diff cost reductions in
//  SessionStore (publish throttle/debounce) and ChatHistoryItem (version-
//  based Equatable). With those in place, NSEvent monitors on the main
//  thread are no longer starved by SwiftUI rendering, and we can avoid the
//  Input Monitoring TCC requirement that CGEvent.tapCreate would impose.
//
//  See: docs/superpowers/plans/2026-04-07-revert-cgevent-tap.md
//

import AppKit

final class EventMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit { stop() }

    func start() {
        guard globalMonitor == nil else { return }

        // Global monitor for events outside our app
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handler(event)
        }

        // Local monitor for events inside our app
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handler(event)
            return event
        }
    }

    /// Stop both monitors. Singletons that own an `EventMonitor` never
    /// `deinit`, so termination must call this explicitly to release the
    /// global / local NSEvent monitors that would otherwise keep the run
    /// loop alive after Quit. See `EventMonitors.stop()`.
    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
