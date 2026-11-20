import AudioToolbox
import CoreAudio
import Foundation

/// Volume of the current output device of the Mac (CoreAudio).
enum SystemVolume {
    struct State {
        /// From 0 to 1; `nil` when the device has no software volume (HDMI, some interfaces).
        let volume: Double?
        let isMuted: Bool
    }

    static var state: State {
        guard let device = outputDevice else { return .init(volume: nil, isMuted: false) }
        var volumeAddress: AudioObjectPropertyAddress = Self.volumeAddress
        var volume: Float32 = 0
        var volumeSize: UInt32 = .init(MemoryLayout<Float32>.size)
        let hasVolume: Bool = AudioObjectHasProperty(device, &volumeAddress)
            && AudioObjectGetPropertyData(device, &volumeAddress, 0, nil, &volumeSize, &volume) == noErr
        var muteAddress: AudioObjectPropertyAddress = Self.muteAddress
        var muted: UInt32 = 0
        var muteSize: UInt32 = .init(MemoryLayout<UInt32>.size)
        let hasMute: Bool = AudioObjectHasProperty(device, &muteAddress)
            && AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &muteSize, &muted) == noErr
        return .init(volume: hasVolume ? Double(volume) : nil, isMuted: hasMute && muted != 0)
    }

    static func setVolume(_ value: Double) {
        guard let device = outputDevice else { return }
        var address: AudioObjectPropertyAddress = volumeAddress
        var volume: Float32 = .init(min(max(value, 0), 1))
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume)
        if value > 0, state.isMuted {
            setMuted(false)
        }
    }

    static func toggleMute() {
        setMuted(!state.isMuted)
    }

    private static func setMuted(_ muted: Bool) {
        guard let device = outputDevice else { return }
        var address: AudioObjectPropertyAddress = muteAddress
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private static var outputDevice: AudioObjectID? {
        var address: AudioObjectPropertyAddress = .init(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device: AudioObjectID = .init(kAudioObjectUnknown)
        var size: UInt32 = .init(MemoryLayout<AudioObjectID>.size)
        let status: OSStatus = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private static var volumeAddress: AudioObjectPropertyAddress {
        .init(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static var muteAddress: AudioObjectPropertyAddress {
        .init(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    }
}
