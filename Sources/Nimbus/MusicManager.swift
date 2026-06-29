import Foundation
import Combine
import AppKit

class MusicManager: ObservableObject {
    static let shared = MusicManager()

    @Published var isPlaying: Bool = false
    @Published var trackTitle: String = "Not Playing"
    @Published var trackArtist: String = ""
    @Published var playerPosition: Double = 0.0
    @Published var trackDuration: Double = 1.0
    @Published var activePlayer: MusicPlayerType = .none

    @Published var isSimulated: Bool = false
    @Published var isMediaRemoteAvailable: Bool = false

    enum MusicPlayerType: String {
        case appleMusic = "Apple Music"
        case spotify = "Spotify"
        case system = "Now Playing"   // any other media app (browsers/YouTube/etc.) via MediaRemote
        case simulated = "Demo Player"
        case none = "None"
    }

    private var mainTimer: Timer?
    private var simulationTimer: Timer?

    // Serial poll queue + re-entrancy guard: never let a slow osascript poll
    // pile up across 1s ticks (that pile-up was the cause of the hang/lag).
    private let pollQueue = DispatchQueue(label: "com.akshayjoshi.nimbus.poll", qos: .userInitiated)
    private var pollPending = false
    private var isBrowserSource = false   // current .system track came from a browser tab (controllable via JS)

