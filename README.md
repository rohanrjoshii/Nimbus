<div align="center">

# Nimbus

### A Dynamic Island for macOS — real-time music, system stats, and a lock screen companion, built entirely in Swift.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-black?style=flat-square&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-blue?style=flat-square)
![AppKit](https://img.shields.io/badge/AppKit-✓-blue?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

</div>

---

## What is Nimbus?

Nimbus is a floating HUD widget for macOS that brings the iPhone's **Dynamic Island** experience to your desktop. It lives at the top of your screen as a sleek, pill-shaped overlay — expanding on click to reveal a full music player, system performance stats, a focus timer, weather, and calendar — all inside a single glassmorphic card.

Inspired by apps like **Canopy** and Apple's own Dynamic Island, Nimbus is built from scratch using a **SwiftUI + AppKit hybrid** architecture, with zero third-party dependencies.

---

## Features

| Feature | Details |
|---|---|
| 🎵 **Real-time Music Sync** | Reads live track title, artist, artwork, position, and play/pause state from **Spotify** and **Apple Music** simultaneously via AppleScript subprocess polling |
| 🎨 **Live Album Art** | Fetches album artwork in real time through the iTunes Search API with an in-memory `NSImage` cache |
| 📊 **System Stats** | Live CPU usage, RAM pressure, battery level/charging state, disk usage, and network throughput |
| ⏱️ **Focus Timer** | Pomodoro-style countdown timer with pause/resume and visual pill state when active |
| 🌤️ **Live Weather** | Real current conditions, temperature, and a 6-hour forecast via the key-less **Open-Meteo API**, located through CoreLocation with an automatic IP-geolocation fallback |
| 📅 **Real Calendar** | Today's events pulled live from **EventKit** across every granted calendar, with "happening now" detection and graceful empty/no-access states |
| 🔒 **Lock Screen Companion** | Canopy-inspired mode with the full music player + **system brightness slider** + **system volume slider** |
| 🎛️ **Brightness & Volume** | Drag-to-control sliders for display brightness and audio output volume, without leaving the widget |
| 💎 **Glassmorphic Design** | `NSVisualEffectView` frosted-glass blur with a dark tinted overlay and a top-lit gradient inner border |
| 🏝️ **Dynamic Morphing** | The pill smoothly animates between 5 sizes (idle, music-playing, timer-active, expanded, lock-screen) using `NSAnimationContext` with a custom cubic Bézier easing |
| 🌊 **Waveform Visualizer** | Animated 3-bar equaliser in the collapsed pill, colour-coded green for Spotify, red for Apple Music |
| 🖱️ **Drag to Reposition** | Spring-back drag gesture; snaps to any screen position |
| 🖥️ **Multi-Monitor Aware** | Always positions relative to the screen containing the mouse cursor |
| 🎪 **Notch Integration** | Optionally snaps flush into the MacBook Pro notch when collapsed |

---

## Architecture

```
Nimbus
├── AppDelegate.swift          # NSPanel lifecycle, resize-on-demand (frame-diff guarded)
├── FloatingPanel.swift        # Borderless, always-on-top NSPanel at .screenSaver level
├── AppState.swift             # Central @Published state; drives all layout decisions
│
├── MusicManager.swift         # 1Hz AppleScript polling via osascript subprocess
│                              # Spotify + Apple Music auto-detection
│                              # Smooth local position advance when playing
│
├── ArtworkCache.swift         # iTunes Search API → NSImage in-memory cache
├── SystemStatsManager.swift   # CPU (host_processor_info), RAM (host_statistics64),
│                              # battery (IOKit), disk + real network throughput (getifaddrs)
├── WeatherManager.swift       # Open-Meteo + CoreLocation, IP-geolocation fallback
├── CalendarManager.swift      # EventKit today-events, live "happening now" detection
├── TimerManager.swift         # Pomodoro countdown with Combine publishers
├── LockScreenManager.swift    # DistributedNotificationCenter lock/unlock observer
├── LoginItem.swift            # SMAppService "Launch at Login" registration
│
├── DynamicIslandView.swift    # Root SwiftUI view; routes collapsed/expanded/lock layouts
├── MusicWidgetView.swift      # Expanded music player (art, scrubber, transport controls)
├── StatsWidgetView.swift      # CPU/RAM/battery gauges + storage + network
├── TimerWidgetView.swift      # Countdown display + start/pause/reset controls
├── WeatherWidgetView.swift    # Live conditions + 6-hour forecast row
├── CalendarWidgetView.swift   # Today's events list + empty/no-access states
├── SettingsView.swift         # Preferences UI (persisted via UserDefaults)
├── SystemControlSliders.swift # Brightness + volume sliders (osascript backend)
│
├── VisualEffectView.swift     # NSViewRepresentable wrapping NSVisualEffectView
├── ControlButtonStyle.swift   # Shared hover-scale + press-dim ButtonStyle
└── HapticManager.swift        # NSHapticFeedbackManager wrappers
```

### Key Design Decisions

**No polling-driven redraws.** `MusicManager` polls Spotify every second, but `AppDelegate` only re-animates the window frame when the computed `NSRect` has actually changed (>0.5pt delta). This prevents the 1Hz music tick from causing constant window re-animation.

**Three-layer corner radius.** SwiftUI's `.clipShape()` only clips the SwiftUI renderer. To get true rounded corners on a floating `NSPanel`, corner radius is applied at three independent levels: `NSVisualEffectView.layer`, `NSHostingView.layer`, and SwiftUI `.clipShape()` — all using `.continuous` corner curve.

**`osascript` subprocess over `NSAppleScript`.** `NSAppleScript` is subject to macOS TCC (Transparency, Consent & Control) per binary. Calling `/usr/bin/osascript` as a `Process` subprocess bypasses the binary-specific restriction while still respecting user-granted Automation permissions.

---

## Tech Stack

- **Language**: Swift 5.9
- **UI Framework**: SwiftUI + AppKit (hybrid — `NSViewRepresentable`, `NSHostingView`)
- **Concurrency**: Combine (`@Published`, `PassthroughSubject`), `DispatchQueue.global`
- **System Integration**: `osascript` (media + sliders), `IOKit` (battery), `host_processor_info` (CPU), `host_statistics64` (RAM), `getifaddrs` (network), `CoreLocation` + `EventKit` (weather/calendar), `SMAppService` (login item), `DistributedNotificationCenter` (lock screen)
- **Networking**: `URLSession` against the key-less **Open-Meteo** weather API and the iTunes Search API
- **Persistence**: `UserDefaults` for all user preferences
- **Windowing**: Borderless `NSPanel` at `NSWindow.Level.screenSaver`
- **Build**: `swiftc` direct compilation + custom `bundle.sh` packaging script
- **No third-party Swift package dependencies** (one private framework, MediaRemote, is loaded at runtime purely for richer artwork)

---

## Build & Run

### Requirements
- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)
- Spotify or Apple Music installed

