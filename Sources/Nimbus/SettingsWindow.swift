import AppKit
import SwiftUI

class SettingsWindow: NSWindow, NSWindowDelegate {
    private static var instance: SettingsWindow?
    
    static var shared: SettingsWindow {
        if let window = instance {
            return window
        }
        let window = SettingsWindow()
        instance = window
        return window
    }
    
    private init() {
        let contentRect = NSRect(x: 0, y: 0, width: 560, height: 400)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Nimbus Preferences"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isReleasedWhenClosed = false
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.delegate = self

        // Let SwiftUI manage its own layout via NSHostingController. Manually
        // placing an NSHostingView (fixed frame) inside an NSVisualEffectView made
        // AppKit's constraint layout throw an exception → crash on open. The frosted
        // background now lives inside SettingsView itself.
        self.contentViewController = NSHostingController(rootView: SettingsView())
        self.center()
    }
    
    func show() {
        // Become a regular app while Settings is open so the window gets proper key
        // focus and interactive controls (accessory apps can't reliably do this),
        // then revert to accessory on close.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.center()
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
