import SwiftUI
import Combine

enum IslandTab: String, CaseIterable, Identifiable {
    case music = "Music"
    case stats = "Stats"
    case timer = "Timer"
    case weather = "Weather"
    case calendar = "Calendar"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .music: return "music.note"
        case .stats: return "cpu"
        case .timer: return "timer"
        case .weather: return "cloud.sun.fill"
        case .calendar: return "calendar"
        }
    }
}

/// The single most relevant thing to surface right now (iPhone-style live activity).
enum IslandActivity: Equatable {
    case idle, music, timer, calendar, battery, audioDevice

    var tab: IslandTab? {
        switch self {
        case .music:       return .music
        case .timer:       return .timer
        case .calendar:    return .calendar
        case .battery:     return .stats
        case .audioDevice: return nil
        case .idle:        return nil
        }
    }
}

class AppState: ObservableObject {
    static let shared = AppState()

    // Core expansion and routing (transient — not persisted)
    @Published var isExpanded: Bool = false
    @Published var activeTab: IslandTab = .music
    @Published var isHovered: Bool = false
    @Published var isScreenLocked: Bool = false
    @Published var islandHidden: Bool = false   // user-toggled show/hide (menu bar + hotkey)
    @Published var isPinned: Bool = false       // pin expanded (ignores hover-collapse)

    private var collapseWork: DispatchWorkItem?

