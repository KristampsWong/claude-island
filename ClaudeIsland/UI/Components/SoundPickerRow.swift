//
//  SoundPickerRow.swift
//  ClaudeIsland
//
//  Notification sound selection picker for settings menu
//

import AppKit
import SwiftUI

struct SoundPickerRow: View {
    @ObservedObject var soundSelector: SoundSelector
    @State private var isHovered = false
    @State private var selectedSound: NotificationSound = AppSettings.notificationSound

    private var isExpanded: Bool {
        soundSelector.isPickerExpanded
    }

    private func setExpanded(_ value: Bool) {
        soundSelector.isPickerExpanded = value
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row - shows current selection
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    setExpanded(!isExpanded)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 12))
                        .foregroundColor(textColor)
                        .frame(width: 16)

                    Text("Notification Sound")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textColor)

                    Spacer()

                    Text(selectedSound.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
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

            // Expanded sound list
            if isExpanded {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(NotificationSound.allCases, id: \.self) { sound in
                            SoundOptionRowInline(
                                sound: sound,
                                isSelected: selectedSound == sound
                            ) {
                                // Play preview sound
                                if let soundName = sound.soundName {
                                    NSSound(named: soundName)?.play()
                                }
                                selectedSound = sound
                                AppSettings.notificationSound = sound
                            }
                        }
                    }
                }
                // RIGID size, not `maxHeight`. ScrollView is intrinsically flexible
                // and `.frame(maxHeight:)` only caps its upper bound, so under any
                // parent height pressure it will collapse toward 0. That made the
                // picker silently fail to open whenever the surrounding panel hadn't
                // already grown to make room. Using `.frame(height:)` forces the
                // ScrollView to always ask for exactly the height it needs, which
                // lets `NotchMenuView`'s GeometryReader observe the real expanded
                // height and grow `openedSize` to match.
                .frame(height: CGFloat(min(NotificationSound.allCases.count, 6)) * 32)
                .padding(.leading, 2)
                .padding(.top, 4)
            }
        }
        .onAppear {
            selectedSound = AppSettings.notificationSound
        }
    }

    private var textColor: Color {
        .white.opacity(isHovered ? 1.0 : 0.7)
    }
}

// MARK: - Sound Option Row (Inline version)

private struct SoundOptionRowInline: View {
    let sound: NotificationSound
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? TerminalColors.green : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)

                Text(sound.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(isHovered ? 1.0 : 0.7))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(TerminalColors.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            // Make the full row rectangle hit-testable. Without this, SwiftUI's
            // Button only hit-tests opaque content (Text/Circle/Image), so the
            // Spacer gap and the empty trailing area where the checkmark would
            // be don't register hover, and `Color.clear` backgrounds don't help.
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
