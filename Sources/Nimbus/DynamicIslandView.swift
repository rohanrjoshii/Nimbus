import SwiftUI

struct DynamicIslandView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var music: MusicManager
    @EnvironmentObject var timer: TimerManager
    @EnvironmentObject var stats: SystemStatsManager

    @ObservedObject private var lyrics = LyricsManager.shared
    @ObservedObject private var calendar = CalendarManager.shared
    @ObservedObject private var audio = AudioDeviceManager.shared
    @ObservedObject private var power = PowerManager.shared
    @ObservedObject private var volume = VolumeMonitor.shared

    @State private var pulsePhase: Double = 0.0

    // Lock / unlock flash animation
    @State private var showLockFlash = false
    @State private var lockFlashLocking = true
    @State private var lockFlashScale: CGFloat = 1.0

    // Consistent pill shape used for clipping AND stroke
    private var cornerRadius: CGFloat { (appState.isExpanded || appState.isScreenLocked) ? 32 : 18 }
    private var pillShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    // Overlay darkness, driven by the user's opacity preference (0.3...1.0).
    // Collapsed pill stays slightly more solid so small text/art reads cleanly.
    private var overlayOpacity: Double {
        let base = appState.opacityValue
        return (appState.isExpanded || appState.isScreenLocked) ? base : min(1.0, base + 0.06)
    }

    var body: some View {
        ZStack {
            // ── 1. Frosted glass base (real macOS blur) ─────────────────────
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .behindWindow,
                state: .active,
                cornerRadius: cornerRadius
            )

            // ── 2. Dark overlay — NOT fully opaque so blur shows through ────
            //    Driven by the user's "Background Opacity" preference; collapsed
            //    state stays a touch more solid for legibility at small sizes.
            pillShape
                .fill(Color.black.opacity(overlayOpacity))

            // ── 3. Content router ───────────────────────────────────────────
            Group {
                if appState.isScreenLocked {
                    lockScreenLayout
                } else if appState.isExpanded {
                    expandedLayout
                } else {
                    collapsedLayout
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96)),
                removal: .opacity
            ))

            // ── 4. Soft specular highlight along the very top edge (glass sheen) ──
            pillShape
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(appState.isExpanded ? 0.10 : 0.07), .clear],
                        startPoint: .top, endPoint: .center
                    )
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // ── 5. Two-tone glass border: bright top-light, dark bottom-shade ──
            pillShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(appState.isExpanded ? 0.30 : 0.22),
                            Color.white.opacity(0.06),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.9
                )

            // ── 6. Transient lock / unlock flash ────────────────────────────
            if showLockFlash {
                ZStack {
                    Color.black.opacity(0.28)
                    Image(systemName: lockFlashLocking ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(lockFlashScale)
                        .shadow(color: .black.opacity(0.4), radius: 6)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        // ── Critical: clip ALL layers including content to the pill shape ──
        .clipShape(pillShape)
        // Hover is handled at the AppKit level (IslandHostingView) for reliability.
        .contextMenu {
            Button {
                HapticManager.shared.triggerClick()
                (NSApplication.shared.delegate as? AppDelegate)?.openSettingsWindow()
            } label: { Label("Nimbus Settings…", systemImage: "slider.horizontal.3") }

            Divider()

            Button {
                HapticManager.shared.triggerClick()
                withAnimation(.spring()) { appState.isScreenLocked.toggle() }
            } label: {
                Label(
                    appState.isScreenLocked ? "✓ Lock Screen Mode" : "Lock Screen Mode",
                    systemImage: "lock.shield"
                )
            }

            Button {
                HapticManager.shared.triggerClick()
                appState.isPinned.toggle()
                withAnimation(.spring()) { appState.isExpanded = appState.isPinned }
            } label: { Label(appState.isPinned ? "✓ Pin Expanded" : "Pin Expanded", systemImage: "pin") }

            Divider()

            Button("Quit Nimbus", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
        .onChange(of: appState.isScreenLocked) { triggerLockFlash() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulsePhase = 1.0
            }
        }
    }

    private func triggerLockFlash() {
        lockFlashLocking = appState.isScreenLocked
        lockFlashScale = 0.5
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            showLockFlash = true
            lockFlashScale = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.35)) { showLockFlash = false }
        }
    }

    // MARK: – Collapsed pill

    private var collapsedLayout: some View {
        Group {
            switch appState.currentActivity {
            case .audioDevice:
                HStack(spacing: 10) {
                    Image(systemName: audio.deviceIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(audio.isConnected ? .white : .white.opacity(0.6))
                        .frame(width: 22)
                    Text(audio.deviceName.isEmpty ? "Headphones" : audio.deviceName)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    HStack(spacing: 4) {
                        Circle().fill(audio.isConnected ? Color.green : Color.white.opacity(0.4)).frame(width: 6, height: 6)
                        Text(audio.isConnected ? "Connected" : "Disconnected")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(audio.isConnected ? .green : .white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 15)

            case .charging:
                HStack(spacing: 10) {
                    Image(systemName: power.isCharging ? "bolt.fill" : "battery.50")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(power.isCharging ? .green : .white.opacity(0.85))
                        .frame(width: 20)
                    Text(power.isCharging ? "Charging" : "On Battery")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer(minLength: 6)
                    Text("\(power.level)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(power.isCharging ? .green : .white.opacity(0.8))
                }
                .padding(.horizontal, 15)

            case .volume:
                HStack(spacing: 11) {
                    Image(systemName: volume.muted || volume.volume < 0.01 ? "speaker.slash.fill"
                            : (volume.volume < 0.4 ? "speaker.wave.1.fill" : "speaker.wave.3.fill"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 20)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18)).frame(height: 5)
                            Capsule().fill(.white)
                                .frame(width: max(3, geo.size.width * CGFloat(volume.muted ? 0 : volume.volume)), height: 5)
                                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: volume.volume)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 15)

            case .timer:
                HStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(timer.isPaused ? "Paused" : "Focused")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text(timer.timeFormatted)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 14)

            case .music:
                HStack(spacing: 8) {
                    collapsedArt
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    if let line = lyrics.line(at: lyrics.index), music.isPlaying {
                        Text(line)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(lyrics.index)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: lyrics.index)
                    } else {
                        Spacer()
                        MiniWaveformVisualizer(isPlaying: music.isPlaying, activePlayer: music.activePlayer)
                    }
                }
                .padding(.horizontal, 12)

            case .calendar:
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.pink)
                    Text(calendar.imminentTitle ?? "Upcoming")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Text("in \(calendar.imminentMinutes)m")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.pink)
                }
                .padding(.horizontal, 14)

            case .battery:
                HStack(spacing: 8) {
                    Image(systemName: "battery.25")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                    Text("\(stats.batteryLevel)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Low")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 14)

            case .idle:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.triggerClick()
            if let t = appState.currentActivity.tab { appState.activeTab = t }
            withAnimation(.spring(response: 0.40, dampingFraction: 0.78)) {
                appState.isExpanded = true
            }
        }
    }

    @ViewBuilder
    private var collapsedArt: some View {
        if let img = ArtworkCache.shared.get(title: music.trackTitle, artist: music.trackArtist) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [Color(hue: 0.72, saturation: 0.6, brightness: 0.45),
                         Color(hue: 0.55, saturation: 0.7, brightness: 0.30)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    // MARK: – Expanded pill

    private var expandedLayout: some View {
        VStack(spacing: 0) {
            // ── Tab bar ───────────────────────────────────────────────────────
            HStack(spacing: 2) {
                ForEach(IslandTab.allCases) { tab in
                    let active = appState.activeTab == tab
                    Button {
                        HapticManager.shared.triggerClick()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            appState.activeTab = tab
                        }
                    } label: {
                        HStack(spacing: active ? 5 : 0) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 10.5, weight: active ? .bold : .semibold))
                                .frame(width: 13, height: 13)
                            if active {
                                Text(tab.rawValue)
                                    .font(.system(size: 9.5, weight: .bold))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
                            }
                        }
                        .foregroundColor(active ? .black : Color.white.opacity(0.55))
                        .padding(.horizontal, active ? 10 : 7)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(active ? Color.white : Color.clear)
                        )
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: active)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if appState.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                        .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Hairline divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)

            // ── Widget content ───────────────────────────────────────────────
            Group {
                switch appState.activeTab {
                case .music:
                    MusicWidgetView()
                        .environmentObject(music)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity
                        ))
                case .stats:
                    StatsWidgetView()
                        .environmentObject(stats)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.97)),
                            removal: .opacity
                        ))
                case .timer:
                    TimerWidgetView()
                        .environmentObject(timer)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        ))
                case .weather:
                    WeatherWidgetView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                case .calendar:
                    CalendarWidgetView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: – Lock screen layout (Canopy-inspired)

    private var lockScreenLayout: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Now Playing")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                // Dismiss button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        appState.isScreenLocked = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.25))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)

            // Music widget (same as expanded)
            MusicWidgetView()
                .environmentObject(music)
                .frame(height: 132)

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)

            // System controls: Brightness + Volume
            HStack(spacing: 12) {
                // Brightness
                HStack(spacing: 8) {
                    Image(systemName: "sun.min.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                    BrightnessSlider()
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.65))
                }

                Rectangle().fill(Color.white.opacity(0.10)).frame(width: 0.5, height: 16)

                // Volume
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                    VolumeSlider()
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

