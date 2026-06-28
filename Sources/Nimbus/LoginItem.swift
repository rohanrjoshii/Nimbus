import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService` (macOS 13+) for the "Launch at Login" toggle.
/// Registers the running `.app` bundle as a login item — no helper target required.
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("Nimbus: LoginItem toggle failed — \(error.localizedDescription)")
            return false
        }
    }
}
