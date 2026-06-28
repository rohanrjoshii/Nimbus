import AppKit
import SwiftUI

/// Menu-bar status item that opens the Nimbus Control Center popover —
/// the classy, minimalist GUI for sound, brightness, map, and quick toggles.
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?

    private override init() { super.init() }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Nimbus")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
        statusItem = item

        // .applicationDefined (NOT .transient): a transient popover in an accessory
        // app dismisses on the slightest focus change — including dragging the map
        // or sliders. We control closing ourselves (icon re-click or click-away).
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.appearance = NSAppearance(named: .vibrantDark)
        // Fixed size — NOT auto-sizing. Auto-sizing an NSPopover around SwiftUI
        // content (esp. an embedded MKMapView) throws an AppKit layout exception
        // and crashes the app. ControlCenterView is sized to match.
        popover.contentSize = NSSize(width: 286, height: 474)
        let hosting = NSHostingController(
            rootView: ControlCenterView()
                .environmentObject(AppState.shared)
                .environmentObject(MusicManager.shared)
        )
        popover.contentViewController = hosting
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            HapticManager.shared.triggerClick()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            // Close only when the user clicks OUTSIDE the popover (other apps / desktop).
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    func closePopover() {
        popover.performClose(nil)
        if let m = outsideClickMonitor {
            NSEvent.removeMonitor(m)
            outsideClickMonitor = nil
        }
    }
}
