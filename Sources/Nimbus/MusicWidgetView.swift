import SwiftUI

struct MusicWidgetView: View {
    @EnvironmentObject var music: MusicManager
    @EnvironmentObject var appState: AppState
    @StateObject private var artworkCache = ArtworkCache.shared
    @ObservedObject private var lyrics = LyricsManager.shared

    @State private var gradientRotation: Double = 0.0
    @State private var breathe = false

    private var sourceDotColor: Color {
        switch music.activePlayer {
        case .spotify:    return .green
        case .appleMusic: return Color(red: 0.98, green: 0.3, blue: 0.35)
        default:          return .white
        }
    }

    private var elapsed: String { formatTime(music.playerPosition) }
    private var remaining: String {
        let r = max(0, music.trackDuration - music.playerPosition)
        return (r > 0 && music.trackDuration > 1) ? "-" + formatTime(r) : "-0:00"
    }

    var body: some View {
        ZStack {
            // ── Living album-art backdrop + depth gradient ──────────────────
            artworkBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 55)
                .opacity(0.5)
                .scaleEffect(breathe ? 1.2 : 1.05)
                .hueRotation(.degrees(breathe ? 6 : -6))
                .allowsHitTesting(false)
            LinearGradient(colors: [Color.white.opacity(0.05), .clear, Color.black.opacity(0.42)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            // ── Main content ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 14) {

                // Row 1 ─ Album art + Title / Artist + source dot
                HStack(alignment: .center, spacing: 13) {
                    albumArtView
                        .frame(width: 62, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.55), radius: 11, x: 0, y: 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(music.trackTitle)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        HStack(spacing: 6) {
                            Circle().fill(sourceDotColor).frame(width: 5, height: 5)
                                .opacity(music.activePlayer == .none ? 0 : 1)
                            Text(music.trackArtist)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.55))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer(minLength: 6)

                    // Now-playing equaliser in the source colour
                    if music.isPlaying && music.activePlayer != .none {
                        MiniWaveformVisualizer(isPlaying: true, activePlayer: music.activePlayer)
                            .frame(width: 16)
                    }
                }

                // Row 2 ─ Scrubber track + time labels
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let frac = music.trackDuration > 1 ? CGFloat(music.playerPosition / music.trackDuration) : 0
                        let w = max(0, min(geo.size.width * frac, geo.size.width))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.16)).frame(height: 4)
                            Capsule().fill(Color.white.opacity(0.95)).frame(width: w, height: 4)
                                .animation(.linear(duration: 0.6), value: music.playerPosition)
                            Circle().fill(.white).frame(width: 10, height: 10)
                                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                                .offset(x: w - 5)
                                .animation(.linear(duration: 0.6), value: music.playerPosition)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    let pct = Double(max(0, min(v.location.x / geo.size.width, 1)))
                                    music.seek(to: pct * music.trackDuration)
                                }
                        )
                    }
                    .frame(height: 10)

                    HStack {
                        Text(elapsed)
                        Spacer()
                        Text(remaining)
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.38))
                }

                // Row 3 ─ Transport controls
                HStack(spacing: 0) {
                    TransportButton(icon: "shuffle", size: 12, dim: true) {}
                    Spacer()
                    TransportButton(icon: "backward.fill", size: 19) { music.prevTrack() }
                    Spacer()
                    TransportButton(icon: music.isPlaying ? "pause.fill" : "play.fill", size: 20, primary: true) {
                        music.togglePlayPause()
                    }
                    Spacer()
                    TransportButton(icon: "forward.fill", size: 19) { music.nextTrack() }
                    Spacer()
                    TransportButton(icon: "repeat", size: 12, dim: true) {}
                }

                // Row 4 ─ Synced karaoke lyrics (only when available)
                if lyrics.available { lyricsStrip }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .onAppear {
            artworkCache.fetchArtwork(title: music.trackTitle, artist: music.trackArtist)
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .onChange(of: music.trackTitle) {
            artworkCache.fetchArtwork(title: music.trackTitle, artist: music.trackArtist)
        }
    }

    // MARK: – Karaoke lyrics

    private var lyricsStrip: some View {
        VStack(spacing: 3) {
            Text(lyrics.line(at: lyrics.index) ?? "♪ ♪ ♪")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .id("cur-\(lyrics.index)")
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity))
            Text(lyrics.line(at: lyrics.index + 1) ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: lyrics.index)
    }

    // MARK: – Sub-views

    @ViewBuilder
    private var albumArtView: some View {
        if let img = artworkCache.get(title: music.trackTitle, artist: music.trackArtist),
           music.activePlayer != .none {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: 0.72, saturation: 0.6, brightness: 0.45),
                        Color(hue: 0.55, saturation: 0.7, brightness: 0.30)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .hueRotation(.degrees(gradientRotation))
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.white.opacity(music.activePlayer == .none ? 0.35 : 0.7))
            }
        }
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let img = artworkCache.get(title: music.trackTitle, artist: music.trackArtist),
           music.activePlayer != .none {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [
                    Color(hue: 0.72, saturation: 0.5, brightness: 0.3),
                    Color(hue: 0.55, saturation: 0.6, brightness: 0.2)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private func formatTime(_ s: Double) -> String {
        let t = Int(max(0, s))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

// MARK: – Premium transport button

/// A music transport control with hover-scale, press feedback, and an optional
/// filled "primary" treatment (the play/pause button) for an Apple-Music feel.
struct TransportButton: View {
    let icon: String
    let size: CGFloat
    var primary: Bool = false
    var dim: Bool = false
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: { HapticManager.shared.triggerClick(); action() }) {
            ZStack {
                if primary {
                    Circle()
                        .fill(Color.white)
                        .frame(width: size + 24, height: size + 24)
                        .shadow(color: .black.opacity(0.3), radius: 7, y: 2)
                } else if hover {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: size + 18, height: size + 18)
                }
                Image(systemName: icon)
                    .font(.system(size: size, weight: primary ? .heavy : .semibold))
                    .foregroundColor(iconColor)
            }
            .frame(width: size + (primary ? 24 : 18), height: size + (primary ? 24 : 18))
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle(hover: hover))
        .onHover { hover = $0 }
    }

    private var iconColor: Color {
        if primary { return .black }
        if dim { return .white.opacity(hover ? 0.75 : 0.42) }
        return .white.opacity(hover ? 1.0 : 0.85)
    }
}

