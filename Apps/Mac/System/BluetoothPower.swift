import Foundation

/// Turns Bluetooth on from the menu bar (private IOBluetooth function, as the former app did).
@MainActor
enum BluetoothPower {
    private typealias GetFunction = @convention(c) () -> Int32
    private typealias SetFunction = @convention(c) (Int32) -> Void

    private static let getPower: GetFunction? = PrivateSymbols.load(
        "IOBluetoothPreferenceGetControllerPowerState",
        from: PrivateSymbols.ioBluetoothFramework,
        as: GetFunction.self
    )
    private static let setPower: SetFunction? = PrivateSymbols.load(
        "IOBluetoothPreferenceSetControllerPowerState",
        from: PrivateSymbols.ioBluetoothFramework,
        as: SetFunction.self
    )

    static var canToggle: Bool {
        setPower != nil
    }

    static var isOn: Bool {
        (getPower?() ?? 0) != 0
    }

    static func turnOn() {
        setPower?(1)
    }
}
