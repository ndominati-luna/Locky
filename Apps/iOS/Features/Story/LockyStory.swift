import AVFoundation
import Foundation

/// The easter egg of the About screen: the video of the very first Locky, opened by tapping the
/// logo once per year since 2014.
///
/// The video is not in the app. It is streamed from a folder of the site that nothing links to
/// (HLS, five qualities from 270p to 1080p, so that it plays smoothly on any network), and every
/// segment is encrypted (AES-128): the playlists name the key `locky-story://key`, a scheme only
/// ``StoryKeyLoader`` answers, with the key kept in the app. The address and the key are masked,
/// so that they do not show up among the strings of the binary.
enum LockyStory {
    /// The year the first Locky came out.
    static let firstReleaseYear: Int = 2014

    /// Taps on the logo of About that open the video: the difference between this calendar year
    /// and the first one (12 in 2026).
    static var tapCount: Int {
        Calendar(identifier: .gregorian).component(.year, from: .now) - firstReleaseYear
    }

    /// The master playlist on the site.
    static var videoURL: URL? {
        URL(string: String(decoding: unmask(urlBytes, with: urlMask), as: UTF8.self))
    }

    /// The AES-128 key of the segments.
    static var key: Data {
        Data(unmask(keyBytes, with: keyMask))
    }

    private static func unmask(_ bytes: [UInt8], with mask: [UInt8]) -> [UInt8] {
        bytes.enumerated().map { $0.element ^ mask[$0.offset % mask.count] }
    }

    private static let keyMask: [UInt8] = [
        0xB1, 0x78, 0x68, 0x33, 0x95, 0x8B, 0x89, 0x84, 0xBC, 0xA9, 0x64, 0x4F, 0xF7, 0x67, 0x53,
        0x02
    ]
    private static let keyBytes: [UInt8] = [
        0x65, 0x1C, 0x8D, 0xCC, 0x17, 0xE9, 0xC7, 0xF2, 0x19, 0xDC, 0xA8, 0x87, 0xAC, 0xDC, 0xC1,
        0xEF
    ]
    private static let urlMask: [UInt8] = [
        0x77, 0x3B, 0xAD, 0x76, 0xD2, 0xC3, 0xC3, 0x32, 0xDD, 0x76, 0x7F, 0x09, 0x4F, 0xB4, 0xF6,
        0x4A
    ]
    private static let urlBytes: [UInt8] = [
        0x1F, 0x4F, 0xD9, 0x06, 0xA1, 0xF9, 0xEC, 0x1D, 0xB1, 0x19, 0x1C, 0x62, 0x36, 0x9A, 0x9A,
        0x3F, 0x19, 0x5A, 0xCF, 0x13, 0xB7, 0xED, 0xB0, 0x46, 0xA8, 0x12, 0x16, 0x66, 0x60, 0x83,
        0xC5, 0x7D, 0x44, 0x03, 0xCC, 0x42, 0xEA, 0xF5, 0xA2, 0x0B, 0xEB, 0x44, 0x1C, 0x39, 0x7D,
        0xD7, 0xCE, 0x2C, 0x13, 0x5D, 0x98, 0x4F, 0xE6, 0xF5, 0xF0, 0x03, 0xB9, 0x43, 0x1B, 0x6C,
        0x2A, 0x9B, 0x9B, 0x2B, 0x04, 0x4F, 0xC8, 0x04, 0xFC, 0xAE, 0xF0, 0x47, 0xE5
    ]
}

/// Hands the key of ``LockyStory`` to AVFoundation, which asks for `locky-story://key` while it
/// reads the playlists. Anything else is left to AVFoundation.
final class StoryKeyLoader: NSObject, AVAssetResourceLoaderDelegate, Sendable {
    static let scheme: String = "locky-story"
    /// AVFoundation calls the delegate on a queue of its choosing.
    let queue: DispatchQueue = .init(label: "studio.lunabee.locky.story-key")
    private let key: Data

    init(key: Data) {
        self.key = key
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard loadingRequest.request.url?.scheme == Self.scheme else { return false }
        loadingRequest.dataRequest?.respond(with: key)
        loadingRequest.finishLoading()
        return true
    }
}

/// The player of the video, with the delegate that gives it the key (an asset only holds its
/// delegate weakly).
@MainActor
final class StoryPlayback {
    let player: AVPlayer
    private let keyLoader: StoryKeyLoader = .init(key: LockyStory.key)

    init() {
        guard let url = LockyStory.videoURL else {
            player = .init()
            return
        }
        let asset: AVURLAsset = .init(url: url)
        asset.resourceLoader.setDelegate(keyLoader, queue: keyLoader.queue)
        player = .init(playerItem: .init(asset: asset))
    }
}
