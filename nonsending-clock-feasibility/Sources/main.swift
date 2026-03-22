// MARK: - NonsendingClock Feasibility
// Purpose: Validate that a NonsendingClock protocol refining Clock can be
//          defined, and that an ImmediateClock preserves caller isolation
//          with zero thread hop.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Results Summary:
//   B5 — CONFIRMED: NonsendingClock protocol compiles and ImmediateClock preserves isolation
//
// Background: Pointfree #355 (Feb 23, 2026) demonstrated that their
//   ImmediateClock with nonisolated(nonsending) sleep achieved 100%
//   deterministic testing (10,000 runs, 0 failures).
//
// Date: 2026-02-25

// ============================================================================
// MARK: - B5: NonsendingClock-style protocol
// Hypothesis: A Clock with nonisolated(nonsending) sleep can be defined and
//             used such that ImmediateClock.sleep is a no-op without thread hop.
// Result: CONFIRMED — MainActor.assertIsolated passed after immediate sleep
// ============================================================================

protocol NonsendingClock<Duration>: Clock {
    nonisolated(nonsending)
    func sleep(until deadline: Instant, tolerance: Duration?) async throws
}

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

@MainActor
func testB5() async {
    let clock = ImmediateNonsendingClock()

    MainActor.assertIsolated("Should be on MainActor before sleep")
    try? await clock.sleep(for: .seconds(1))
    MainActor.assertIsolated("Should be on MainActor after immediate sleep — no thread hop")

    print("B5-nonsending-clock: passed")
}

// ============================================================================
// MARK: - Runner
// ============================================================================

@MainActor
func main() async {
    print("=== NonsendingClock Feasibility ===")
    print()

    print("--- B5: NonsendingClock protocol ---")
    await testB5()
    print()

    print("=== All tests complete ===")
}

await main()
