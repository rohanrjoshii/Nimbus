import SwiftUI
import AppKit

// MARK: – Thin fixed-width slider
// Avoids GeometryReader: a flexible GeometryReader-based track inside the menu-bar
// panel threw an AppKit layout exception and crashed the app. A fixed width is robust.

struct ThinSlider: View {
    let value: Double                 // 0...1
    let fill: Color
    var minValue: Double = 0.0
    let onScrub: (Double) -> Void

    private let width: CGFloat = 168
    private let track: CGFloat = 4

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.15)).frame(width: width, height: track)
            Capsule().fill(fill)
                .frame(width: max(0, min(width * CGFloat(value), width)), height: track)
        }
        .frame(width: width, height: 16)        // taller touch target; capsules centre vertically
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let pct = max(minValue, min(Double(v.location.x / width), 1))
                    onScrub(pct)
                }
        )
    }
}

// MARK: – System Volume

struct VolumeSlider: View {
    @State private var volume: Double = 0.5

    var body: some View {
        ThinSlider(value: volume, fill: Color.white.opacity(0.9)) { v in
            volume = v
            setSystemVolume(v)
        }
        .onAppear { volume = getSystemVolume() }
    }

    private func getSystemVolume() -> Double {
        let result = shell("osascript -e 'output volume of (get volume settings)'")
        let v = (Double(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 50) / 100.0
        return v.isFinite ? min(max(v, 0), 1) : 0.5
    }

    private func setSystemVolume(_ v: Double) {
        let pct = Int(v * 100)
        DispatchQueue.global(qos: .userInitiated).async {
            _ = shell("osascript -e 'set volume output volume \(pct)'")
        }
    }
}

// MARK: – System Brightness

struct BrightnessSlider: View {
    @State private var brightness: Double = 0.5

    var body: some View {
        ThinSlider(value: brightness, fill: Color.yellow.opacity(0.9), minValue: 0.05) { v in
            brightness = v
            setSystemBrightness(v)
        }
        .onAppear { brightness = getSystemBrightness() }
    }

    private func getSystemBrightness() -> Double {
        // NOTE: NSScreen.value(forKey: "brightness") is an undocumented KVC key that
        // throws NSUnknownKeyException on modern macOS — which AppKit turns into a
        // hard crash. There is no public API to read display brightness, so we start
        // at a neutral 50%; dragging still sets the real brightness via osascript.
        return 0.5
    }

    private func setSystemBrightness(_ value: Double) {
        let script = """
        tell application "System Events"
            try
                set brightness of screen 1 to \(Int(value * 100))
            end try
        end tell
        """
        let cmd = "osascript -e '\(script.replacingOccurrences(of: "'", with: "\\'"))'"
        DispatchQueue.global(qos: .userInitiated).async { _ = shell(cmd) }
    }
}

// MARK: – Shared shell helper

private func shell(_ cmd: String, timeout: TimeInterval = 1.5) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", cmd]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError  = Pipe()
    do { try process.run() } catch { return "" }
    let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    killer.cancel()
    return String(data: data, encoding: .utf8) ?? ""
}
