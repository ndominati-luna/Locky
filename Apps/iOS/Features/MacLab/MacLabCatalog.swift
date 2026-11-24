import LockyKit
import SwiftUI

/// A Mac of the lab: one picture of the catalog, with the types of Mac it stands for (several
/// years of a model often share it). Its name is read from those types, as macOS names them only
/// by family.
struct MacLabModel: Identifiable, Hashable {
    /// The picture in the catalog of the app.
    let id: String
    /// One of the types it stands for, to find it in the catalog.
    let deviceType: String
    let family: MacFamily
    /// "MacBook Pro 14-inch", localized.
    let name: String
    /// "Space Black", localized; `nil` for the Macs that come in one colour.
    let colour: String?
    /// "2023 – 2026", or "Since 2024".
    let years: String

    /// The colour and the years, under its name.
    var detail: String {
        [colour, years].compactMap(\.self).joined(separator: " · ")
    }

    var frame: MacFrame? {
        MacFrame.catalog(deviceType: deviceType, model: nil)
    }
}

/// The Macs of the lab, by family, in the order of the Apple Store.
enum MacLabCatalog {
    struct Section: Identifiable {
        let family: MacFamily
        let title: String
        let models: [MacLabModel]

        var id: String {
            title
        }
    }

    /// Read once from the catalog.
    @MainActor static let sections: [Section] = makeSections()

    @MainActor static var models: [MacLabModel] {
        sections.flatMap(\.models)
    }

    @MainActor
    static func model(id: String?) -> MacLabModel? {
        models.first { $0.id == id }
    }

    private static func makeSections() -> [Section] {
        // The types of each picture.
        var typesByAsset: [String: [String]] = [:]
        for type in MacCatalog.typeIdentifiers {
            guard let asset = MacCatalog.entry(deviceType: type, model: nil)?.asset else { continue }
            typesByAsset[asset, default: []].append(type)
        }
        let models: [MacLabModel] = typesByAsset.compactMap { asset, types in
            makeModel(asset: asset, types: types.sorted())
        }
        let order: [(MacFamily, String, [String])] = [
            (.macBook, String(localized: "MacBook"), ["macbookneo", "macbookair", "macbookpro"]),
            (.iMac, "iMac", ["imac"]),
            (.macMini, "Mac mini", ["macmini"]),
            (.macStudio, "Mac Studio", ["macstudio"]),
            (.macPro, "Mac Pro", ["macpro"])
        ]
        return order.compactMap { family, title, prefixes in
            let inFamily: [MacLabModel] = models
                .filter { model in prefixes.contains { model.id.hasPrefix("Mac-\($0)") } }
                .sorted { first, second in
                    let firstPrefix: Int = prefixes.firstIndex { first.id.hasPrefix("Mac-\($0)") } ?? 0
                    let secondPrefix: Int = prefixes.firstIndex { second.id.hasPrefix("Mac-\($0)") } ?? 0
                    if firstPrefix != secondPrefix {
                        return firstPrefix < secondPrefix
                    }
                    if first.name != second.name {
                        return first.name.localizedStandardCompare(second.name) == .orderedAscending
                    }
                    if first.years != second.years {
                        return first.years < second.years
                    }
                    return (first.colour ?? "").localizedStandardCompare(second.colour ?? "") == .orderedAscending
                }
            guard !inFamily.isEmpty else { return nil }
            return Section(family: family, title: title, models: inFamily)
        }
    }

    private static func makeModel(asset: String, types: [String]) -> MacLabModel? {
        guard let type = types.first else { return nil }
        let id: String = asset.replacing("Mac-", with: "")
        let size: String? = ["13", "14", "15", "16"].first { id.contains("-\($0)-") || id.hasSuffix("-\($0)") }
        let name: String
        let family: MacFamily
        if id.hasPrefix("imac") {
            family = .iMac
            name = String(localized: "iMac 24-inch")
        } else if id.hasPrefix("macbookair") {
            family = .macBook
            name = size == "15" ? String(localized: "MacBook Air 15-inch") : String(localized: "MacBook Air 13-inch")
        } else if id.hasPrefix("macbookneo") {
            family = .macBook
            name = "MacBook Neo"
        } else if id.hasPrefix("macbookpro") {
            family = .macBook
            switch size {
            case "13": name = String(localized: "MacBook Pro 13-inch")
            case "16": name = String(localized: "MacBook Pro 16-inch")
            default: name = String(localized: "MacBook Pro 14-inch")
            }
        } else if id.hasPrefix("macmini") {
            family = .macMini
            name = "Mac mini"
        } else if id.hasPrefix("macstudio") {
            family = .macStudio
            name = "Mac Studio"
        } else if id.hasPrefix("macpro") {
            family = .macPro
            name = id.contains("rackmount") ? String(localized: "Mac Pro, rack") : "Mac Pro"
        } else {
            return nil
        }
        return .init(
            id: asset,
            deviceType: type,
            family: family,
            name: name,
            colour: colour(of: id, family: family),
            years: years(of: types)
        )
    }

    /// The colour of a picture, from its name; the Macs without a colour in their name are silver,
    /// those that come in one colour have none.
    private static func colour(of id: String, family: MacFamily) -> String? {
        let colours: [(String, String)] = [
            ("space-black", String(localized: "Space Black")),
            ("space-gray", String(localized: "Space Gray")),
            ("sky-blue", String(localized: "Sky Blue")),
            ("midnight", String(localized: "Midnight")),
            ("starlight", String(localized: "Starlight")),
            ("gold", String(localized: "Gold")),
            ("blush", String(localized: "Blush")),
            ("citrus", String(localized: "Citrus")),
            ("indigo", String(localized: "Indigo")),
            ("blue", String(localized: "Blue")),
            ("green", String(localized: "Green")),
            ("orange", String(localized: "Orange")),
            ("pink", String(localized: "Pink")),
            ("purple", String(localized: "Purple")),
            ("yellow", String(localized: "Yellow"))
        ]
        if let colour = colours.first(where: { id.contains($0.0) }) {
            return colour.1
        }
        switch family {
        case .macBook, .iMac: return String(localized: "Silver")
        default: return nil
        }
    }

    /// The years of the types a picture stands for: "2021 – 2023", "2024", or "Since 2022" when
    /// some are named after their chip only (the latest ones).
    private static func years(of types: [String]) -> String {
        var years: [Int] = []
        var hasLater: Bool = false
        for type in types {
            let words: [Substring] = type.replacing("com.apple.", with: "").split(separator: "-")
            let found: [Int] = words.compactMap { Int($0) }.filter { $0 >= 2000 }
            if let year = found.first {
                years.append(year)
            } else if type == "com.apple.macstudio" {
                // The first Mac Studio, of 2022.
                years.append(2022)
            } else {
                hasLater = true
            }
        }
        guard let first = years.min(), let last = years.max() else { return "" }
        if hasLater {
            return String(localized: "Since \(String(first))")
        }
        return first == last ? String(first) : "\(first) – \(last)"
    }
}
