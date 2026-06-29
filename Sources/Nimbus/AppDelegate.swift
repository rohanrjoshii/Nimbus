import AppKit
import SwiftUI
import Combine

/// Hosting view that drives hover + click reliably on a borderless,
/// non-activating overlay panel — where SwiftUI's own `.onHover`/taps are flaky.
/// Installs its own always-active tracking area (tagged via userInfo so it
/// doesn't react to SwiftUI's internal areas) and makes the window key on
/// click so inner buttons/sliders receive events.
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    private var islandTracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = islandTracking { removeTrackingArea(t) }
        let t = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: ["nimbusIsland": true]
        )
        addTrackingArea(t)
        islandTracking = t
    }

    private func isIslandArea(_ event: NSEvent) -> Bool {
        event.trackingArea?.userInfo?["nimbusIsland"] != nil
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if isIslandArea(event) { AppState.shared.setHover(true) }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if isIslandArea(event) { AppState.shared.setHover(false) }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)   // ensure inner controls get the click
        super.mouseDown(with: event)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: FloatingPanel!
    private var hostingView: NSHostingView<AnyView>!
    private var cancellables = Set<AnyCancellable>()

    // Debounce: only resize when the TARGET FRAME actually changes
    private var lastTargetFrame: NSRect = .zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        let music = MusicManager.shared
        let timer = TimerManager.shared
        let stats = SystemStatsManager.shared
        AppState.shared.setupSubscriptions(music: music, timer: timer)
        LockScreenManager.shared.startObserving()
        WeatherManager.shared.start()
        CalendarManager.shared.start()
        AudioDeviceManager.shared.start()
        MenuBarController.shared.setup()
        HotKeyManager.shared.onTrigger = {
            AppState.shared.islandHidden.toggle()
            HapticManager.shared.triggerExpand()
        }
        HotKeyManager.shared.register()

        let initialSize = AppState.shared.currentSize
        let rect = getCenteredTopRect(for: initialSize)
        lastTargetFrame = rect

        window = FloatingPanel(contentRect: rect)

        let contentView = AnyView(
            DynamicIslandView()
                .environmentObject(AppState.shared)
                .environmentObject(music)
                .environmentObject(timer)
                .environmentObject(stats)
        )

        hostingView = IslandHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor  = NSColor.clear.cgColor
        hostingView.layer?.masksToBounds    = true
        hostingView.layer?.cornerCurve      = .continuous
        applyCornerRadius()

        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        // React to AppState changes — but only resize when the computed frame changes
        AppState.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.updateWindowLevel()
                    self?.updateVisibility()
                    self?.resizeIfNeeded()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.lastTargetFrame = .zero // force recalc on screen change
                    self?.resizeIfNeeded()
                }
            }
            .store(in: &cancellables)

        // Re-assert the overlay after display sleep / wake so it stays on top and
        // interactive (a high-level panel can get stranded after the screen sleeps).
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            ws.publisher(for: name)
                .sink { [weak self] _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.reassertWindow() }
                }
                .store(in: &cancellables)
        }
    }

    /// Bring the overlay back to a known-good state (front, correct level, repositioned).
    private func reassertWindow() {
        guard let window = window, !AppState.shared.islandHidden else { return }
        lastTargetFrame = .zero
        updateWindowLevel()
        window.orderFrontRegardless()
        resizeIfNeeded()
    }

    // MARK: – Corner radius

    private var currentCornerRadius: CGFloat {
        (AppState.shared.isExpanded || AppState.shared.isScreenLocked) ? 32 : 18
    }

    private func applyCornerRadius() {
        let r = currentCornerRadius
        hostingView?.layer?.cornerRadius = r
    }

    // MARK: – Window level

    private func updateVisibility() {
        guard let window = window else { return }
        if AppState.shared.islandHidden {
            if window.isVisible { window.orderOut(nil) }
        } else {
            if !window.isVisible { window.orderFront(nil) }
        }
    }

    private func updateWindowLevel() {
        guard let window = window else { return }
        window.sharingType = AppState.shared.hideFromCapture ? .none : .readOnly
        window.level = AppState.shared.isScreenLocked
            ? NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
            : .screenSaver
    }

    // MARK: – Resize (only when frame actually changes)

    private func resizeIfNeeded() {
        guard let window = window else { return }

        let targetSize = AppState.shared.currentSize
        let targetRect = getCenteredTopRect(for: targetSize)

        // ── KEY FIX: skip if frame hasn't meaningfully changed ──────────────
        let dx = abs(targetRect.minX   - lastTargetFrame.minX)
        let dy = abs(targetRect.minY   - lastTargetFrame.minY)
        let dw = abs(targetRect.width  - lastTargetFrame.width)
        let dh = abs(targetRect.height - lastTargetFrame.height)
        guard dx > 0.5 || dy > 0.5 || dw > 0.5 || dh > 0.5 else { return }

        lastTargetFrame = targetRect

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.40
            // Smooth, slightly-eased morph that matches the SwiftUI content spring.
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.30, 0.92, 0.26, 1.0)
            ctx.allowsImplicitAnimation = true
            window.animator().setFrame(targetRect, display: true)
        }, completionHandler: { [weak self] in
            self?.applyCornerRadius()
            window.invalidateShadow()
        })
    }

    // MARK: – Frame calculation

    private func getCenteredTopRect(for size: CGSize) -> NSRect {
        let screens = NSScreen.screens
        let mouse   = NSEvent.mouseLocation
        let screen  = screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
                      ?? NSScreen.main ?? screens[0]
        let sf = screen.frame

        let x = sf.minX + (sf.width - size.width) / 2

        if AppState.shared.isScreenLocked {
            // Bottom-centre, above Dock
            let y = sf.minY + 80
            return NSRect(x: x, y: y, width: size.width, height: size.height)
        }

        var yOffset: CGFloat = AppState.shared.topOffset
        if #available(macOS 12.0, *) {
            let inset = screen.safeAreaInsets.top
            if inset > 0 {
                yOffset = (AppState.shared.useNotchIntegration && !AppState.shared.isExpanded)
                    ? 0 : inset + 6
            } else {
                if AppState.shared.isExpanded { yOffset = 10 }
            }
        }

        let y = sf.maxY - size.height - yOffset
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    func openSettingsWindow() {
        DispatchQueue.main.async { SettingsWindow.shared.show() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        TimerManager.shared.reset()
    }
}
