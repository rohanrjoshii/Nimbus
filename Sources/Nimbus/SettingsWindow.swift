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
        let contentRect = NSRect(x: 0, y: 0, width: 540, height: 380)
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
        
        // Frosted visual effect view
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.frame = contentRect
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        
        // Wrap our settings view
        let hosting = NSHostingView(rootView: SettingsView())
        hosting.frame = contentRect
        visualEffect.addSubview(hosting)
        
        self.contentView = visualEffect
        self.delegate = self
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
