import Foundation
import CoreAudio
import Combine

/// Watches the system audio output device and pops a transient "Connected"
/// live-activity in the island when headphones / AirPods / a Bluetooth or USB
/// device becomes the output — iPhone-style.
final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()

    @Published var deviceName: String = ""
    @Published var deviceIcon: String = "headphones"
    @Published var showConnected: Bool = false   // transient — true for a few seconds on connect

    private var lastDeviceID: AudioDeviceID = 0
    private var dismissWork: DispatchWorkItem?

    private init() {}

    func start() {
        lastDeviceID = currentOutputDevice()
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main
        ) { [weak self] _, _ in
            self?.outputChanged()
        }
    }

    // MARK: - Change handling

    private func outputChanged() {
        let dev = currentOutputDevice()
        guard dev != 0, dev != lastDeviceID else { return }
        lastDeviceID = dev

        let transport = transportType(dev)
        // Only announce real "you plugged in headphones" devices — skip built-in speakers.
        guard transport != kAudioDeviceTransportTypeBuiltIn,
              transport != kAudioDeviceTransportTypeVirtual,
              transport != kAudioDeviceTransportTypeAggregate else { return }

        let name = deviceName(dev)
        deviceName = name
        deviceIcon = icon(for: transport, name: name)

        showConnected = true
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.showConnected = false }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: work)
    }

    // MARK: - CoreAudio reads

    private func currentOutputDevice() -> AudioDeviceID {
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
        return dev
    }

    private func deviceName(_ dev: AudioDeviceID) -> String {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, $0)
        }
        return status == noErr ? (name as String) : "Audio Device"
    }

    private func transportType(_ dev: AudioDeviceID) -> UInt32 {
        var t: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &t)
        return t
    }

    private func icon(for transport: UInt32, name: String) -> String {
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpods.max" }
        if n.contains("airpods pro") { return "airpods.pro" }
        if n.contains("airpods")     { return "airpods" }
        if n.contains("beats")       { return "beats.headphones" }
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "headphones"
        case kAudioDeviceTransportTypeUSB:        return "headphones"
        case kAudioDeviceTransportTypeAirPlay:    return "airplayaudio"
        case kAudioDeviceTransportTypeHDMI,
             kAudioDeviceTransportTypeDisplayPort: return "tv.inset.filled"
        default:                                   return "hifispeaker.fill"
        }
    }
}
