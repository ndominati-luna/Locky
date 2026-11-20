import Foundation

/// Information the iPhone sends to the Mac once the secure session is established.
public struct DeviceStatus: Codable, Sendable, Equatable {
    public var name: String
    /// Marketing model, e.g. "iPhone".
    public var model: String
    /// Hardware identifier, e.g. "iPhone18,1", used by the Mac to draw the exact device.
    public var modelIdentifier: String
    public var systemVersion: String
    public var appVersion: String
    /// Battery level in percent, `nil` when unknown.
    public var batteryLevel: Int?
    public var preferences: PhonePreferences
    /// ``MacImages/version`` the iPhone already has, so the Mac only announces new images.
    public var macImagesVersion: String?

    public init(
        name: String,
        model: String,
        modelIdentifier: String,
        systemVersion: String,
        appVersion: String,
        batteryLevel: Int?,
        preferences: PhonePreferences,
        macImagesVersion: String?
    ) {
        self.name = name
        self.model = model
        self.modelIdentifier = modelIdentifier
        self.systemVersion = systemVersion
        self.appVersion = appVersion
        self.batteryLevel = batteryLevel
        self.preferences = preferences
        self.macImagesVersion = macImagesVersion
    }
}