// MARK: – Collapsed waveform visualiser

struct MiniWaveformVisualizer: View {
    let isPlaying: Bool
    let activePlayer: MusicManager.MusicPlayerType

    var body: some View {
        HStack(spacing: 1.5) {
            MiniWaveBar(isPlaying: isPlaying, duration: 0.40, maxVal: 10, color: waveColor)
            MiniWaveBar(isPlaying: isPlaying, duration: 0.62, maxVal: 13, color: waveColor)
            MiniWaveBar(isPlaying: isPlaying, duration: 0.32, maxVal:  9, color: waveColor)
        }
        .frame(height: 12)
    }

    private var waveColor: Color {
        switch activePlayer {
        case .spotify:    return .green
        case .appleMusic: return Color(red: 0.98, green: 0.3, blue: 0.35)
        default:          return .white
        }
    }
}

struct MiniWaveBar: View {
    let isPlaying: Bool
    let duration: Double
    let maxVal: CGFloat
    let color: Color
    @State private var h: CGFloat = 3

    var body: some View {
        RoundedRectangle(cornerRadius: 0.75)
            .fill(color)
            .frame(width: 1.5, height: h)
            .onAppear { animate() }
            .onChange(of: isPlaying) {
                if !isPlaying { withAnimation(.spring()) { h = 3 } }
                else { animate() }
            }
    }

    private func animate() {
        guard isPlaying else { return }
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            h = CGFloat.random(in: 4...maxVal)
        }
    }
}
