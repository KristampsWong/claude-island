//
//  NotchMenuView.swift
//  ClaudeIsland
//
//  Minimal menu matching Dynamic Island aesthetic
//

import Combine
import SwiftUI
import ServiceManagement
import Sparkle

// MARK: - Preference Key

/// Carries the live-measured intrinsic height of `NotchMenuView`'s body up to
/// `NotchViewModel.measuredMenuContentHeight`. This is what lets the panel
/// (and the AppKit hit-test rect derived from it) track the actual rendered
/// menu without anybody having to count rows by hand.
private struct MenuContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // The menu has a single source of this preference; `max` is the safe
        // reducer in case multiple ever exist.
        value = max(value, nextValue())
    }
}

// MARK: - NotchMenuView

struct NotchMenuView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject private var updateManager = UpdateManager.shared
    @ObservedObject private var screenSelector = ScreenSelector.shared
    @ObservedObject private var soundSelector = SoundSelector.shared
    @State private var hooksInstalled: Bool = false
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            // Back button
            MenuRow(
                icon: "chevron.left",
                label: "Back"
            ) {
                viewModel.toggleMenu()
            }

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 4)

            // Appearance settings
            ScreenPickerRow(screenSelector: screenSelector)
            SoundPickerRow(soundSelector: soundSelector)

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 4)

            // System settings
            MenuToggleRow(
                icon: "power",
                label: "Launch at Login",
                isOn: launchAtLogin
            ) {
                do {
                    if launchAtLogin {
                        try SMAppService.mainApp.unregister()
                        launchAtLogin = false
                    } else {
                        try SMAppService.mainApp.register()
                        launchAtLogin = true
                    }
                } catch {
                    print("Failed to toggle launch at login: \(error)")
                }
            }

            MenuToggleRow(
                icon: "arrow.triangle.2.circlepath",
                label: "Hooks",
                isOn: hooksInstalled
            ) {
                if hooksInstalled {
                    HookInstaller.uninstall()
                    hooksInstalled = false
                } else {
                    HookInstaller.installIfNeeded()
                    hooksInstalled = true
                }
            }

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 4)

            // About
            UpdateRow(updateManager: updateManager)

            MenuRow(
                icon: "star",
                label: "Star on GitHub"
            ) {
                if let url = URL(string: "https://github.com/KristampsWong/claude-island") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 4)

            MenuRow(
                icon: "xmark.circle",
                label: "Quit",
                isDestructive: true
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        // Stretch horizontally only — DO NOT use maxHeight: .infinity here.
        // The parent panel proposes a height equal to `openedSize.height`, so
        // a maxHeight of .infinity would inflate the menu to fill that whole
        // proposal, leaving an empty gap below the last row whenever
        // `openedSize.height` is larger than the intrinsic content.
        .frame(maxWidth: .infinity, alignment: .top)
        // Measure the menu's actual rendered height and publish it via a
        // PreferenceKey. `NotchViewModel.openedSize` reads this back to size
        // the panel — and therefore the AppKit hit-test rect — to whatever the
        // menu actually needs right now (rows added/removed, pickers expanded
        // or collapsed, accessibility text sizes, …). No hardcoded constants.
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: MenuContentHeightKey.self,
                        value: proxy.size.height
                    )
            }
        )
        .onPreferenceChange(MenuContentHeightKey.self) { height in
            // Defer to the next runloop tick so we never mutate observable
            // state inside a view-update pass.
            DispatchQueue.main.async {
                if viewModel.measuredMenuContentHeight != height {
                    viewModel.measuredMenuContentHeight = height
                }
            }
        }
        .onAppear {
            refreshStates()
        }
        .onChange(of: viewModel.contentType) { _, newValue in
            if newValue == .menu {
                refreshStates()
            }
        }
    }

    private func refreshStates() {
        hooksInstalled = HookInstaller.isInstalled()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        screenSelector.refreshScreens()
    }
}

// MARK: - Update Row

struct UpdateRow: View {
    @ObservedObject var updateManager: UpdateManager
    @State private var isHovered = false
    @State private var isSpinning = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    if case .installing = updateManager.state {
                        Image(systemName: "gear")
                            .font(.system(size: 12))
                            .foregroundColor(TerminalColors.blue)
                            .rotationEffect(.degrees(isSpinning ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isSpinning)
                            .onAppear { isSpinning = true }
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                            .foregroundColor(iconColor)
                    }
                }
                .frame(width: 16)

