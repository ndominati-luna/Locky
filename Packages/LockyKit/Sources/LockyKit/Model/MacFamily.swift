import Foundation

/// Product family of a Mac, used when its exact device image is not available yet.
public enum MacFamily: String, Codable, Sendable, CaseIterable {
    case macBook
    case iMac
    case macMini
    case macStudio
    case macPro
    case unknown

    /// Infers the family from a marketing name ("MacBook Pro (14-inch, 2021)") or a model
    /// identifier ("MacBookPro18,4"). Recent identifiers ("Mac16,7") carry no family: the marketing
    /// name must be preferred.
    public init(productName: String) {
        let name: String = productName.lowercased().replacing(" ", with: "")
        if name.hasPrefix("macbook") {
            self = .macBook
        } else if name.hasPrefix("imac") {
            self = .iMac
        } else if name.hasPrefix("macmini") {
            self = .macMini
        } else if name.hasPrefix("macstudio") {
            self = .macStudio
        } else if name.hasPrefix("macpro") {
            self = .macPro
        } else {
            self = .unknown
        }
    }

    /// `true` for portable Macs.
    public var isLaptop: Bool {
        self == .macBook
    }

    /// SF Symbol representing the family.
    public var systemImage: String {
        switch self {
        case .macBook: "macbook"
        case .iMac: "desktopcomputer"
        case .macMini: "macmini"
        case .macStudio: "macstudio"
        case .macPro: "macpro.gen3"
        case .unknown: "laptopcomputer"
        }
    }
}
