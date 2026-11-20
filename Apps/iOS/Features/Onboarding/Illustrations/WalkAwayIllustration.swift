import SwiftUI

/// Footsteps walking away from the Mac (it locks) and coming back (it unlocks), in a loop.
struct WalkAwayIllustration: View {
    private static let stepCount: Int = 5
    /// Ticks spent at each end of the walk (locked far away, celebrating back at the Mac).
    private static let pauseLength: Int = 3
    /// Each way: the turn, the steps, then the pause.
    private static let legLength: Int = 1 + stepCount + pauseLength
    private static let cycle: Int = legLength * 2

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.42)) { timeline in
            let tick: Int = .init(timeline.date.timeIntervalSinceReferenceDate / 0.42) % Self.cycle
            let phase: Phase = .init(tick: tick, stepCount: Self.stepCount, legLength: Self.legLength)
            HStack(alignment: .center, spacing: 0) {
                ZStack {
                    MacOutline {
                        Image(systemName: phase.isLocked ? "lock.fill" : "lock.open.fill")
                            .font(.title)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    if phase.isCelebrating {
                        SparklesView()
                            .transition(.opacity)
                    }
                }
                .frame(width: 120)
                Footsteps(litCount: phase.litSteps, isReturning: phase.isReturning, stepCount: Self.stepCount)
            }
            .animation(.easeInOut(duration: 0.3), value: tick)
        }
        .foregroundStyle(Color.brandArt)
        .accessibilityHidden(true)
    }

    /// Where the walk is: each way starts by turning the footprints around, all faded again,
    /// then lights them one by one in the walking direction.
    private struct Phase {
        /// Footprints lit since the last turn, counted in the walking direction.
        let litSteps: Int
        let isReturning: Bool
        let isLocked: Bool
        let isCelebrating: Bool

        init(tick: Int, stepCount: Int, legLength: Int) {
            let legTick: Int = tick % legLength
            let hasArrived: Bool = legTick > stepCount
            isReturning = tick >= legLength
            litSteps = min(legTick, stepCount)
            // Locked once far away, until back at the Mac.
            isLocked = isReturning ? !hasArrived : hasArrived
            isCelebrating = isReturning && hasArrived
        }
    }
}

/// A trail of footprints going right (or coming back left), lit as they are walked.
private struct Footsteps: View {
    let litCount: Int
    let isReturning: Bool
    let stepCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { index in
                Image(index.isMultiple(of: 2) ? .stepLeft : .stepRight)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34)
                    .scaleEffect(x: isReturning ? -1 : 1)
                    .offset(y: index.isMultiple(of: 2) ? -10 : 10)
                    .opacity(isLit(index) ? 1 : 0.12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Going away the trail lights from the Mac; coming back, from the far end.
    private func isLit(_ index: Int) -> Bool {
        isReturning ? index >= stepCount - litCount : index < litCount
    }
}