    // Dynamic MediaRemote function pointers — system-wide now-playing + transport control.
    private typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping (CFDictionary) -> Void) -> Void
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int, CFDictionary?) -> Bool
    private var mrGetNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    private var mrSendCommand: MRMediaRemoteSendCommandFunction?

    // MRCommand constants
    private let kMRTogglePlayPause = 2, kMRNextTrack = 4, kMRPreviousTrack = 5

    private init() {
        setupMediaRemote()
        startPolling()
    }

    private func setupMediaRemote() {
        let bundlePath = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, URL(fileURLWithPath: bundlePath) as CFURL) else { return }

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            mrGetNowPlayingInfo = unsafeBitCast(ptr, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        }
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            mrSendCommand = unsafeBitCast(ptr, to: MRMediaRemoteSendCommandFunction.self)
        }

        // Listen for now-playing change notifications to get faster artwork updates
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(mediaRemoteDidChange),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil
        )
    }

    @objc private func mediaRemoteDidChange() {
        // Only use MediaRemote for artwork enrichment after we've already identified the player
        if activePlayer != .none {
            fetchArtworkViaMediaRemote()
        }
    }

    // MARK: - Main Polling Loop

    func startPolling() {
        mainTimer?.invalidate()
        mainTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
        // Immediate first poll
        updateTrackInfo()
    }

    private func timerTick() {
        guard !isSimulated else {
            // Simulation: just let simulationTimer increment position
            return
        }
        updateTrackInfo()
    }

    // MARK: - Core Sync

    func updateTrackInfo() {
        guard !isSimulated else { return }
        guard !pollPending else { return }   // a poll is still running — skip, never pile up
        pollPending = true

        let source = AppState.shared.audioSource
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.pollPending = false } }
            self.performPoll(source: source)
        }
    }

    /// Runs synchronously on the serial pollQueue (one poll at a time).
    private func performPoll(source: Int) {
        switch source {
        case 1: // forced Spotify
            if let info = querySpotify() { DispatchQueue.main.async { self.applyTrackInfo(info, player: .spotify) } }
            else { DispatchQueue.main.async { self.setNotPlaying() } }
        case 2: // forced Apple Music
            if let info = queryAppleMusic() { DispatchQueue.main.async { self.applyTrackInfo(info, player: .appleMusic) } }
            else { DispatchQueue.main.async { self.setNotPlaying() } }
        default:
            performAutoPoll()
        }
    }

    private func performAutoPoll() {
        if isAppRunning("Spotify"), let info = querySpotify() {
            let parts = info.components(separatedBy: "|")
            if parts.count >= 2 && parts[0] != "stopped" {
                DispatchQueue.main.async { self.applyTrackInfo(info, player: .spotify) }
                return
            }
        }
        if isAppRunning("Music"), let info = queryAppleMusic() {
            let parts = info.components(separatedBy: "|")
            if parts.count >= 2 && parts[0] != "stopped" {
                DispatchQueue.main.async { self.applyTrackInfo(info, player: .appleMusic) }
                return
            }
        }
        // Browser fallback — only when a browser is frontmost (a single cheap osascript).
        if let b = queryBrowser() {
            DispatchQueue.main.async {
                self.applyNowPlaying(title: b.title, artist: b.artist, pos: b.pos, dur: b.dur,
                                     playing: b.playing, artwork: nil, browser: true)
            }
            if let art = b.artworkURL { fetchRemoteArtwork(art, title: b.title, artist: b.artist) }
            return
        }
        fetchNowPlayingViaMediaRemote()
    }

    // MARK: - Browser tab fallback (YouTube etc.)

    struct BrowserTrack { let title: String; let artist: String; let artworkURL: String?
                          let pos: Double; let dur: Double; let playing: Bool }

    /// The frontmost app if it's a supported browser → (AppleScript name, isSafari).
    private func frontmostBrowser() -> (app: String, isSafari: Bool)? {
        guard let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() else { return nil }
        if front.contains("google.chrome") { return ("Google Chrome", false) }
        if front.contains("brave")          { return ("Brave Browser", false) }
        if front.contains("edgemac")        { return ("Microsoft Edge", false) }
        if front.contains("thebrowser") || front.hasSuffix(".arc") { return ("Arc", false) }
        if front.contains("apple.safari")   { return ("Safari", true) }
        return nil
    }

    /// Reads the frontmost browser's active media tab — title, thumbnail, and the
    /// real <video> position/duration/play-state via injected JavaScript.
    /// (JS needs "Allow JavaScript from Apple Events" enabled in the browser.)
    private func queryBrowser() -> BrowserTrack? {
        guard let b = frontmostBrowser() else { return nil }
        let tab = b.isSafari ? "current tab of front window" : "active tab of front window"
        let titleProp = b.isSafari ? "name" : "title"
        let js = "(function(){var v=document.querySelector('video');if(!v)return '';return v.currentTime+'|'+v.duration+'|'+(v.paused?'0':'1');})()"
        let exec = b.isSafari ? "do JavaScript jsCode in \(tab)" : "execute \(tab) javascript jsCode"
        let script = """
        tell application "\(b.app)"
            if (count of windows) is 0 then return ""
            set t to \(titleProp) of \(tab)
            set u to URL of \(tab)
            set jsCode to "\(js)"
            set vi to ""
            try
                set vi to (\(exec)) as text
            end try
            return u & "|||" & t & "|||" & vi
        end tell
        """
        return parseBrowserResult(runAppleScript(script))
    }

    private func parseBrowserResult(_ out: String?) -> BrowserTrack? {
        guard let out = out else { return nil }
        let parts = out.components(separatedBy: "|||")
        guard parts.count >= 2 else { return nil }
        let url = parts[0].lowercased()
        guard url.contains("youtube.com/watch") || url.contains("music.youtube.com")
                || url.contains("soundcloud.com/") || url.contains("open.spotify.com/") else { return nil }
        let title = cleanMediaTitle(parts[1])
        guard !title.isEmpty else { return nil }

        var pos = 0.0, dur = 0.0, playing = true
        if parts.count >= 3 {
            let vi = parts[2].trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
            if vi.count >= 3 {
                pos = Double(vi[0]).flatMap { $0.isFinite ? $0 : nil } ?? 0
                dur = Double(vi[1]).flatMap { $0.isFinite ? $0 : nil } ?? 0
                playing = (vi[2] == "1")
            }
        }
        let source = url.contains("youtube") ? "YouTube" : (url.contains("soundcloud") ? "SoundCloud" : "Web")
        return BrowserTrack(title: title, artist: source, artworkURL: youtubeThumbnail(from: parts[0]),
                            pos: pos, dur: dur, playing: playing)
    }

    /// Injects JS into the frontmost browser's active tab (for transport control).
    private func runBrowserJS(_ js: String) {
        guard let b = frontmostBrowser() else { return }
        let tab = b.isSafari ? "current tab of front window" : "active tab of front window"
        let exec = b.isSafari ? "do JavaScript jsCode in \(tab)" : "execute \(tab) javascript jsCode"
        let script = """
        tell application "\(b.app)"
            set jsCode to "\(js)"
            try
                \(exec)
            end try
        end tell
        """
        _ = runAppleScript(script)
    }

    private func cleanMediaTitle(_ raw: String) -> String {
        var s = raw
        if s.hasPrefix("("), let r = s.range(of: ") ") { s = String(s[r.upperBound...]) }  // strip "(3) "
        for suffix in [" - YouTube Music", " - YouTube", " | SoundCloud", " - SoundCloud"] {
            if s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)) }
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private func youtubeThumbnail(from url: String) -> String? {
        guard let comps = URLComponents(string: url),
              let id = comps.queryItems?.first(where: { $0.name == "v" })?.value else { return nil }
        return "https://img.youtube.com/vi/\(id)/hqdefault.jpg"
    }

    private func fetchRemoteArtwork(_ urlStr: String, title: String, artist: String) {
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let img = NSImage(data: data) else { return }
            DispatchQueue.main.async { ArtworkCache.shared.cachedImages["\(title)-\(artist)"] = img }
        }.resume()
    }

    // MARK: - Apply Track State

    private func applyTrackInfo(_ info: String, player: MusicPlayerType) {
        let parts = info.components(separatedBy: "|")
        guard parts.count >= 5 else {
            setNotPlaying()
            return
        }

        let state = parts[0]   // "playing" | "paused" | "stopped"
        let title = parts[1]
        let artist = parts[2]
        let pos = Double(parts[3]) ?? 0.0
        let dur = Double(parts[4]) ?? 1.0

        guard state != "stopped" else {
            setNotPlaying()
            return
        }

        let playing = (state == "playing")
        let safeTitle = title.isEmpty ? "Unknown Title" : title
        let safeArtist = artist.isEmpty ? "Unknown Artist" : artist
        isBrowserSource = false

        // Only update if something actually changed (avoid redundant SwiftUI redraws)
        if self.trackTitle != safeTitle || self.trackArtist != safeArtist || self.activePlayer != player {
            self.trackTitle = safeTitle
            self.trackArtist = safeArtist
            self.activePlayer = player
            // Kick off artwork + lyrics fetch on track change
            ArtworkCache.shared.fetchArtwork(title: safeTitle, artist: safeArtist)
            LyricsManager.shared.load(title: safeTitle, artist: safeArtist, duration: dur)
        }
        // Always immediately reflect play/pause state from Spotify
        self.isPlaying = playing

        // Always use Spotify's reported position as ground truth.
        // Only smooth-advance locally (+1s) when playing AND we're close (avoids stutter)
        // but always snap to real value when paused or significantly drifted.
        let delta = abs(self.playerPosition - pos)
        if !playing || delta > 3.0 {
            // Paused or drifted: always snap to real position
            self.playerPosition = pos
        } else if playing && delta <= 3.0 {
            // Playing and close: advance by 1s locally for smooth scrubber motion
            self.playerPosition = min(self.playerPosition + 1.0, dur)
        }
        self.trackDuration = dur > 0 ? dur : 1.0
        LyricsManager.shared.update(position: self.playerPosition)
    }

    private func setNotPlaying() {
        guard activePlayer != .simulated else { return }
        isBrowserSource = false
        isPlaying = false
        trackTitle = "Not Playing"
        trackArtist = "Play music anywhere"
        playerPosition = 0.0
        trackDuration = 1.0
        activePlayer = .none
        LyricsManager.shared.clear()
    }

    // MARK: - System Now Playing (any app, via MediaRemote)

    private func fetchNowPlayingViaMediaRemote() {
        guard let getInfo = mrGetNowPlayingInfo else {
            DispatchQueue.main.async { self.setNotPlaying() }
            return
        }
        getInfo(DispatchQueue.global(qos: .userInitiated)) { [weak self] dict in
            guard let self = self else { return }
            let info = dict as NSDictionary
            let title = (info["kMRMediaRemoteNowPlayingInfoTitle"] as? String) ?? ""
            guard !title.isEmpty else {
                DispatchQueue.main.async { self.setNotPlaying() }
                return
            }
            let artist  = (info["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? ""
            let elapsed = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double) ?? 0
            let dur     = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double) ?? 0
            let rate    = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 0
            let artData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            DispatchQueue.main.async {
                self.applyNowPlaying(title: title, artist: artist, pos: elapsed,
                                     dur: dur, playing: rate > 0, artwork: artData)
            }
        }
    }

    private func applyNowPlaying(title: String, artist: String, pos: Double,
                                 dur: Double, playing: Bool, artwork: Data?, browser: Bool = false) {
        guard !isSimulated else { return }
        isBrowserSource = browser

        if trackTitle != title || trackArtist != artist || activePlayer != .system {
            trackTitle = title
            trackArtist = artist
            activePlayer = .system
            let key = "\(title)-\(artist)"
            if let artwork = artwork, let img = NSImage(data: artwork) {
                ArtworkCache.shared.cachedImages[key] = img   // embedded artwork (e.g. YouTube thumbnail)
            } else {
                ArtworkCache.shared.fetchArtwork(title: title, artist: artist)
            }
            LyricsManager.shared.load(title: title, artist: artist, duration: dur)
        }
        isPlaying = playing

        let d = dur > 0 ? dur : 1.0
        let delta = abs(playerPosition - pos)
        if !playing || delta > 3.0 {
            playerPosition = min(pos, d)
        } else {
            playerPosition = min(playerPosition + 1.0, d)
        }
        trackDuration = d
        LyricsManager.shared.update(position: playerPosition)
    }

    // MARK: - Artwork via MediaRemote

    private func fetchArtworkViaMediaRemote() {
        guard let getInfo = mrGetNowPlayingInfo else { return }
        getInfo(DispatchQueue.global(qos: .background)) { [weak self] dict in
            guard let self = self else { return }
            let info = dict as NSDictionary
            guard let artData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data,
                  let image = NSImage(data: artData) else { return }
            DispatchQueue.main.async {
                let key = "\(self.trackTitle)-\(self.trackArtist)"
                ArtworkCache.shared.cachedImages[key] = image
            }
        }
    }

    // MARK: - Simulated Player

    func enableSimulation() {
        isSimulated = true
        activePlayer = .simulated
        trackTitle = "Glimpse of Us"
        trackArtist = "Joji"
        trackDuration = 233.0
        playerPosition = 157.0
        isPlaying = true

        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isSimulated, self.isPlaying else { return }
            self.playerPosition += 1.0
            if self.playerPosition >= self.trackDuration { self.playerPosition = 0 }
        }
    }

    func disableSimulation() {
        isSimulated = false
        simulationTimer?.invalidate()
        updateTrackInfo()
    }

    // MARK: - Workspace App Check

    private func isAppRunning(_ name: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.localizedName?.lowercased() == name.lowercased() ||
            $0.bundleIdentifier?.lowercased().contains(name.lowercased()) == true
        }
    }

    // MARK: - Transport Controls

    func togglePlayPause() {
        if isSimulated { isPlaying.toggle(); return }
        isPlaying.toggle()   // optimistic — instant UI feedback
        let player = activePlayer
        let browser = isBrowserSource
        runTransport {
            switch player {
            case .spotify where self.isAppRunning("Spotify"):
                _ = self.runAppleScript("tell application \"Spotify\" to playpause")
            case .appleMusic where self.isAppRunning("Music"):
                _ = self.runAppleScript("tell application \"Music\" to playpause")
            case .system:
                if browser { self.runBrowserJS("var v=document.querySelector('video');if(v){v.paused?v.play():v.pause();}") }
                else { _ = self.mrSendCommand?(self.kMRTogglePlayPause, nil) }
            case .none:
                if self.isAppRunning("Spotify") { _ = self.runAppleScript("tell application \"Spotify\" to play") }
                else if self.isAppRunning("Music") { _ = self.runAppleScript("tell application \"Music\" to play") }
            default: break
            }
        }
    }

    func nextTrack() {
        if isSimulated { trackTitle = "Die For You"; trackArtist = "Joji"; trackDuration = 211; playerPosition = 0; return }
        let player = activePlayer
        let browser = isBrowserSource
        runTransport {
            switch player {
            case .spotify where self.isAppRunning("Spotify"): _ = self.runAppleScript("tell application \"Spotify\" to next track")
            case .appleMusic where self.isAppRunning("Music"): _ = self.runAppleScript("tell application \"Music\" to next track")
            case .system:
                if browser { self.runBrowserJS("var b=document.querySelector('.ytp-next-button');if(b)b.click();") }
                else { _ = self.mrSendCommand?(self.kMRNextTrack, nil) }
            default: break
            }
        }
    }

    func prevTrack() {
        if isSimulated { trackTitle = "Sanctuary"; trackArtist = "Joji"; trackDuration = 180; playerPosition = 0; return }
        let player = activePlayer
        let browser = isBrowserSource
        runTransport {
            switch player {
            case .spotify where self.isAppRunning("Spotify"): _ = self.runAppleScript("tell application \"Spotify\" to previous track")
            case .appleMusic where self.isAppRunning("Music"): _ = self.runAppleScript("tell application \"Music\" to previous track")
            case .system:
                if browser { self.runBrowserJS("var v=document.querySelector('video');if(v)v.currentTime=0;") }
                else { _ = self.mrSendCommand?(self.kMRPreviousTrack, nil) }
            default: break
            }
        }
    }

    func seek(to seconds: Double) {
        if isSimulated { playerPosition = seconds; return }
        playerPosition = seconds   // optimistic scrubber position
        let player = activePlayer
        let browser = isBrowserSource
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            switch player {
            case .spotify where self.isAppRunning("Spotify"): _ = self.runAppleScript("tell application \"Spotify\" to set player position to \(seconds)")
            case .appleMusic where self.isAppRunning("Music"): _ = self.runAppleScript("tell application \"Music\" to set player position to \(seconds)")
            case .system where browser: self.runBrowserJS("var v=document.querySelector('video');if(v)v.currentTime=\(Int(seconds));")
            default: break
            }
        }
    }

    /// Runs a transport command off the main thread (serialized with polling),
    /// then refreshes track state. Keeps the UI responsive on every button press.
    private func runTransport(_ work: @escaping () -> Void) {
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            work()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.updateTrackInfo() }
        }
    }

    // MARK: - AppleScript Queries

    private func querySpotify() -> String? {
        guard isAppRunning("Spotify") else { return nil }
        let script = """
        tell application "Spotify"
            try
                set pState to player state
                if pState is playing then
                    set tTitle to name of current track
                    set tArtist to artist of current track
                    set tPos to player position
                    set tDur to (duration of current track) / 1000
                    return "playing|" & tTitle & "|" & tArtist & "|" & tPos & "|" & tDur
                else if pState is paused then
                    set tTitle to name of current track
                    set tArtist to artist of current track
                    set tPos to player position
                    set tDur to (duration of current track) / 1000
                    return "paused|" & tTitle & "|" & tArtist & "|" & tPos & "|" & tDur
                else
                    return "stopped||||"
                end if
            on error errMsg
                return "stopped||||"
            end try
        end tell
        """
        return runAppleScript(script)
    }

    private func queryAppleMusic() -> String? {
        guard isAppRunning("Music") else { return nil }
        let script = """
        tell application "Music"
            try
                set pState to player state
                if pState is playing then
                    set tTitle to name of current track
                    set tArtist to artist of current track
                    set tPos to player position
                    set tDur to duration of current track
                    return "playing|" & tTitle & "|" & tArtist & "|" & tPos & "|" & tDur
                else if pState is paused then
                    set tTitle to name of current track
                    set tArtist to artist of current track
                    set tPos to player position
                    set tDur to duration of current track
                    return "paused|" & tTitle & "|" & tArtist & "|" & tPos & "|" & tDur
                else
                    return "stopped||||"
                end if
            on error errMsg
                return "stopped||||"
            end try
        end tell
        """
        return runAppleScript(script)
    }

    // MARK: - Shell Runner (uses osascript binary, bypasses TCC restrictions on the app binary)

    private func runAppleScript(_ source: String, timeout: TimeInterval = 2.0) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // silence errors from stdout

        do {
            try process.run()
        } catch {
            return nil
        }

        // Hard timeout: terminate a hung osascript so subprocess threads can't
        // accumulate over time (the cause of the app going sluggish/unusable).
        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()

        guard process.terminationStatus == 0 else { return nil }
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (output?.isEmpty ?? true) ? nil : output
    }
}
