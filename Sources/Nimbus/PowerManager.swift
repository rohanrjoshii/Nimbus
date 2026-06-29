import Foundation
import IOKit.ps
import Combine

/// Pops a transient "Charging" / "On Battery" live-activity when power is
/// connected or disconnected (iPhone-style), via instant IOKit notifications.
final class PowerManager: ObservableObject {
    static let shared = PowerManager()

    @Published var isCharging: Bool = false
    @Published var level: Int = 100
    @Published var showEvent: Bool = false   // transient

    private var lastCharging: Bool?
    private var runLoopSource: CFRunLoopSource?
    private var dismissWork: DispatchWorkItem?

    private init() {}

    func start() {
        let (charging, lvl) = read()
        lastCharging = charging
        isCharging = charging
        level = lvl

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        if let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            Unmanaged<PowerManager>.fromOpaque(ctx).takeUnretainedValue().powerChanged()
        }, ctx)?.takeRetainedValue() {
            runLoopSource = src
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        }
    }

    private func powerChanged() {
        let (charging, lvl) = read()
        level = lvl
        if let last = lastCharging, last != charging {
            isCharging = charging
            flash()
        }
        lastCharging = charging
        isCharging = charging
    }

    private func flash() {
        showEvent = true
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.showEvent = false }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    private func read() -> (charging: Bool, level: Int) {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef] else {
            return (false, 100)
        }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(snap, ps)?.takeUnretainedValue() as? [String: Any] else { continue }
            if (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType {
                let charging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
                let level = (desc[kIOPSCurrentCapacityKey] as? Int) ?? 100
                return (charging, level)
            }
        }
        return (false, 100)
    }
}
