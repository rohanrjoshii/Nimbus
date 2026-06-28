import AppKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func triggerTick() {
        // Trigger a gentle alignment-style haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
    
    func triggerClick() {
        // Trigger a standard click haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }

    func triggerExpand() {
        // Firmer feedback for morphing open/closed — feels like a physical detent
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