/// Scale on hover + press, using the standard ButtonStyle press detection
/// (no extra gestures, so it never interferes with the tap).
struct PressScaleButtonStyle: ButtonStyle {
    var hover: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : (hover ? 1.07 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hover)
    }
}

// MARK: – Waveform / WaveBar helpers (used by DynamicIslandView collapsed state)

struct WaveformVisualizer: View {
    let isPlaying: Bool
    var body: some View {
        HStack(spacing: 2) {
            WaveBar(isPlaying: isPlaying, duration: 0.5)
            WaveBar(isPlaying: isPlaying, duration: 0.7)
            WaveBar(isPlaying: isPlaying, duration: 0.4)
            WaveBar(isPlaying: isPlaying, duration: 0.65)
            WaveBar(isPlaying: isPlaying, duration: 0.55)
        }
        .frame(height: 24)
    }
}

struct WaveBar: View {
    let isPlaying: Bool
    let duration: Double
    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white.opacity(0.85))
            .frame(width: 2.5, height: height)
            .onAppear { startAnimation() }
            .onChange(of: isPlaying) {
                if !isPlaying {
                    withAnimation(.spring()) { height = 4 }
                } else {
                    startAnimation()
                }
            }
    }

    private func startAnimation() {
        guard isPlaying else { return }
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            height = CGFloat.random(in: 8...20)
        }
    }
}
