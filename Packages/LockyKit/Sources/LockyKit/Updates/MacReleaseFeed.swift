import Foundation

/// A version of Locky for Mac, as the Sparkle feed of the site describes it.
public struct MacRelease: Identifiable, Sendable, Equatable {
    /// Version shown to the user, e.g. "1.0.2".
    public var version: String
    /// Build, the number Sparkle compares.
    public var build: Int
    public var date: Date?
    /// Release notes in Markdown (in French), `nil` when the version has none.
    public var notes: String?

    public var id: Int {
        build
    }

    public init(version: String, build: Int, date: Date?, notes: String?) {
        self.version = version
        self.build = build
        self.date = date
        self.notes = notes
    }

    /// The notes line by line, their title left out (the version stands for it), the dash of the
    /// items removed.
    public var noteLines: [String] {
        (notes ?? "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { line in
                guard line.hasPrefix("- ") || line.hasPrefix("* ") else { return line }
                return String(line.dropFirst(2))
            }
    }
}

/// The Sparkle feed of Locky for Mac (`SUFeedURL`): its versions, newest first, for the release
/// notes and to know whether the Mac is up to date.
public enum MacReleaseFeed {
    public static let url: URL = .init(string: "https://locky.lunabee.studio/mac/appcast.xml")!

    public static func fetch() async throws -> [MacRelease] {
        var request: URLRequest = .init(url: url)
        // A new version must show up at once.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response): (Data, URLResponse) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return parse(data)
    }

    public static func parse(_ data: Data) -> [MacRelease] {
        let reader: FeedReader = .init()
        let parser: XMLParser = .init(data: data)
        parser.delegate = reader
        parser.parse()
        return reader.releases.sorted { $0.build > $1.build }
    }
}

/// Reads the items of the RSS feed: title, date, Sparkle versions and description.
private final class FeedReader: NSObject, XMLParserDelegate {
    private(set) var releases: [MacRelease] = []
    private var item: [String: String]?
    private var text: String = ""

    private static let dateFormatter: DateFormatter = {
        let formatter: DateFormatter = .init()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        if elementName == "item" {
            item = [:]
        }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard item != nil else { return }
        if elementName == "item" {
            if let fields = item, let build = fields["sparkle:version"].flatMap({ Int($0) }) {
                releases.append(.init(
                    version: fields["sparkle:shortVersionString"] ?? fields["title"] ?? String(build),
                    build: build,
                    date: fields["pubDate"].flatMap(Self.dateFormatter.date(from:)),
                    notes: fields["description"]
                ))
            }
            item = nil
            return
        }
        item?[elementName] = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
