// MARK: - Nonsending Blocker Validation
// Purpose: Empirically validate the 4 language blockers identified in
//          the Pointfree #355 ecosystem analysis research reports.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Results Summary:
//   B1  — CONFIRMED: nonisolated(nonsending) async closures can be stored in structs and actors
//   B1d — CONFIRMED: nonisolated(nonsending) CANNOT be used on sync function types
//   B2  — CONFIRMED: withCheckedContinuation/withUnsafeContinuation body inherits caller isolation
//   B3  — CONFIRMED: withTaskCancellationHandler has nonisolated(nonsending) overload
//   B4a — NOT A BLOCKER: ~Escapable CAN store @escaping closures (with immortal lifetime)
//   B4b — CONFIRMED: ~Escapable + Sendable work together (orthogonal)
//   B5  — CONFIRMED: NonsendingClock protocol compiles and ImmediateClock preserves isolation
//
// Key Discovery: nonisolated(nonsending) ONLY applies to async function types.
//   This means sync operator closures (map, filter, scan, etc.) cannot use it.
//   Only async operator closures (map(async:), filter(async:)) benefit.
//
// Date: 2026-02-25

// ============================================================================
// MARK: - B1: @escaping nonisolated(nonsending) ASYNC closure stored in a type
// Hypothesis: nonisolated(nonsending) closures CAN be stored as properties,
//             but ONLY for async function types (sync is not applicable).
// Result: CONFIRMED — Build Succeeded, Output: B1a-struct: 42, B1b-actor: 21, 42
// ============================================================================

// B1a: Stored async nonsending closure in a struct
struct StoredNonsendingAsync {
    let operation: nonisolated(nonsending) (Int) async -> Int

    init(_ operation: nonisolated(nonsending) @escaping (Int) async -> Int) {
        self.operation = operation
    }

    func apply(_ value: Int) async -> Int {
        await operation(value)
    }
}

// B1b: Stored async nonsending closure in an actor (operator state pattern)
actor NonsendingOperatorState {
    let transform: nonisolated(nonsending) (Int) async -> Int
    var accumulated: Int = 0

    init(_ transform: nonisolated(nonsending) @escaping (Int) async -> Int) {
        self.transform = transform
    }

    func next(_ value: Int) async -> Int {
        let result = await transform(value)
        accumulated += result
        return accumulated
    }
}

// B1c: Can a nonsending async closure cross into an actor init?
// This tests the actor-init isolation boundary concern from the research.
func testB1() async {
    // Struct with stored nonsending closure
    let stored = StoredNonsendingAsync { $0 * 2 }
    let r1 = await stored.apply(21)
    print("B1a-struct: \(r1)")  // Expected: 42

    // Actor with stored nonsending closure
    let state = NonsendingOperatorState { $0 * 3 }
    let r2 = await state.next(7)
    let r3 = await state.next(7)
    print("B1b-actor: \(r2), \(r3)")  // Expected: 21, 42
}

// ============================================================================
// MARK: - B1d: Sync closures — nonisolated(nonsending) NOT applicable
// Discovery: nonisolated(nonsending) only applies to async function types.
//            Sync closures like map/filter transforms cannot use it.
//            This significantly narrows the adoption surface.
// Result: CONFIRMED — error: cannot use 'nonisolated(nonsending)' on non-async function type
// ============================================================================

// Uncomment to verify compiler error:
// struct SyncNonsending {
//     let transform: nonisolated(nonsending) (Int) -> Int
//     // error: cannot use 'nonisolated(nonsending)' on non-async function type
// }

// ============================================================================
// MARK: - B2: withCheckedContinuation preserves caller isolation via #isolation
// Hypothesis: withCheckedContinuation body inherits caller isolation through
//             the isolation: parameter, eliminating thread hops.
// Result: CONFIRMED — MainActor.assertIsolated passed in both continuation bodies
// ============================================================================

@MainActor
func testB2() async {
    MainActor.assertIsolated("Should be on MainActor before continuation")

    let value = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
        MainActor.assertIsolated("Should be on MainActor inside checked continuation body")
        continuation.resume(returning: 42)
    }
    print("B2a-checked: \(value)")  // Expected: 42

    let value2 = await withUnsafeContinuation { (continuation: UnsafeContinuation<Int, Never>) in
        MainActor.assertIsolated("Should be on MainActor inside unsafe continuation body")
        continuation.resume(returning: 99)
    }
    print("B2b-unsafe: \(value2)")  // Expected: 99
}

// ============================================================================
// MARK: - B3: withTaskCancellationHandler nonisolated(nonsending) overload
// Hypothesis: withTaskCancellationHandler operation inherits caller isolation.
// Result: CONFIRMED — MainActor.assertIsolated passed inside operation
// ============================================================================

@MainActor
func testB3() async {
    MainActor.assertIsolated("Should be on MainActor before cancellation handler")

    let result = await withTaskCancellationHandler {
        MainActor.assertIsolated("Should be on MainActor inside operation")
        return 42
    } onCancel: {
        print("B3: cancelled (not expected)")
    }
    print("B3-handler: \(result)")  // Expected: 42
}

// ============================================================================
// MARK: - B4a: ~Escapable type storing a closure
// Hypothesis: ~Escapable types CANNOT store closures. Expected: REFUTED.
// Result: REFUTED — ~Escapable CAN store @escaping closures (see negative experiment)
//         The actual blocker is: @_lifetime cannot depend on Escapable closure params,
//         and lifetime-dependent ~Escapable values cannot be captured in closures.
// ============================================================================

// Uncomment to test — expected compiler error:
// struct NonEscapableWithClosure: ~Escapable {
//     let action: () -> Void
//     @_lifetime(immortal)
//     init(action: () -> Void) {
//         self.action = action
//     }
// }

// ============================================================================
// MARK: - B4b: ~Escapable + Sendable (orthogonal features)
// Hypothesis: ~Escapable types CAN conform to Sendable.
// Result: CONFIRMED — Output: B4b-sendable-nonescapable: 42
// ============================================================================

struct SendableNonEscapable: ~Escapable, Sendable {
    let value: Int

    @_lifetime(immortal)
    init(value: Int) {
        self.value = value
    }
}

func testB4b() {
    let sne = SendableNonEscapable(value: 42)
    print("B4b-sendable-nonescapable: \(sne.value)")  // Expected: 42
}

// ============================================================================
// MARK: - B5: NonsendingClock-style protocol (does Clock.sleep propagate isolation?)
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
    try? await clock.sleep(until: clock.now.advanced(by: .seconds(1)), tolerance: nil)
    MainActor.assertIsolated("Should be on MainActor after immediate sleep — no thread hop")

    print("B5-nonsending-clock: passed")
}

// ============================================================================
// MARK: - Runner
// ============================================================================

@MainActor
func main() async {
    print("=== Nonsending Blocker Validation ===")
    print()

    print("--- B1: Stored nonisolated(nonsending) async closures ---")
    await testB1()
    print()

    print("--- B2: withCheckedContinuation isolation propagation ---")
    await testB2()
    print()

    print("--- B3: withTaskCancellationHandler nonsending overload ---")
    await testB3()
    print()

    print("--- B4b: ~Escapable + Sendable ---")
    testB4b()
    print()

    print("--- B5: NonsendingClock protocol ---")
    await testB5()
    print()

    print("=== All tests complete ===")
}

await main()
