import Foundation
import IOBluetooth
import LockyKit

/// Classic Bluetooth around the Mac (IOBluetooth): an inquiry finds the devices that can be seen,
/// and the devices paired with the Mac tell whether they are connected.
///
/// An inquiry keeps the radio busy for its whole length: the sound of Bluetooth headphones may
/// stutter meanwhile.
@MainActor
final class ClassicBluetoothScanner: NSObject {
    private var inquiry: IOBluetoothDeviceInquiry?
    private var found: [String: ClassicBluetoothDevice] = [:]
    private var completion: CheckedContinuation<Void, Never>?

    /// Searches for about `seconds` (rounded to the units of Bluetooth, 1.28 s), then returns the
    /// devices found and the paired ones, those connected first.
    func scan(seconds: Double) async -> [ClassicBluetoothDevice] {
        found = [:]
        let inquiry: IOBluetoothDeviceInquiry = .init(delegate: self)
        inquiry.inquiryLength = UInt8(min(max(seconds / 1.28, 1), 48).rounded())
        // Asking every device its name would hold the radio much longer.
        inquiry.updateNewDeviceNames = false
        self.inquiry = inquiry
        if inquiry.start() == kIOReturnSuccess {
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    completion = continuation
                }
            } onCancel: {
                Task { @MainActor [weak self] in self?.finish() }
            }
        }
        self.inquiry = nil
        return devices()
    }

    private func finish() {
        inquiry?.stop()
        completion?.resume()
        completion = nil
    }

    private func devices() -> [ClassicBluetoothDevice] {
        var devices: [String: ClassicBluetoothDevice] = found
        for case let device as IOBluetoothDevice in IOBluetoothDevice.pairedDevices() ?? [] {
            let address: String = device.addressString ?? UUID().uuidString
            var entry: ClassicBluetoothDevice = devices[address] ?? Self.device(device)
            entry.isPaired = true
            entry.isConnected = device.isConnected()
            if entry.isConnected, let rssi = Self.rssi(device) {
                entry.rssi = rssi
            }
            devices[address] = entry
        }
        return devices.values.sorted {
            if $0.isConnected != $1.isConnected { return $0.isConnected }
            return ($0.rssi ?? -127) > ($1.rssi ?? -127)
        }
    }

    private func record(_ device: IOBluetoothDevice) {
        let entry: ClassicBluetoothDevice = Self.device(device)
        found[entry.id] = entry
    }

    private static func device(_ device: IOBluetoothDevice) -> ClassicBluetoothDevice {
        .init(
            id: device.addressString ?? UUID().uuidString,
            name: device.name.flatMap { $0.isEmpty ? nil : $0 },
            rssi: rssi(device),
            kind: .init(classOfDevice: device.classOfDevice),
            isPaired: device.isPaired(),
            isConnected: device.isConnected()
        )
    }

    /// The raw signal, `nil` when unknown (127).
    private static func rssi(_ device: IOBluetoothDevice) -> Int? {
        let rssi: Int = Int(device.rawRSSI())
        return rssi < 0 && rssi > -127 ? rssi : nil
    }
}

extension ClassicBluetoothScanner: IOBluetoothDeviceInquiryDelegate {
    nonisolated func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        nonisolated(unsafe) let device: IOBluetoothDevice? = device
        MainActor.assumeIsolated {
            guard let device else { return }
            record(device)
        }
    }

    nonisolated func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        MainActor.assumeIsolated { finish() }
    }
}
