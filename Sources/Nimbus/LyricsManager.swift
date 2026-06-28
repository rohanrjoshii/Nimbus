import Foundation
import Combine

/// Time-synced (karaoke) lyrics via the free, key-less lrclib.net API.
/// Matches on (title, artist, duration); falls back to fuzzy search.
final class LyricsManager: ObservableObject {
    static let shared = LyricsManager()

    struct Line: Equatable { let time: Double; let text: String }

    @Published private(set) var lines: [Line] = []
    @Published private(set) var index: Int = -1     // current highlighted line
    @Published private(set) var available: Bool = false

    private var loadedKey = ""
    private var task: URLSessionDataTask?

    private init() {}

    /// Returns the line text at `i` (nil for out-of-range or instrumental gaps).
    func line(at i: Int) -> String? {
        guard i >= 0, i < lines.count else { return nil }
        let t = lines[i].text
        return t.isEmpty ? nil : t
    }

    /// Fetch lyrics for a track; no-ops if the song hasn't changed.
    func load(title: String, artist: String, duration: Double) {
        guard !title.isEmpty, title != "Not Playing" else { clear(); return }
        let key = "\(title)|\(artist)"
        guard key != loadedKey else { return }
        loadedKey = key
        task?.cancel()
        setLines([])

        let dur = Int(duration.rounded())
        guard let url = endpoint("get", [("track_name", title), ("artist_name", artist), ("duration", String(dur))]) else { return }
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            if let data = data, let obj = try? JSONDecoder().decode(LRCObject.self, from: data),
               let synced = obj.syncedLyrics, !synced.isEmpty {
                self.setLines(self.parse(synced))
            } else {
                self.searchFallback(title: title, artist: artist, dur: dur)
            }
        }
        task?.resume()
    }

    /// Advance the highlighted line to match playback position (call ~1/sec).
    func update(position: Double) {
        guard !lines.isEmpty else { return }
        var j = -1
        for (k, l) in lines.enumerated() {
            if l.time <= position + 0.2 { j = k } else { break }
        }
        if j != index { DispatchQueue.main.async { self.index = j } }
    }

    func clear() {
        loadedKey = ""
        task?.cancel()
        setLines([])
    }

    // MARK: - Internals

    private func searchFallback(title: String, artist: String, dur: Int) {
        guard let url = endpoint("search", [("track_name", title), ("artist_name", artist)]) else { return }
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data,
                  let arr = try? JSONDecoder().decode([LRCObject].self, from: data) else { return }
            let best = arr
                .filter { ($0.syncedLyrics?.isEmpty == false) }
                .min { abs(($0.duration ?? 0) - Double(dur)) < abs(($1.duration ?? 0) - Double(dur)) }
            if let synced = best?.syncedLyrics { self.setLines(self.parse(synced)) }
        }
        task?.resume()
    }

    private func endpoint(_ path: String, _ items: [(String, String)]) -> URL? {
        var c = URLComponents(string: "https://lrclib.net/api/\(path)")
        c?.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        return c?.url
    }

    private func setLines(_ l: [Line]) {
        DispatchQueue.main.async {
            self.lines = l
            self.index = -1
            self.available = !l.isEmpty
        }
    }

    /// Parse LRC text ("[mm:ss.xx] words") into time-sorted lines.
    private func parse(_ lrc: String) -> [Line] {
        var out: [Line] = []
        for raw in lrc.split(separator: "\n") {
            let s = String(raw)
            guard s.first == "[", let close = s.firstIndex(of: "]") else { continue }
            let stamp = s[s.index(after: s.startIndex)..<close]
            let parts = stamp.split(separator: ":")
            guard parts.count == 2, let m = Double(parts[0]), let sec = Double(parts[1]) else { continue }
            let text = String(s[s.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            out.append(Line(time: m * 60 + sec, text: text))
        }
        return out.sorted { $0.time < $1.time }
    }
}

private struct LRCObject: Decodable {
    let syncedLyrics: String?
    let duration: Double?
}
