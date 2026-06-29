import Foundation
import IOKit.ps
import Combine

/// Pops a transient "Charging" / "On Battery" live-activity when power is
/// connected or disconnected (iPhone-style), via instant IOKit notifications.
final class PowerManager: ObservableObject {
    static let shared = PowerManager()

    @Published var plugged: Bool = false      // power adapter connected (instant signal)
    @Published var isCharging: Bool = false    // battery actively charging
    @Published var level: Int = 100
    @Published var showEvent: Bool = false     // transient

    private var lastPlugged: Bool?
    private var runLoopSource: CFRunLoopSource?
    private var dismissWork: DispatchWorkItem?

    private init() {}

    func start() {
        let s = read()
        lastPlugged = s.plugged
        plugged = s.plugged
        isCharging = s.charging
        level = s.level

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        if let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            Unmanaged<PowerManager>.fromOpaque(ctx).takeUnretainedValue().powerChanged()
        }, ctx)?.takeRetainedValue() {
            runLoopSource = src
            // commonModes so it still fires during menu tracking / live resize.
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        }
    }

    private func powerChanged() {
        let s = read()
        level = s.level
        isCharging = s.charging
        // Pop on plug/unplug — the AC-state change is instant (unlike isCharging).
        if let last = lastPlugged, last != s.plugged {
            plugged = s.plugged
            flash()
        }
        lastPlugged = s.plugged
        plugged = s.plugged
    }

    private func flash() {
        showEvent = true
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.showEvent = false }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    private func read() -> (plugged: Bool, charging: Bool, level: Int) {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef] else {
            return (false, false, 100)
        }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(snap, ps)?.takeUnretainedValue() as? [String: Any] else { continue }
            if (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType {
                let plugged = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
                let charging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
                let level = (desc[kIOPSCurrentCapacityKey] as? Int) ?? 100
                return (plugged, charging, level)
            }
        }
        return (false, false, 100)
    }
}
