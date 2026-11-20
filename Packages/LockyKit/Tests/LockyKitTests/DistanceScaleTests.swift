import Foundation
import Testing
@testable import LockyKit

struct DistanceScaleTests {
    @Test func endsOfTheScale() {
        #expect(DistanceScale.ratio(for: DistanceScale.range.lowerBound) == 0)
        #expect(abs(DistanceScale.ratio(for: DistanceScale.range.upperBound) - 1) < 1e-12)
    }

    @Test func clampsOutOfRangeDistances() {
        #expect(DistanceScale.ratio(for: 0) == 0)
        #expect(DistanceScale.ratio(for: 50) == 1)
    }

    @Test(arguments: [0.5, 1, 1.5, 3, 7.5, 10])
    func ratioAndDistanceAreInverse(distance: Double) {
        #expect(abs(DistanceScale.distance(at: DistanceScale.ratio(for: distance)) - distance) < 1e-9)
    }

    @Test func shortDistancesGetMostOfTheRoom() {
        // The default lock distance sits before the middle of the scale.
        #expect(DistanceScale.ratio(for: DistanceModel.defaultLockDistance) < 0.5)
    }
}
