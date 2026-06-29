import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case behavior = "Behavior"
    case about = "About"

    var id: String { self.rawValue }

    var iconName: String {
        switch self {
        case .general:    return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .behavior:   return "wand.and.stars"
        case .about:      return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var activeTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
        }
        .frame(width: 560, height: 400)
        .background(
            LinearGradient(colors: [Color(red: 0.11, green: 0.11, blue: 0.15),
                                    Color(red: 0.05, green: 0.05, blue: 0.07)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Nimbus").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Text("Settings").font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)

            ForEach(SettingsTab.allCases) { navItem($0) }

            Spacer()

            Text("Version 1.0.0 · Beta")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .padding(.top, 34)   // clear the macOS traffic-light buttons
        .frame(width: 176)
        .background(Color.black.opacity(0.22))
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(width: 0.5), alignment: .trailing)
    }

    private func navItem(_ tab: SettingsTab) -> some View {
        let active = activeTab == tab
        return Button {
            HapticManager.shared.triggerClick()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { activeTab = tab }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 18)
                Text(tab.rawValue).font(.system(size: 12.5, weight: .semibold))
                Spacer()
            }
            .foregroundColor(active ? .white : .white.opacity(0.5))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active
                          ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.27, green: 0.5, blue: 1.0), Color(red: 0.6, green: 0.35, blue: 0.95)], startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(Color.clear))
                    .shadow(color: active ? Color.blue.opacity(0.4) : .clear, radius: 7, y: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            Group {
                switch activeTab {
                case .general:    generalSettings
                case .appearance: appearanceSettings
                case .behavior:   behaviorSettings
                case .about:      aboutView
                }
            }
            .transition(.opacity)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 30)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            Button { SettingsWindow.shared.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }

    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 19, weight: .bold)).foregroundColor(.white)
            Text(subtitle).font(.system(size: 11.5)).foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - General

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("General", "Startup, privacy, and your audio source.")
            SettingsGroup {
                ToggleRow(icon: "power", tint: .green, title: "Launch at Login",
                          subtitle: "Open Nimbus automatically when your Mac starts.",
                          isOn: $appState.launchAtLogin)
                RowDivider()
                ToggleRow(icon: "eye.slash.fill", tint: .indigo, title: "Hide from Screen Capture",
                          subtitle: "Keep the island out of screenshots & recordings.",
                          isOn: $appState.hideFromCapture)
            }
            SettingsGroup {
                VStack(alignment: .leading, spacing: 12) {
                    RowHeader(icon: "music.note", tint: .pink, title: "Preferred Audio Source",
                              subtitle: "Auto-detect what's playing, or force one player.")
                    Picker("", selection: $appState.audioSource) {
                        Text("Auto").tag(0); Text("Spotify").tag(1); Text("Apple Music").tag(2)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .onChange(of: appState.audioSource) {
                        HapticManager.shared.triggerClick()
                        MusicManager.shared.updateTrackInfo()
                    }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Appearance", "Tune how the island looks and sits.")
            SettingsGroup {
                VStack(spacing: 14) {
                    sliderBlock(icon: "circle.lefthalf.filled", tint: .blue, title: "Island Opacity",
                                value: $appState.opacityValue, range: 0.3...1.0,
                                display: "\(Int(appState.opacityValue * 100))%")
                    RowDivider()
                    sliderBlock(icon: "arrow.up.to.line.compact", tint: .teal, title: "Top Offset",
                                value: Binding(get: { Double(appState.topOffset) },
                                               set: { appState.topOffset = CGFloat($0) }),
                                range: 0...40, display: "\(Int(appState.topOffset)) pt")
                }
                .padding(14)
            }
            SettingsGroup {
                VStack(alignment: .leading, spacing: 12) {
                    RowHeader(icon: "paintpalette.fill", tint: .orange, title: "Accent Color",
                              subtitle: "Tint used across the widgets.")
                    HStack(spacing: 16) {
                        ForEach(Array(accentChoices.enumerated()), id: \.offset) { i, c in
                            ColorPickerDot(color: c.0, isSelected: appState.accentColorIndex == i, label: c.1) {
                                appState.accentColorIndex = i
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(14)
            }
        }
    }

    private var accentChoices: [(Color, String)] {
        [(.white, "Auto"), (.cyan, "Cyan"), (.purple, "Purple"), (.orange, "Orange"), (.green, "Green")]
    }

    private func sliderBlock(icon: String, tint: Color, title: String,
                             value: Binding<Double>, range: ClosedRange<Double>, display: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                IconBadge(symbol: icon, tint: tint)
                Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Text(display).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.65))
            }
            Slider(value: value, in: range).tint(tint).controlSize(.small)
        }
    }

    // MARK: - Behavior

    private var behaviorSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Behavior", "How Nimbus reacts to your Mac.")
            SettingsGroup {
                ToggleRow(icon: "macbook", tint: .blue, title: "Snap to Display Top",
                          subtitle: "Attach flush inside or under the notch.",
                          isOn: $appState.useNotchIntegration)
                RowDivider()
                ToggleRow(icon: "lock.fill", tint: .orange, title: "Lock / Unlock Sound",
                          subtitle: "Play a sound on lock & unlock. Drop lock.aiff / unlock.aiff in Sounds/ for your own.",
                          isOn: $appState.lockSoundEnabled)
            }
        }
    }

    // MARK: - About

    private var aboutView: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .shadow(color: .purple.opacity(0.5), radius: 14, y: 5)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 3) {
                Text("Nimbus").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text("Version 1.0.0 (Beta)").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5))
            }

            Text("A Dynamic Island for macOS — live music, synced lyrics, weather, calendar, and system activity, in one glassy overlay.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 28)

            Spacer()

            Text("Made with ♥ by Akshay Joshi")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Premium components

private struct IconBadge: View {
    let symbol: String
    let tint: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(LinearGradient(colors: [tint, tint.opacity(0.62)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 27, height: 27)
            .overlay(Image(systemName: symbol).font(.system(size: 12.5, weight: .bold)).foregroundColor(.white))
            .shadow(color: tint.opacity(0.45), radius: 4, y: 1)
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.04)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 0.6)
            )
    }
}

private struct RowHeader: View {
    let icon: String, tint: Color, title: String, subtitle: String
    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
        }
    }
}

private struct ToggleRow: View {
    let icon: String, tint: Color, title: String, subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).tint(tint)
                .onChange(of: isOn) { HapticManager.shared.triggerClick() }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.6).padding(.leading, 53)
    }
}

struct ColorPickerDot: View {
    let color: Color
    let isSelected: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.triggerClick()
            action()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(color).frame(width: 22, height: 22)
                        .shadow(color: color.opacity(isSelected ? 0.6 : 0.25), radius: isSelected ? 6 : 2)
                    if isSelected {
                        Circle().stroke(Color.white, lineWidth: 2).frame(width: 29, height: 29)
                    }
                }
                .frame(width: 31, height: 31)
                Text(label)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }
}
