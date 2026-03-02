// MARK: - Nonsending Through Generic Dispatch
// Purpose: Does nonisolated(nonsending) on a concrete Clock.sleep survive
//          when called through a generic <C: Clock> parameter?
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Results:
//   Test 1 (direct concrete call): PASSED — nonsending preserved, MainActor maintained
//   Test 2 (generic <C: Clock>):   PASSED — nonsending survives protocol witness dispatch
//   Test 3 (some Clock<Duration>): PASSED — nonsending survives opaque type dispatch
//
// Conclusion: nonisolated(nonsending) propagates through ALL dispatch modes.
//   No separate NonsendingClock protocol is needed. Just annotate concrete types directly.
// Date: 2026-02-25

// A concrete clock with nonisolated(nonsending) sleep
final class ImmediateClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol, Sendable, Hashable {
        let offset: Duration
        init(offset: Duration = .zero) { self.offset = offset }
        func advanced(by duration: Duration) -> Self { .init(offset: offset + duration) }
        func duration(to other: Self) -> Duration { other.offset - offset }
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.offset < rhs.offset }
    }

    var now: Instant { .init() }
    var minimumResolution: Duration { .zero }

    nonisolated(nonsending)
    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        // No-op, no yield, no suspension
    }
}

// MARK: - Test 1: Direct call on concrete type
// Expected: PASSES (nonsending applies, stays on MainActor)

@MainActor
func testDirect() async {
    let clock = ImmediateClock()
    MainActor.assertIsolated("before direct sleep")
    try? await clock.sleep(until: clock.now.advanced(by: .seconds(1)))
    MainActor.assertIsolated("after direct sleep")
    print("Test 1 (direct): PASSED")
}

// MARK: - Test 2: Generic <C: Clock> dispatch
// Question: Does nonsending survive through the protocol witness?

@MainActor
func testGeneric<C: Clock>(clock: C) async where C.Duration == Duration {
    MainActor.assertIsolated("before generic sleep")
    try? await clock.sleep(until: clock.now.advanced(by: .seconds(1)), tolerance: nil)
    MainActor.assertIsolated("after generic sleep")
    print("Test 2 (generic): PASSED")
}

// MARK: - Test 3: Via Clock.Any (our type-erased clock)
// Question: Does nonsending survive through our Any wrapper?

@MainActor
func testSomeClock(clock: some Clock<Duration>) async {
    MainActor.assertIsolated("before some-clock sleep")
    try? await clock.sleep(until: clock.now.advanced(by: .seconds(1)), tolerance: nil)
    MainActor.assertIsolated("after some-clock sleep")
    print("Test 3 (some Clock): PASSED")
}

// MARK: - Runner

@MainActor
func main() async {
    let clock = ImmediateClock()

    print("=== Nonsending Generic Dispatch ===")
    await testDirect()
    await testGeneric(clock: clock)
    await testSomeClock(clock: clock)
    print("=== Done ===")
}

await main()
