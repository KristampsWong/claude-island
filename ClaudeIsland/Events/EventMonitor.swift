//
//  EventMonitor.swift
//  ClaudeIsland
//
//  Lightweight wrapper around a CGEventTap running on a dedicated background thread.
//  Unlike NSEvent.addGlobalMonitorForEvents (which fires on the main thread),
//  CGEventTap callbacks execute on whatever CFRunLoop the tap is added to —
//  keeping event delivery immune to main-thread SwiftUI blocking.
//
//  See: KristampsWong/whisper-island#1 (terminal becomes laggy when ChatView
//  is open) — replacing main-thread NSEvent monitors with a CGEventTap on a
//  dedicated thread is what unblocks the system event pipeline.
//

import AppKit
import os.log

final class EventMonitor {
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var thread: Thread?
    private var runLoopRef: CFRunLoop?
    private var handlerBoxPtr: UnsafeMutableRawPointer?
    private let mask: CGEventMask
    private let handler: (CGEvent) -> Void
    private static let logger = Logger(subsystem: "com.claudeisland", category: "EventMonitor")

    init(mask: CGEventMask, handler: @escaping (CGEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit { stop() }

    func start() {
        guard machPort == nil else { return }

        let box = Unmanaged.passRetained(HandlerBox(handler))
        let ptr = box.toOpaque()
        handlerBoxPtr = ptr

        machPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let box = Unmanaged<HandlerBox>.fromOpaque(userInfo).takeUnretainedValue()
                box.handler(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: ptr
        )

        guard let machPort else {
            Self.logger.error("CGEvent.tapCreate failed — check Accessibility permissions")
            releaseHandlerBox()
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0)

        let t = Thread { [weak self] in
            guard let self, let source = self.runLoopSource else { return }
            self.runLoopRef = CFRunLoopGetCurrent()
            CFRunLoopAddSource(self.runLoopRef, source, .commonModes)
            CFRunLoopRun()
        }
        t.name = "com.claudeisland.eventtap"
        t.qualityOfService = .userInteractive
        thread = t
        t.start()
    }

    func stop() {
        if let rl = runLoopRef {
            CFRunLoopStop(rl)
            runLoopRef = nil
        }
        if let port = machPort {
            CFMachPortInvalidate(port)
            machPort = nil
        }
        runLoopSource = nil
        thread = nil
        releaseHandlerBox()
    }

    private func releaseHandlerBox() {
        if let ptr = handlerBoxPtr {
            Unmanaged<HandlerBox>.fromOpaque(ptr).release()
            handlerBoxPtr = nil
        }
    }
}

private final class HandlerBox {
    let handler: (CGEvent) -> Void
    init(_ handler: @escaping (CGEvent) -> Void) { self.handler = handler }
}
