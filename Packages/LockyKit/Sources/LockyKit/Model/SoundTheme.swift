import Foundation

/// Sound played on the iPhone when the Mac locks.
public enum SoundTheme: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case standard = "default"
    case yesMyLord = "yesmylord"
    case readyToServe = "readytoserve"
    case oss117Unfaithful = "ossalorsinfidele"
    case oss117Blanquette = "osslablanquette"
    case bike = "velo"
    case fx1
    case fx2
    case fx3
    case magic
    case laser = "lazer"
    case chewbacca = "chewbaka"

    public var id: String { rawValue }

    /// Name of the `.caf` resource (without extension) in the iPhone app bundle.
    public var fileName: String? {
        switch self {
        case .none: nil
        case .standard: "lock"
        case .yesMyLord: "yml"
        case .readyToServe: "rts"
        case .oss117Unfaithful: "oai"
        case .oss117Blanquette: "ocevb"
        case .bike: "velo"
        case .fx1: "borg"
        case .fx2: "comp"
        case .fx3: "fx"
        case .magic: "magic"
        case .laser: "lazer"
        case .chewbacca: "chwbk"
        }
    }

    /// Localized theme name.
    public var localizedName: String {
        switch self {
        case .none: String(localized: "None", bundle: .module)
        case .standard: String(localized: "Default sounds", bundle: .module)
        case .yesMyLord: "Yes my Lord"
        case .readyToServe: "Ready to serve my Lord"
        case .oss117Unfaithful: "OSS 117 - Alors infidèle"
        case .oss117Blanquette: "OSS 117 - Comment est votre blanquette ?"
        case .bike: String(localized: "Bike", bundle: .module)
        case .fx1: "FX 1"
        case .fx2: "FX 2"
        case .fx3: "FX 3"
        case .magic: String(localized: "Magic", bundle: .module)
        case .laser: String(localized: "Laser", bundle: .module)
        case .chewbacca: "Chewbacca"
        }
    }
}
