//
//  NotchViewModel.swift
//  ClaudeIsland
//
//  State management for the dynamic island
//

import AppKit
import Combine
import SwiftUI

enum NotchStatus: Equatable {
    case closed
    case opened
    case popping
}

enum NotchOpenReason {
    case click
    case hover
    case notification
    case boot
    case unknown
}

enum NotchContentType: Equatable {
    case instances
    case menu
    case chat(SessionState)

    var id: String {
        switch self {
        case .instances: return "instances"
        case .menu: return "menu"
        case .chat(let session): return "chat-\(session.sessionId)"
        }
    }
}

@MainActor
class NotchViewModel: ObservableObject {
    // MARK: - Published State

    @Published var status: NotchStatus = .closed
    @Published var openReason: NotchOpenReason = .unknown
    @Published var contentType: NotchContentType = .instances
    @Published var isHovering: Bool = false

    /// True when the cursor is inside the currently-visible opened panel rect.
    /// `NotchWindowController` subscribes to this to toggle the panel window's
    /// `ignoresMouseEvents` — false inside, true outside — so clicks that land
    /// in the window frame but outside the visible UI pass through to whatever
    /// window is behind, instead of being silently absorbed by the full-width
    /// 750pt-tall overlay panel.
    @Published var mouseInsideOpenedPanel: Bool = false

    /// Live-measured intrinsic height of the menu's body (rows + dividers + its own
    /// padding), reported by `NotchMenuView` via a PreferenceKey on every layout
    /// pass. Drives `openedSize` for the menu so the panel — and the hit-test rect
    /// derived from it — always tracks the actual rendered content. 0 until the
    /// menu has been laid out at least once; `openedSize` falls back to a sensible
    /// estimate for that single first frame.
    @Published var measuredMenuContentHeight: CGFloat = 0

    // MARK: - Callbacks

    /// Called synchronously by `handleMouseDown` immediately before `notchClose()`
    /// runs, so the controller can release focus / restore mouse-passthrough on
    /// the same runloop tick as the user's click. Without this, the status sink
    /// in `NotchWindowController` (which sets `ignoresMouseEvents` and resigns
    /// key) only fires on the next runloop tick, leaving a brief window where
    /// the panel still owns focus and the global `NSEvent` mouse-down monitor
    /// can observe a phantom click from the in-flight focus transition.
    var onClosePanel: (() -> Void)?

    // MARK: - Dependencies

    private let screenSelector = ScreenSelector.shared
    private let soundSelector = SoundSelector.shared

    // MARK: - Geometry

    let geometry: NotchGeometry
    let spacing: CGFloat = 12
    let hasPhysicalNotch: Bool

    var deviceNotchRect: CGRect { geometry.deviceNotchRect }
    var screenRect: CGRect { geometry.screenRect }
    var windowHeight: CGFloat { geometry.windowHeight }

    /// Dynamic opened size based on content type
    var openedSize: CGSize {
        switch contentType {
        case .chat:
            // Large size for chat view
            return CGSize(
                width: min(screenRect.width * 0.5, 600),
                height: 580
            )
        case .menu:
            // Menu panel sizes itself to its actual rendered content. The body
            // height is measured live by `NotchMenuView` via a PreferenceKey
            // (see `measuredMenuContentHeight`) so that adding rows, expanding
            // pickers, or changing fonts all just work — no constants to tune,
            // and no risk of the hit-test rect drifting from the visible panel.
            //
            // For the very first frame (before any layout pass has reported a
            // measurement) we use a fallback that's a reasonable over-estimate
            // for the menu in its collapsed state. The next layout pass will
            // correct it within one animation frame.
            let header = max(24, deviceNotchRect.height)
            let bottomPanelPadding: CGFloat = 12
            let menuContent = measuredMenuContentHeight > 0
                ? measuredMenuContentHeight
                : 440 // collapsed-menu fallback for the first frame
            return CGSize(
                width: min(screenRect.width * 0.4, 480),
                height: header + menuContent + bottomPanelPadding
            )
        case .instances:
            return CGSize(
                width: min(screenRect.width * 0.4, 480),
                height: 320
            )
        }
    }

    // MARK: - Animation

