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
            // ── Living album-art aurora backdrop ────────────────────────────
            artworkBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 48)
                .opacity(0.42)
                .scaleEffect(breathe ? 1.18 : 1.02)
                .hueRotation(.degrees(breathe ? 7 : -7))
                .allowsHitTesting(false)

            // ── Main content ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 14) {

                // Row 1 ─ Album art + Title / Artist + source dot
                HStack(alignment: .center, spacing: 12) {
                    albumArtView
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(music.trackTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(music.trackArtist)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.50))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 4)

                    // Tiny source colour dot (green Spotify · red Apple Music · white other)
                    Circle()
                        .fill(sourceDotColor)
                        .frame(width: 6, height: 6)
                        .opacity(music.activePlayer == .none ? 0 : 1)
                }

                // Row 2 ─ Scrubber track + time labels
                VStack(spacing: 5) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 3)
                            Capsule()
                                .fill(Color.white.opacity(0.92))
                                .frame(
                                    width: max(0, min(
                                        geo.size.width * CGFloat(
                                            music.trackDuration > 1
                                                ? music.playerPosition / music.trackDuration
                                                : 0
                                        ),
                                        geo.size.width
                                    )),
                                    height: 3
                                )
                                .animation(.linear(duration: 0.6), value: music.playerPosition)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    let pct = Double(max(0, min(v.location.x / geo.size.width, 1)))
                                    music.seek(to: pct * music.trackDuration)
                                }
                        )
                    }
                    .frame(height: 3)

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
