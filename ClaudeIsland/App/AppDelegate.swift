import AppKit
import Sparkle
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowManager: WindowManager?
    private var screenObserver: ScreenObserver?
    private var updateCheckTimer: Timer?

    static var shared: AppDelegate?
    let updater: SPUUpdater
    private let userDriver: NotchUserDriver

    var windowController: NotchWindowController? {
        windowManager?.windowController
    }

    override init() {
        userDriver = NotchUserDriver()
        updater = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: userDriver,
            delegate: nil
        )
        super.init()
        AppDelegate.shared = self

        do {
            try updater.start()
        } catch {
            print("Failed to start Sparkle updater: \(error)")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !ensureSingleInstance() {
            NSApplication.shared.terminate(nil)
            return
        }

        HookInstaller.installIfNeeded()
        NSApplication.shared.setActivationPolicy(.accessory)

        windowManager = WindowManager()
        _ = windowManager?.setupNotchWindow()

        // Install the menu-bar status item AFTER the window manager has
        // created the notch view model — its menu actions reach the view
        // model via `windowController` and would be no-ops otherwise. This
        // is the user's permanent escape hatch when the notch is unreachable
        // for any reason (e.g. Accessibility not yet granted, so click
        // re-posting from `NotchViewModel.repostClickAt` is silently dropped).
        StatusItemController.shared.install()

        screenObserver = ScreenObserver { [weak self] in
            self?.handleScreenChange()
        }

        if updater.canCheckForUpdates {
            updater.checkForUpdates()
        }

        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let updater = self?.updater, updater.canCheckForUpdates else { return }
            updater.checkForUpdates()
        }
    }

    private func handleScreenChange() {
        _ = windowManager?.setupNotchWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil
        screenObserver = nil

        // Release background resources that would otherwise keep dispatch
        // sources / file descriptors / global NSEvent monitors alive and
        // prevent the process from actually exiting after Quit.
        // See: KristampsWong/whisper-island#3 (inherited from
        // farouqaldori/claude-island#20).
        EventMonitors.shared.stop()
        HookSocketServer.shared.stop()
        InterruptWatcherManager.shared.stopAll()
        AgentFileWatcherManager.shared.stopAll()
        StatusItemController.shared.uninstall()

        // Final safety net: if anything still holds the run loop alive
        // after cleanup, force-exit shortly after so users never have to
        // force-kill via Activity Monitor.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    private func ensureSingleInstance() -> Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.farouqaldori.ClaudeIsland"
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID
        }

        if runningApps.count > 1 {
            if let existingApp = runningApps.first(where: { $0.processIdentifier != getpid() }) {
                existingApp.activate()
            }
            return false
        }

        return true
    }
}
