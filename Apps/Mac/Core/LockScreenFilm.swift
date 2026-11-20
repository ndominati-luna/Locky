#if DEBUG
import AppKit
import AVFoundation
import CoreVideo
import ImageIO
import OSLog
import ScreenCaptureKit

/// Films the main display for the lock screen demo (`-LockyDemoRecordLockScreen YES`), frame by
/// frame: macOS stops every screen recording (`screencapture -v`, ScreenCaptureKit streams) as soon
/// as the session locks, but still takes screenshots of the lock screen. About 13 frames per second
/// with ScreenCaptureKit, `screencapture` (about 5) when it fails. Each frame keeps the time it was
/// taken, so the animations play at their real speed. The film ends 3 seconds after the unlock,
/// lands in the Movies folder and is shown in the Finder.
@MainActor
final class LockScreenFilm {
    static let maximumDuration: TimeInterval = 120
    /// Half the width of the 5120 pt display: sharp enough, and fast to capture.
    private static let width: Int = 2_560

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "LockScreenFilm")
    private var task: Task<Void, Never>?
    private var unlockDate: Date?

    func start() {
        task = Task { await film() }
    }

    /// The desktop is back: the film ends 3 seconds later.
    func markUnlocked() {
        unlockDate = unlockDate ?? .now
    }

    private func film() async {
        let displayID: CGDirectDisplayID = CGMainDisplayID()
        let bounds: CGRect = CGDisplayBounds(displayID)
        // Even dimensions: H.264 encodes 4:2:0, by pairs of pixels.
        let height: CGFloat = (CGFloat(Self.width) * bounds.height / bounds.width / 2).rounded() * 2
        let size: CGSize = .init(width: CGFloat(Self.width), height: height)
        let url: URL = Self.movieURL()
        let writer: FilmWriter
        do {
            writer = try FilmWriter(url: url, size: size)
        } catch {
            logger.error("Film writer failed: \(error.localizedDescription)")
            return
        }
        var screenshots: ScreenshotSource? = await ScreenshotSource(displayID: displayID, size: size)
        let start: Date = .now
        var frames: (screenCaptureKit: Int, command: Int, missed: Int) = (0, 0, 0)
        logger.info("Filming the main display frame by frame")
        while !Task.isCancelled, Date.now.timeIntervalSince(start) < Self.maximumDuration {
            if let unlockDate, Date.now.timeIntervalSince(unlockDate) > 3 { break }
            let time: TimeInterval = Date.now.timeIntervalSince(start)
            if let image = await screenshots?.capture() {
                frames.screenCaptureKit += 1
                await writer.append(image, at: time)
            } else if let image = await Self.captureWithCommand(displayID: displayID, width: Self.width) {
                frames.command += 1
                await writer.append(image, at: time)
                // ScreenCaptureKit may work again (new display configuration): try it once in a while.
                if frames.command.isMultiple(of: 20) {
                    screenshots = await ScreenshotSource(displayID: displayID, size: size)
                }
            } else {
                frames.missed += 1
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        await writer.finish()
        let duration: TimeInterval = Date.now.timeIntervalSince(start)
        logger.info(
            "Film saved (\(Int(duration)) s, \(frames.screenCaptureKit) ScreenCaptureKit frames, \(frames.command) screencapture frames, \(frames.missed) missed): \(url.path(percentEncoded: false), privacy: .public)"
        )
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func movieURL() -> URL {
        let stamp: String = Date.now.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).hour().minute().second())
            .replacing("/", with: "-")
            .replacing(":", with: ".")
        return .moviesDirectory.appending(path: "Locky - écran verrouillé \(stamp).mov")
    }

    /// One screenshot with `screencapture`, which still works once the session is locked.
    private nonisolated static func captureWithCommand(displayID: CGDirectDisplayID, width: Int) async -> CGImage? {
        let url: URL = .temporaryDirectory.appending(path: "locky-film-frame.jpg")
        let process: Process = .init()
        process.executableURL = URL(filePath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-D", "1", "-t", "jpg", url.path(percentEncoded: false)]
        let finished: Bool = await withCheckedContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus == 0)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: false)
            }
        }
        guard finished, let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: width
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// Screenshots of a display with ScreenCaptureKit.
private struct ScreenshotSource {
    let filter: SCContentFilter
    let configuration: SCStreamConfiguration

    init?(displayID: CGDirectDisplayID, size: CGSize) async {
        guard
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
            let display = content.displays.first(where: { $0.displayID == displayID })
        else { return nil }
        filter = .init(display: display, excludingWindows: [])
        configuration = .init()
        configuration.width = Int(size.width)
        configuration.height = Int(size.height)
        configuration.showsCursor = false
    }

    func capture() async -> CGImage? {
        try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
}

/// Writes frames taken at irregular times into a QuickTime movie.
private actor FilmWriter {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let size: CGSize
    private var lastTime: CMTime = .negativeInfinity

    init(url: URL, size: CGSize) throws {
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ])
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        writer.add(input)
        self.size = size
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ image: CGImage, at seconds: TimeInterval) {
        let time: CMTime = .init(seconds: seconds, preferredTimescale: 600)
        guard time > lastTime, input.isReadyForMoreMediaData, let buffer = pixelBuffer(from: image) else { return }
        if adaptor.append(buffer, withPresentationTime: time) {
            lastTime = time
        }
    }

    func finish() async {
        input.markAsFinished()
        await writer.finishWriting()
    }

    private func pixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
#endif
