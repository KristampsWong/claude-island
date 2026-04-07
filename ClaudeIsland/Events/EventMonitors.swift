//
//  EventMonitors.swift
//  ClaudeIsland
//
//  Singleton that aggregates all event monitors.
//  Uses CGEventTap on a dedicated background thread so main-thread
//  SwiftUI blocking can never stall event delivery.
//

import AppKit
import Combine

class EventMonitors {
    static let shared = EventMonitors()

    let mouseLocation = CurrentValueSubject<CGPoint, Never>(.zero)
    let mouseDown = PassthroughSubject<Void, Never>()

    private var mouseMoveMonitor: EventMonitor?
    private var mouseDownMonitor: EventMonitor?

    /// Minimum interval between mouse location updates (source-level throttle)
    private let throttleInterval: TimeInterval = 0.05 // 50ms = 20Hz max
    private var lastMouseLocationTime: CFAbsoluteTime = 0

    /// Whether event forwarding is currently paused
    private(set) var isPaused = false

    private init() {
        setupMonitors()
    }

    private func setupMonitors() {
        // Mouse move + drag — both just update location
        let moveMask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)

        mouseMoveMonitor = EventMonitor(mask: moveMask) { [weak self] event in
            self?.throttledSendMouseLocation(event)
        }
        mouseMoveMonitor?.start()

        // Mouse down
        let downMask: CGEventMask = 1 << CGEventType.leftMouseDown.rawValue
        mouseDownMonitor = EventMonitor(mask: downMask) { [weak self] _ in
            guard self?.isPaused != true else { return }
            self?.mouseDown.send()
        }
        mouseDownMonitor?.start()
    }

    /// Source-level throttle: skip if called within throttleInterval of last send
    private func throttledSendMouseLocation(_ event: CGEvent) {
        guard !isPaused else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastMouseLocationTime >= throttleInterval else { return }
        lastMouseLocationTime = now

        // CGEvent location is in screen coords (top-left origin).
        // Convert to NSScreen coords (bottom-left origin) for AppKit compatibility.
        let cgPoint = event.location
        if let screenHeight = NSScreen.main?.frame.height {
            let nsPoint = CGPoint(x: cgPoint.x, y: screenHeight - cgPoint.y)
            mouseLocation.send(nsPoint)
        }
    }

    // MARK: - Pause / Resume

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    // MARK: - Shutdown

    /// Stop all event monitors. Singletons never `deinit`, so termination
    /// must call this explicitly to release the CGEventTap and let the
    /// dedicated CFRunLoop thread exit — otherwise the run loop would
    /// keep the process alive after Quit.
    func stop() {
        mouseMoveMonitor?.stop()
        mouseMoveMonitor = nil
        mouseDownMonitor?.stop()
        mouseDownMonitor = nil
        isPaused = false
    }

    deinit { stop() }
}
