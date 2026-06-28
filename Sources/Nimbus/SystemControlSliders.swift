import SwiftUI
import AppKit

// MARK: – System Volume Slider
// Controls macOS output volume via osascript (no private API needed)

struct VolumeSlider: View {
    @State private var volume: Double = 0.5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 3)
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: max(0, min(geo.size.width * volume, geo.size.width)), height: 3)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        volume = max(0, min(Double(v.location.x / geo.size.width), 1))
                        setSystemVolume(volume)
                    }
            )
        }
        .frame(height: 3)
        .onAppear { volume = getSystemVolume() }
    }

    private func getSystemVolume() -> Double {
        let result = shell("osascript -e 'output volume of (get volume settings)'")
        return (Double(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 50) / 100.0
    }

    private func setSystemVolume(_ v: Double) {
        let pct = Int(v * 100)
        DispatchQueue.global(qos: .userInitiated).async {
            _ = shell("osascript -e 'set volume output volume \(pct)'")
        }
    }
}

// MARK: – System Brightness Slider
// Controls display brightness via screen brightness API

struct BrightnessSlider: View {
    @State private var brightness: Double = 0.5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 3)
                Capsule()
                    .fill(Color.yellow.opacity(0.85))
                    .frame(width: max(0, min(geo.size.width * brightness, geo.size.width)), height: 3)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        brightness = max(0.05, min(Double(v.location.x / geo.size.width), 1))
                        setSystemBrightness(brightness)
                    }
            )
        }
        .frame(height: 3)
        .onAppear { brightness = getSystemBrightness() }
    }

    private func getSystemBrightness() -> Double {
        // Use NSScreen brightness if available (works on built-in display)
        if let screen = NSScreen.main,
           let brightness = screen.value(forKey: "brightness") as? Double {
            return max(0.05, min(brightness, 1.0))
        }
        return 0.5
    }

    private func setSystemBrightness(_ value: Double) {
        // Use osascript to set brightness via CoreDisplay framework call
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
    // Timeout so a stuck osascript can't freeze the main thread during slider drags.
    let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    killer.cancel()
    return String(data: data, encoding: .utf8) ?? ""
}