                // Label
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(labelColor)

                Spacer()

                // Right side: progress or status
                rightContent
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered && isInteractive ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: updateManager.state)
    }

    // MARK: - Right Content

    @ViewBuilder
    private var rightContent: some View {
        switch updateManager.state {
        case .idle:
            Text(appVersion)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))

        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(TerminalColors.green)
                Text("Up to date")
                    .font(.system(size: 11))
                    .foregroundColor(TerminalColors.green)
            }

        case .checking, .installing:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)

        case .found(let version, _):
            HStack(spacing: 6) {
                Circle()
                    .fill(TerminalColors.green)
                    .frame(width: 6, height: 6)
                Text("v\(version)")
                    .font(.system(size: 11))
                    .foregroundColor(TerminalColors.green)
            }

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 60)
                    .tint(TerminalColors.blue)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TerminalColors.blue)
                    .frame(width: 32, alignment: .trailing)
            }

        case .extracting(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 60)
                    .tint(TerminalColors.amber)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TerminalColors.amber)
                    .frame(width: 32, alignment: .trailing)
            }

        case .readyToInstall(let version):
            HStack(spacing: 6) {
                Circle()
                    .fill(TerminalColors.green)
                    .frame(width: 6, height: 6)
                Text("v\(version)")
                    .font(.system(size: 11))
                    .foregroundColor(TerminalColors.green)
            }

        case .error:
            Text("Retry")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Computed Properties

    private var icon: String {
        switch updateManager.state {
        case .idle:
            return "arrow.down.circle"
        case .checking:
            return "arrow.down.circle"
        case .upToDate:
            return "checkmark.circle.fill"
        case .found:
            return "arrow.down.circle.fill"
        case .downloading:
            return "arrow.down.circle"
        case .extracting:
            return "doc.zipper"
        case .readyToInstall:
            return "checkmark.circle.fill"
        case .installing:
            return "gear"
        case .error:
            return "exclamationmark.circle"
        }
    }

    private var iconColor: Color {
        switch updateManager.state {
        case .idle:
            return .white.opacity(isHovered ? 1.0 : 0.7)
        case .checking:
            return .white.opacity(0.7)
        case .upToDate:
            return TerminalColors.green
        case .found, .readyToInstall:
            return TerminalColors.green
        case .downloading:
            return TerminalColors.blue
        case .extracting:
            return TerminalColors.amber
        case .installing:
            return TerminalColors.blue
        case .error:
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }

    private var label: String {
        switch updateManager.state {
        case .idle:
            return "Check for Updates"
        case .checking:
            return "Checking..."
        case .upToDate:
            return "Check for Updates"
        case .found:
            return "Download Update"
        case .downloading:
            return "Downloading..."
        case .extracting:
            return "Extracting..."
        case .readyToInstall:
            return "Install & Relaunch"
        case .installing:
            return "Installing..."
        case .error:
            return "Update failed"
        }
    }

    private var labelColor: Color {
        switch updateManager.state {
        case .idle, .upToDate:
            return .white.opacity(isHovered ? 1.0 : 0.7)
        case .checking, .downloading, .extracting, .installing:
            return .white.opacity(0.9)
        case .found, .readyToInstall:
            return TerminalColors.green
        case .error:
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }

    private var isInteractive: Bool {
        switch updateManager.state {
        case .idle, .upToDate, .found, .readyToInstall, .error:
            return true
        case .checking, .downloading, .extracting, .installing:
            return false
        }
    }

    // MARK: - Actions

    private func handleTap() {
        switch updateManager.state {
        case .idle, .upToDate, .error:
            updateManager.checkForUpdates()
        case .found:
            updateManager.downloadAndInstall()
        case .readyToInstall:
            updateManager.installAndRelaunch()
        default:
            break
        }
    }
}

struct MenuRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var textColor: Color {
        if isDestructive {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
        return .white.opacity(isHovered ? 1.0 : 0.7)
    }
}

struct MenuToggleRow: View {
    let icon: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)

                Spacer()

                Circle()
                    .fill(isOn ? TerminalColors.green : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)

                Text(isOn ? "On" : "Off")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var textColor: Color {
        .white.opacity(isHovered ? 1.0 : 0.7)
    }
}
