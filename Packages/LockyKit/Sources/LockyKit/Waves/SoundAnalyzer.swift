import Accelerate
import Foundation

/// Turns microphone samples into a ``SoundSpectrum``: the power spectrum of successive windows
/// (Hann), averaged, then summed into thirds of an octave.
public final class SoundAnalyzer {
    /// Samples per window: about 85 ms at 48 kHz, 12 Hz between two bins.
    public static let windowSize: Int = 4096

    public let sampleRate: Double
    private let transform: vDSP.DiscreteFourierTransform<Float>?
    private let window: [Float]
    private let windowEnergy: Double
    private let zeros: [Float]
    private var pending: [Float] = []
    private var powerSums: [Double]
    private var windowCount: Int = 0
    private var meanSquareSum: Double = 0
    private var loudestMeanSquare: Double = 0

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        transform = try? .init(count: Self.windowSize, direction: .forward, transformType: .complexComplex, ofType: Float.self)
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: Self.windowSize, isHalfWindow: false)
        windowEnergy = Double(vDSP.sumOfSquares(window))
        zeros = .init(repeating: 0, count: Self.windowSize)
        powerSums = .init(repeating: 0, count: Self.windowSize / 2)
    }

    /// Adds samples (mono, from -1 to 1), in the order they were recorded.
    public func add(_ samples: [Float]) {
        pending.append(contentsOf: samples)
        while pending.count >= Self.windowSize {
            analyze(Array(pending.prefix(Self.windowSize)))
            pending.removeFirst(Self.windowSize)
        }
    }

    /// Windows analyzed so far.
    public var analyzedWindows: Int {
        windowCount
    }

    /// The spectrum of everything added, `nil` before a whole window.
    public func spectrum() -> SoundSpectrum? {
        guard windowCount > 0 else { return nil }
        let binWidth: Double = sampleRate / Double(Self.windowSize)
        let averagePower: [Double] = powerSums.map { $0 / Double(windowCount) }
        let centers: [Double] = SoundSpectrum.bandCenters.filter { $0 * pow(2, 1.0 / 6) < sampleRate / 2 }
        var levels: [Double] = []
        for center in centers {
            let low: Double = center / pow(2, 1.0 / 6)
            let high: Double = center * pow(2, 1.0 / 6)
            let first: Int = max(1, Int((low / binWidth).rounded(.up)))
            let last: Int = min(averagePower.count - 1, Int((high / binWidth).rounded(.down)))
            // The lowest bands are narrower than a bin: the bin they fall in.
            let power: Double = first <= last
                ? averagePower[first...last].reduce(0, +)
                : averagePower[min(max(Int((center / binWidth).rounded()), 1), averagePower.count - 1)]
            levels.append(Self.decibels(power))
        }
        let loudestBin: Int? = averagePower.indices.dropFirst().max { averagePower[$0] < averagePower[$1] }
        return .init(
            frequencies: centers,
            levels: levels,
            averageLevel: Self.decibels(meanSquareSum / Double(windowCount)),
            peakLevel: Self.decibels(loudestMeanSquare),
            dominantFrequency: loudestBin.map { Double($0) * binWidth }
        )
    }

    private func analyze(_ samples: [Float]) {
        let meanSquare: Double = Double(vDSP.meanSquare(samples))
        meanSquareSum += meanSquare
        loudestMeanSquare = max(loudestMeanSquare, meanSquare)
        guard let transform else { return }
        let windowed: [Float] = vDSP.multiply(samples, window)
        let output: (real: [Float], imaginary: [Float]) = transform.transform(real: windowed, imaginary: zeros)
        // Power of each bin, scaled so that the bins of a band add up to the mean square of what
        // sounds in it (Parseval, the energy of the window taken out): a band reads like the
        // average level.
        let scale: Double = 2 / (Double(Self.windowSize) * windowEnergy)
        for bin in powerSums.indices {
            let real: Double = Double(output.real[bin])
            let imaginary: Double = Double(output.imaginary[bin])
            powerSums[bin] += (real * real + imaginary * imaginary) * scale
        }
        windowCount += 1
    }

    /// Power (mean square) in decibels relative to full scale, floored at -120 dB.
    static func decibels(_ power: Double) -> Double {
        max(10 * log10(max(power, 1e-12)), -120)
    }
}