    var animation: Animation {
        .easeOut(duration: 0.25)
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private let events = EventMonitors.shared
    private var hoverTimer: DispatchWorkItem?

    // MARK: - Initialization

    init(deviceNotchRect: CGRect, screenRect: CGRect, windowHeight: CGFloat, hasPhysicalNotch: Bool) {
        self.geometry = NotchGeometry(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenRect,
            windowHeight: windowHeight
        )
        self.hasPhysicalNotch = hasPhysicalNotch
        setupEventHandlers()
        observeSelectors()
    }

    private func observeSelectors() {
        screenSelector.$isPickerExpanded
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        soundSelector.$isPickerExpanded
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Event Handling

    private func setupEventHandlers() {
        events.mouseLocation
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] location in
                self?.handleMouseMove(location)
            }
            .store(in: &cancellables)

        events.mouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMouseDown()
            }
            .store(in: &cancellables)
    }

    /// Whether we're in chat mode (sticky behavior)
    private var isInChatMode: Bool {
        if case .chat = contentType { return true }
        return false
    }

    /// The chat session we're viewing (persists across close/open)
    private var currentChatSession: SessionState?

    private func handleMouseMove(_ location: CGPoint) {
        let inNotch = geometry.isPointInNotch(location)
        let inOpened = status == .opened && geometry.isPointInOpenedPanel(location, size: openedSize)

        // Drive window-level click pass-through: capture clicks only when the
        // cursor is actually over the visible panel. Outside the panel the
        // window becomes mouse-transparent so dismiss clicks reach the app
        // underneath — this is what makes the user's dismiss click count as
        // a real click in Terminal/VSCode/etc. instead of needing a second one.
        if mouseInsideOpenedPanel != inOpened {
            mouseInsideOpenedPanel = inOpened
        }

        let newHovering = inNotch || inOpened

        // Only update if changed to prevent unnecessary re-renders
        guard newHovering != isHovering else { return }

        isHovering = newHovering

        // Cancel any pending hover timer
        hoverTimer?.cancel()
        hoverTimer = nil

        // Start hover timer to auto-expand after 1 second
        if isHovering && (status == .closed || status == .popping) {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isHovering else { return }
                self.notchOpen(reason: .hover)
            }
            hoverTimer = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        }
    }

    private func handleMouseDown() {
        let location = NSEvent.mouseLocation

        switch status {
        case .opened:
            if geometry.isPointOutsidePanel(location, size: openedSize) {
                // Clicking outside the panel only dismisses the panel — we
                // intentionally do NOT synthesize a click-through to the
                // window underneath. That matches macOS-native popover
                // semantics (NSMenu, NSPopover, Spotlight, Notification
                // Center all absorb their dismiss click) and avoids the
                // footgun of accidentally triggering UI on a background
                // window when the user only meant to close the notch.
                onClosePanel?()
                notchClose()
            } else if geometry.notchScreenRect.contains(location) {
                // Clicking notch while opened - only close if NOT in chat mode
                if !isInChatMode {
                    onClosePanel?()
                    notchClose()
                }
            }
        case .closed, .popping:
            if geometry.isPointInNotch(location) {
                notchOpen(reason: .click)
            }
        }
    }

    // MARK: - Actions

    func notchOpen(reason: NotchOpenReason = .unknown) {
        openReason = reason
        status = .opened

        // Seed pointer-in-panel state immediately so the window can flip to
        // `ignoresMouseEvents = false` right at open, before the first
        // mouseMoved event arrives. Otherwise a button click that follows the
        // hover-triggered open before any movement would be dropped.
        mouseInsideOpenedPanel = geometry.isPointInOpenedPanel(NSEvent.mouseLocation, size: openedSize)

        // Don't restore chat on notification - show instances list instead
        if reason == .notification {
            currentChatSession = nil
            return
        }

        // Restore chat session if we had one open before
        if let chatSession = currentChatSession {
            // Avoid unnecessary updates if already showing this chat
            if case .chat(let current) = contentType, current.sessionId == chatSession.sessionId {
                return
            }
            contentType = .chat(chatSession)
        }
    }

    func notchClose() {
        // Save chat session before closing if in chat mode
        if case .chat(let session) = contentType {
            currentChatSession = session
        }
        status = .closed
        contentType = .instances
        mouseInsideOpenedPanel = false
    }

    func notchPop() {
        guard status == .closed else { return }
        status = .popping
    }

    func notchUnpop() {
        guard status == .popping else { return }
        status = .closed
    }

    func toggleMenu() {
        contentType = contentType == .menu ? .instances : .menu
    }

    func showChat(for session: SessionState) {
        // Avoid unnecessary updates if already showing this chat
        if case .chat(let current) = contentType, current.sessionId == session.sessionId {
            return
        }
        contentType = .chat(session)
    }

    /// Go back to instances list and clear saved chat state
    func exitChat() {
        currentChatSession = nil
        contentType = .instances
    }

    /// Perform boot animation: expand briefly then collapse
    func performBootAnimation() {
        notchOpen(reason: .boot)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.openReason == .boot else { return }
            self.notchClose()
        }
    }
}
