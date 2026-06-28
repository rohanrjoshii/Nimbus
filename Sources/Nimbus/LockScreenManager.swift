import Foundation
import AppKit

class LockScreenManager {
    static let shared = LockScreenManager()
    
    private init() {}
    
    func startObserving() {
        let dnc = DistributedNotificationCenter.default()
        
        // Distributed notifications for lock/unlock
        dnc.addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        dnc.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        // Workspace notifications for screen sleep state
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(
            self,
            selector: #selector(screenSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        ws.addObserver(
            self,
            selector: #selector(screenWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }
    
    @objc private func screenLocked() {
        playSound(named: "lock", fallback: "Tink")
        DispatchQueue.main.async {
            AppState.shared.isScreenLocked = true
            AppState.shared.isExpanded = false
        }
    }

    @objc private func screenUnlocked() {
        playSound(named: "unlock", fallback: "Bottle")
        DispatchQueue.main.async {
            AppState.shared.isScreenLocked = false
        }
    }

    /// Plays a custom bundled sound (e.g. Resources/lock.aiff) if present —
    /// drop in your own iPhone-style files — otherwise a macOS system sound.
    private func playSound(named base: String, fallback: String) {
        guard AppState.shared.lockSoundEnabled else { return }
        for ext in ["aiff", "wav", "m4a", "mp3", "caf"] {
            if let url = Bundle.main.url(forResource: base, withExtension: ext),
               let sound = NSSound(contentsOf: url, byReference: true) {
                sound.play()
                return
            }
        }
        NSSound(named: fallback)?.play()
    }
    
    @objc private func screenSleep() {
        // Triggered when display goes to sleep
    }
    
    @objc private func screenWake() {
        // Triggered when display wakes up
    }
}
