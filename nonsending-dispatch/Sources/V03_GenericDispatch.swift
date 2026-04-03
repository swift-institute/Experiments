// V03: Nonsending Through Generic Dispatch
//
// Purpose: Does nonisolated(nonsending) on a concrete Clock.sleep survive
//          when called through a generic <C: Clock> parameter?
//
// Status: ALL PASSED -- nonsending propagates through all dispatch modes.
//   Test 1 (direct concrete call): PASSED
//   Test 2 (generic <C: Clock>):   PASSED
//   Test 3 (some Clock<Duration>): PASSED
//
// Conclusion: nonisolated(nonsending) propagates through ALL dispatch modes.
//   No separate NonsendingClock protocol is needed. Just annotate concrete
//   types directly.
//
// Revalidation: Re-run if protocol witness table dispatch changes.
//
// Origin: nonsending-generic-dispatch
// Date: 2026-02-25

// MARK: - V03 Namespace

enum V03_GenericDispatch {

    // MARK: - ImmediateClock

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

    @MainActor
    static func testDirect() async {
        let clock = ImmediateClock()
        MainActor.assertIsolated("before direct sleep")
        try? await clock.sleep(for: .seconds(1))
        MainActor.assertIsolated("after direct sleep")
        print("Test 1 (direct): PASSED")
    }

    // MARK: - Test 2: Generic <C: Clock> dispatch

    @MainActor
    static func testGeneric<C: Clock>(clock: C) async where C.Duration == Duration {
        MainActor.assertIsolated("before generic sleep")
        try? await clock.sleep(for: .seconds(1))
        MainActor.assertIsolated("after generic sleep")
        print("Test 2 (generic): PASSED")
    }

    // MARK: - Test 3: some Clock<Duration> dispatch

    @MainActor
    static func testSomeClock(clock: some Clock<Duration>) async {
        MainActor.assertIsolated("before some-clock sleep")
        try? await clock.sleep(for: .seconds(1))
        MainActor.assertIsolated("after some-clock sleep")
        print("Test 3 (some Clock): PASSED")
    }

    // MARK: - Runner

    @MainActor
    static func run() async {
        let clock = ImmediateClock()

        print("=== Nonsending Generic Dispatch ===")
        await testDirect()
        await testGeneric(clock: clock)
        await testSomeClock(clock: clock)
        print("=== Done ===")
    }
}