    /// Single source of truth for hover-driven expand/collapse, called from the
    /// AppKit tracking area (reliable on a borderless non-activating panel).
    /// Collapse is debounced so window-resize jitter doesn't cause flicker.
    func setHover(_ hovering: Bool) {
        isHovered = hovering
        guard !isScreenLocked, !isPinned else { return }
        collapseWork?.cancel()
        if hovering {
            // Auto-surface the tab matching the current live-activity.
            if let t = currentActivity.tab { activeTab = t }
            if !isExpanded { HapticManager.shared.triggerExpand() }
            withAnimation(.spring(response: 0.40, dampingFraction: 0.78)) { isExpanded = true }
        } else {
            let work = DispatchWorkItem { [weak self] in
                withAnimation(.spring(response: 0.40, dampingFraction: 0.78)) { self?.isExpanded = false }
            }
            collapseWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: work)
        }
    }

    // ── Persisted user preferences ──────────────────────────────────────────
    @Published var useNotchIntegration: Bool { didSet { persist(useNotchIntegration, .useNotchIntegration) } }
    @Published var topOffset: CGFloat { didSet { persist(Double(topOffset), .topOffset) } }
    @Published var opacityValue: Double { didSet { persist(opacityValue, .opacityValue) } }
    @Published var hideFromCapture: Bool { didSet { persist(hideFromCapture, .hideFromCapture) } }
    @Published var accentColorIndex: Int { didSet { persist(accentColorIndex, .accentColorIndex) } } // 0: Auto, 1: Cyan, 2: Purple, 3: Orange, 4: Green
    @Published var audioSource: Int { didSet { persist(audioSource, .audioSource) } } // 0: Auto, 1: Spotify, 2: Apple Music
    @Published var lockSoundEnabled: Bool { didSet { persist(lockSoundEnabled, .lockSoundEnabled) } }
    @Published var launchAtLogin: Bool { didSet { LoginItem.setEnabled(launchAtLogin) } }

    // Drag gestures tracking
    @Published var dragOffset: CGSize = .zero
    @Published var userSavedPosition: CGPoint? = nil

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Persistence

    private enum Key: String {
        case useNotchIntegration, topOffset, opacityValue, hideFromCapture, accentColorIndex, audioSource, lockSoundEnabled
    }

    private func persist<T>(_ value: T, _ key: Key) {
        UserDefaults.standard.set(value, forKey: "nimbus.\(key.rawValue)")
    }

    private init() {
        let d = UserDefaults.standard
        // Register sensible defaults so first launch matches the original design.
        d.register(defaults: [
            "nimbus.useNotchIntegration": true,
            "nimbus.topOffset": 8.0,
            "nimbus.opacityValue": 0.85,
            "nimbus.hideFromCapture": false,
            "nimbus.accentColorIndex": 0,
            "nimbus.audioSource": 0,
            "nimbus.lockSoundEnabled": true,
        ])
        useNotchIntegration = d.bool(forKey: "nimbus.\(Key.useNotchIntegration.rawValue)")
        topOffset           = CGFloat(d.double(forKey: "nimbus.\(Key.topOffset.rawValue)"))
        opacityValue        = d.double(forKey: "nimbus.\(Key.opacityValue.rawValue)")
        hideFromCapture     = d.bool(forKey: "nimbus.\(Key.hideFromCapture.rawValue)")
        accentColorIndex    = d.integer(forKey: "nimbus.\(Key.accentColorIndex.rawValue)")
        audioSource         = d.integer(forKey: "nimbus.\(Key.audioSource.rawValue)")
        lockSoundEnabled    = d.bool(forKey: "nimbus.\(Key.lockSoundEnabled.rawValue)")
        launchAtLogin       = LoginItem.isEnabled
    }
    
    func setupSubscriptions(music: MusicManager, timer: TimerManager) {
        // Only trigger a resize when the PLAYER TYPE or TIMER ACTIVE state changes —
        // NOT on every isPlaying tick (which fires every 1s and doesn't affect window size).
        Publishers.CombineLatest(
            music.$activePlayer.map(\.rawValue),
            timer.$isActive
        )
        .removeDuplicates(by: { $0 == $1 })
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)

        // Resize the island when lyrics become (un)available or playback toggles.
        Publishers.CombineLatest(LyricsManager.shared.$available, music.$isPlaying)
            .removeDuplicates(by: { $0 == $1 })
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Re-evaluate the live-activity when battery or an imminent event changes.
        Publishers.CombineLatest3(
            SystemStatsManager.shared.$batteryLevel,
            SystemStatsManager.shared.$isBatteryCharging,
            CalendarManager.shared.$imminentTitle
        )
        .map { "\($0)-\($1)-\($2 ?? "")" }
        .removeDuplicates()
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.objectWillChange.send() }
        .store(in: &cancellables)

        // Pop the island when an audio device connects.
        AudioDeviceManager.shared.$showConnected
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self?.objectWillChange.send() }
            }
            .store(in: &cancellables)
    }
    
    /// Priority-ordered "what matters now". Timer > playing music > imminent event
    /// > low battery > paused music > idle.
    var currentActivity: IslandActivity {
        if AudioDeviceManager.shared.showConnected { return .audioDevice }   // transient, top priority
        if TimerManager.shared.isActive { return .timer }
        if MusicManager.shared.isPlaying { return .music }
        if CalendarManager.shared.imminentTitle != nil { return .calendar }
        let stats = SystemStatsManager.shared
        if !stats.isBatteryCharging && stats.batteryLevel <= 20 { return .battery }
        if MusicManager.shared.activePlayer != .none { return .music }   // paused
        return .idle
    }

    var currentSize: CGSize {
        // If locked: large bottom player card
        if isScreenLocked {
            return CGSize(width: 390, height: 240)
        }
        
        if isExpanded {
            switch activeTab {
            case .music:
                // Taller when synced lyrics are available, to fit the karaoke strip.
                return CGSize(width: 360, height: LyricsManager.shared.available ? 248 : 178)
            case .stats:
                return CGSize(width: 360, height: 206)
            case .timer:
                return CGSize(width: 300, height: 160)
            case .weather:
                return CGSize(width: 340, height: 170)
            case .calendar:
                return CGSize(width: 320, height: 150)
            }
        } else {
            // Collapsed size matches the current live-activity.
            switch currentActivity {
            case .audioDevice:
                return CGSize(width: 260, height: 40)
            case .timer:
                return CGSize(width: 230, height: 38)
            case .music:
                let wide = LyricsManager.shared.available && MusicManager.shared.isPlaying
                return CGSize(width: wide ? 260 : 150, height: 38)
            case .calendar:
                return CGSize(width: 250, height: 38)
            case .battery:
                return CGSize(width: 175, height: 38)
            case .idle:
                return CGSize(width: 110, height: 30) // Sleek iPhone-style empty pill
            }
        }
    }
    
    var currentAccentColor: Color {
        switch accentColorIndex {
        case 1: return .cyan
        case 2: return .purple
        case 3: return .orange
        case 4: return .green
        default:
            // Auto: depend on current active tab
            switch activeTab {
            case .music:
                return MusicManager.shared.activePlayer == .spotify ? .green : .red
            case .stats:
                return .blue
            case .timer:
                return .orange
            case .weather:
                return .yellow
            case .calendar:
                return .pink
            }
        }
    }
}