### Quick Start

```bash
git clone https://github.com/rohanrjoshii/Nimbus.git
cd Nimbus
chmod +x bundle.sh
./bundle.sh
open Nimbus.app
```

> **First launch:** macOS will prompt for **Automation** (Spotify/Apple Music), **Location** (weather), and **Calendar** access. Grant them in **System Settings → Privacy & Security**. Each is optional — Nimbus degrades gracefully if any is denied (weather falls back to IP location; calendar shows a friendly access-needed state).

### Build Script

`bundle.sh` compiles all Swift sources with `-O` optimisation, creates a proper `.app` bundle with `Info.plist`, and copies the app icon `.icns`.

---

## Usage

| Action | Result |
|---|---|
| **Click** the pill | Expand to full widget |
| **Hover away** | Auto-collapse |
| **Drag** the pill | Reposition anywhere on screen |
| **Right-click** | Context menu (settings, pin, lock screen mode, quit) |
| **Lock Screen Mode** (right-click) | Shows full music player + brightness/volume sliders |

---

## Permissions Required

| Permission | Why |
|---|---|
| **Automation → Spotify** | Read current track, artist, position, player state |
| **Automation → Apple Music** | Same as above for Apple Music |
| **Location** | Resolve coordinates for local weather (falls back to IP geolocation if denied) |
| **Calendar** | Read today's events for the calendar widget (shows an access-needed state if denied) |

Not sandboxed. Every permission is optional and the app degrades gracefully when any is withheld.

---

## What I Learned / Built

- Building **AppKit + SwiftUI hybrid** macOS apps without Xcode's project system — using `swiftc` directly and a custom bundle script
- **Three-layer compositing** to achieve true rounded corners on borderless `NSPanel` windows (a common pitfall: SwiftUI `.clipShape()` alone doesn't clip the `NSVisualEffectView` blur layer)
- Implementing a **jank-free 1Hz data sync loop** for Spotify/Apple Music without causing 60fps UI redraws — by separating the data polling thread from the SwiftUI update cycle using `DispatchQueue.main.async` gates
- Understanding **macOS TCC (Transparency, Consent & Control)** and why `NSAppleScript` vs `osascript` behave differently for the same script
- Designing a **state machine** in `AppState` that drives 5 distinct window geometries through a single `currentSize: CGSize` computed property
- Using `NSAnimationContext` with a custom **cubic Bézier timing function** for fluid pill morphing that feels native
- Subscribing to **`DistributedNotificationCenter`** for system lock/unlock events to build a Canopy-style lock screen companion

---

## Roadmap

- [x] **Live weather** via Open-Meteo free API (no key required)
- [x] **Real calendar** via EventKit
- [x] **Real network throughput** via `getifaddrs` byte counters
- [x] **Persisted preferences** + **Launch at Login** (`SMAppService`)
- [ ] **Spotify Lyrics** via Musixmatch or Spotify internal WebSocket
- [ ] **ScreenSaver extension** for true lock-screen presence (requires `.saver` bundle target)
- [ ] **Menu bar icon** with quick settings popover
- [ ] **Keyboard shortcuts** to expand/collapse and switch tabs
- [ ] **iCloud sync** for timer presets and widget order preferences

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

Built with ❤️ by [Rohan Joshi](https://github.com/rohanrjoshii)

*Inspired by Apple's Dynamic Island and the Canopy macOS app*

</div>
