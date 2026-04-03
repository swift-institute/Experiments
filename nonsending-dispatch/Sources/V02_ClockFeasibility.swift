// V02: NonsendingClock Feasibility
//
// Purpose: Validate that a NonsendingClock protocol refining Clock can be
//          defined, and that an ImmediateClock preserves caller isolation
//          with zero thread hop.
//
// Status: CONFIRMED -- NonsendingClock protocol compiles and ImmediateClock
//         preserves isolation.
//
// Background: Pointfree #355 (Feb 23, 2026) demonstrated that their
//   ImmediateClock with nonisolated(nonsending) sleep achieved 100%
//   deterministic testing (10,000 runs, 0 failures).
//
// Revalidation: Re-run if Clock protocol requirements change.
//
// Origin: nonsending-clock-feasibility
// Date: 2026-02-25

// MARK: - V02 Namespace

enum V02_ClockFeasibility {

    // MARK: - NonsendingClock protocol

    protocol NonsendingClock<Duration>: Clock {
        nonisolated(nonsending)
        func sleep(until deadline: Instant, tolerance: Duration?) async throws
    }

    // MARK: - ImmediateNonsendingClock

    struct ImmediateNonsendingClock: NonsendingClock {
        typealias Instant = ContinuousClock.Instant
        typealias Duration = Swift.Duration

        var now: Instant { ContinuousClock.now }
        var minimumResolution: Duration { .zero }

        nonisolated(nonsending)
        func sleep(until deadline: Instant, tolerance: Duration?) async throws {
            // No-op: immediate clock never sleeps
        }
    }

    // MARK: - Runner

    @MainActor
    static func run() async {
        let clock = ImmediateNonsendingClock()

        MainActor.assertIsolated("Should be on MainActor before sleep")
        try? await clock.sleep(for: .seconds(1))
        MainActor.assertIsolated("Should be on MainActor after immediate sleep -- no thread hop")

        print("B5-nonsending-clock: passed")
    }
}
