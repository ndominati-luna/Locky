import Foundation

/// The artwork of a track of the Apple Music catalog, from the public iTunes Search API (no account,
/// no permission). Music gives AppleScript no artwork for a streamed track that is not in the
/// library: only its title, artist and album, sent to Apple to find it.
enum CatalogArtwork {
    private struct Response: Decodable {
        struct Song: Decodable {
            let trackName: String?
            let artistName: String?
            let collectionName: String?
            let artworkUrl100: URL?
        }

        let results: [Song]
    }

    /// The artwork, `pixelSize` pixels wide, of the catalog track with this title or from this album;
    /// `nil` when the catalog has neither.
    static func fetch(title: String, artist: String?, album: String?, pixelSize: Int) async -> Data? {
        // The artist first; several artists ("A, B & C") may hide the track, the album then finds it.
        // The search finds nothing with the " - Single" or " - EP" of the album names.
        let albumWords: String? = album?.replacing(#/ - (Single|EP)$/#, with: "")
        let terms: [String] = [artist, albumWords].compactMap { $0 }.map { "\(title) \($0)" } + [title]
        for term in terms {
            guard let songs = await search(term) else { return nil }
            let matching: Response.Song? = songs.first { same($0.trackName, title) && same($0.collectionName, album) }
                ?? songs.first { same($0.collectionName, album) }
                ?? songs.first { same($0.trackName, title) && same($0.artistName, artist) }
            guard let artworkURL = matching?.artworkUrl100 else { continue }
            // ".../100x100bb.jpg": the server scales the artwork to the size in the name.
            let sized: URL = artworkURL.deletingLastPathComponent().appending(path: "\(pixelSize)x\(pixelSize)bb.jpg")
            return try? await URLSession.shared.data(from: sized).0
        }
        return nil
    }

    /// Songs of the store of the Mac's region; `nil` when the search failed.
    private static func search(_ term: String) async -> [Response.Song]? {
        guard var components = URLComponents(string: "https://itunes.apple.com/search") else { return nil }
        components.queryItems = [
            .init(name: "term", value: term),
            .init(name: "media", value: "music"),
            .init(name: "entity", value: "song"),
            .init(name: "limit", value: "10"),
            .init(name: "country", value: Locale.current.region?.identifier ?? "US")
        ]
        guard
            let url = components.url,
            let (data, response) = try? await URLSession.shared.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let decoded = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }
        return decoded.results.filter { $0.artworkUrl100 != nil }
    }

    private static func same(_ name: String?, _ expected: String?) -> Bool {
        guard let name, let expected else { return false }
        return name.compare(expected, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}
