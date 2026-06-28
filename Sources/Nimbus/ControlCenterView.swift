import SwiftUI

/// The Nimbus Control Center — a minimalist glass popover from the menu bar.
struct ControlCenterView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var music: MusicManager
    @ObservedObject private var weather = WeatherManager.shared
    @ObservedObject private var artwork = ArtworkCache.shared

    var body: some View {
        VStack(spacing: 14) {
            header
            nowPlayingCard
            controlGroup
            weatherRow
            hideButton
            secondaryToggles
            footer
        }
        .padding(16)
        .frame(width: 286, height: 474, alignment: .top)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .preferredColorScheme(.dark)
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("Nimbus")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Button {
                HapticManager.shared.triggerClick()
                (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Now playing
    private var nowPlayingCard: some View {
        HStack(spacing: 12) {
            art
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 5, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(music.trackTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white).lineLimit(1)
                Text(music.trackArtist)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer()

            HStack(spacing: 14) {
                ctlIcon("backward.fill", 13) { music.prevTrack() }
                ctlIcon(music.isPlaying ? "pause.fill" : "play.fill", 16) { music.togglePlayPause() }
                ctlIcon("forward.fill", 13) { music.nextTrack() }
            }
        }
        .padding(12)
        .background(glassCard)
    }

    @ViewBuilder private var art: some View {
        if let img = artwork.get(title: music.trackTitle, artist: music.trackArtist), music.activePlayer != .none {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(colors: [Color(hue: 0.72, saturation: 0.6, brightness: 0.4),
                                        Color(hue: 0.55, saturation: 0.7, brightness: 0.28)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note").font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: Sound + Brightness
    private var controlGroup: some View {
        VStack(spacing: 12) {
            sliderRow(lowIcon: "sun.min.fill", highIcon: "sun.max.fill") { BrightnessSlider() }
            sliderRow(lowIcon: "speaker.fill", highIcon: "speaker.wave.3.fill") { VolumeSlider() }
        }
        .padding(14)
        .background(glassCard)
    }

    private func sliderRow<S: View>(lowIcon: String, highIcon: String, @ViewBuilder slider: () -> S) -> some View {
        HStack(spacing: 10) {
            Image(systemName: lowIcon).font(.system(size: 10)).foregroundColor(.white.opacity(0.5)).frame(width: 14)
            slider()
            Image(systemName: highIcon).font(.system(size: 11)).foregroundColor(.white.opacity(0.7)).frame(width: 16)
        }
    }

    // MARK: Weather (safe, pure-SwiftUI — replaces the crash-prone embedded map)
    private var weatherRow: some View {
        HStack(spacing: 12) {
            Image(systemName: weather.symbol)
                .font(.system(size: 22))
                .foregroundStyle(weather.symbolColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(weather.isLoaded ? "\(weather.temperature)\(weather.unitSymbol)" : "—")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(weather.conditionText)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            Text(weather.locationName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(13)
        .background(glassCard)
    }

    // MARK: Quick toggles
    // Prominent primary control: hide / show the island, with hotkey hint.
    private var hideButton: some View {
        Button {
            HapticManager.shared.triggerClick()
            appState.islandHidden.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: appState.islandHidden ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(appState.islandHidden ? "Show Dynamic Island" : "Hide Dynamic Island")
                    .font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Text("⌥⌘A")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(appState.islandHidden
                          ? LinearGradient(colors: [.cyan.opacity(0.35), .purple.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.07)], startPoint: .leading, endPoint: .trailing))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private var secondaryToggles: some View {
        HStack(spacing: 8) {
            toggle("moon.fill", "Lock Card", appState.isScreenLocked) {
                withAnimation(.spring()) { appState.isScreenLocked.toggle() }
            }
            toggle("camera.fill", "Hide Capture", appState.hideFromCapture) {
                appState.hideFromCapture.toggle()
            }
        }
    }

    private func toggle(_ icon: String, _ label: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.triggerClick()
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(label).font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(on ? .black : .white.opacity(0.8))
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(on ? Color.white : Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Footer
    private var footer: some View {
        HStack {
            Button {
                (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
            } label: {
                Label("Settings", systemImage: "gearshape").font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }.buttonStyle(.plain)
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power").font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }.buttonStyle(.plain)
        }
    }

    // MARK: Helpers
    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func ctlIcon(_ name: String, _ size: CGFloat, _ action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.triggerClick()
            action()
        } label: {
            Image(systemName: name).font(.system(size: size, weight: .medium))
                .foregroundColor(.white).frame(width: size + 8, height: size + 8)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

