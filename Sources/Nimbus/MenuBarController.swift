import AppKit
import SwiftUI

/// Menu-bar status item that opens the Nimbus Control Center — the classy,
/// minimalist GUI for sound, brightness, weather, and quick toggles.
///
/// Uses a borderless NSPanel (not NSPopover): NSPopover repeatedly threw an
/// AppKit layout exception around the SwiftUI content and crashed the app.
/// An NSPanel + NSHostingController is the same reliable pattern the Settings
/// window uses.
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var outsideClickMonitor: Any?

    private override init() { super.init() }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Nimbus")
            button.image?.isTemplate = true
            button.action = #selector(togglePanel)
            button.target = self
        }
        statusItem = item
    }

    private func makePanel() -> NSPanel {
        let size = NSSize(width: 286, height: 474)
        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.isMovable = false

        // Use NSHostingView as the panel's contentView (the same pattern the island
        // panel uses). NSHostingController + a manual layoutSubtreeIfNeeded() forces
        // SwiftUI layout — including its NSVisualEffectView — before the view is in a
        // window, which throws an AppKit layout exception and crashes.
        let hosting = NSHostingView(
            rootView: ControlCenterView()
                .environmentObject(AppState.shared)
                .environmentObject(MusicManager.shared)
        )
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 22
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        p.contentView = hosting
        return p
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true { closePanel(); return }
        let p = panel ?? makePanel()
        panel = p

        HapticManager.shared.triggerClick()
        position(p)
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)

        // Close when the user clicks anywhere outside the panel.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    /// Anchor the panel just below the menu-bar icon, clamped to the screen.
    private func position(_ p: NSPanel) {
        guard let button = statusItem?.button, let bw = button.window else { return }
        let anchor = bw.convertToScreen(button.convert(button.bounds, to: nil))
        let size = p.frame.size
        var x = anchor.midX - size.width / 2
        let y = anchor.minY - size.height - 6
        if let vis = (button.window?.screen ?? NSScreen.main)?.visibleFrame {
            x = min(max(x, vis.minX + 8), vis.maxX - size.width - 8)
        }
        p.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func closePanel() {
        panel?.orderOut(nil)
        if let m = outsideClickMonitor {
            NSEvent.removeMonitor(m)
            outsideClickMonitor = nil
        }
    }
}
