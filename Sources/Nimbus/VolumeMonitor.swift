import Foundation
import CoreAudio
import Combine

/// Shows a transient volume HUD in the island when the output volume or mute
/// changes (e.g. the volume keys). Note: macOS still shows its own overlay
/// unless the system OSD is disabled.
final class VolumeMonitor: ObservableObject {
    static let shared = VolumeMonitor()

    @Published var volume: Float = 0.5
    @Published var muted: Bool = false
    @Published var showHUD: Bool = false   // transient

    private var device: AudioDeviceID = 0
    private var primed = false
    private var dismissWork: DispatchWorkItem?

    private init() {}

    func start() {
        device = defaultOutput()
        volume = readVolume()
        muted = readMuted()
        attachListeners(to: device)

        // Re-attach when the default output device changes.
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main) { [weak self] _, _ in
            guard let self = self else { return }
            self.device = self.defaultOutput()
            self.attachListeners(to: self.device)
            self.refresh(pop: false)
        }
    }

    private func attachListeners(to dev: AudioDeviceID) {
        let targets: [(AudioObjectPropertySelector, UInt32)] = [
            (kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyElementMain),
            (kAudioDevicePropertyVolumeScalar, 1),
            (kAudioDevicePropertyMute, kAudioObjectPropertyElementMain),
        ]
        for (sel, el) in targets {
            var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeOutput, mElement: el)
            AudioObjectAddPropertyListenerBlock(dev, &addr, DispatchQueue.main) { [weak self] _, _ in
                self?.refresh(pop: true)
            }
        }
    }

    private func refresh(pop: Bool) {
        volume = readVolume()
        muted = readMuted()
        guard pop else { return }
        guard primed else { primed = true; return }   // don't pop on the very first event
        showHUD = true
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.showHUD = false }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }

    // MARK: - CoreAudio reads

    private func defaultOutput() -> AudioDeviceID {
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
        return dev
    }

    private func readVolume() -> Float {
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar,
                                              mScope: kAudioObjectPropertyScopeOutput,
                                              mElement: kAudioObjectPropertyElementMain)
        if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &v) == noErr { return v }
        addr.mElement = 1   // fall back to channel 1
        if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &v) == noErr { return v }
        return volume
    }

    private func readMuted() -> Bool {
        var m: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                              mScope: kAudioObjectPropertyScopeOutput,
                                              mElement: kAudioObjectPropertyElementMain)
        if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &m) == noErr { return m != 0 }
        return false
    }
}
