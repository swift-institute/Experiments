// MARK: - Stdlib Concurrency Isolation Propagation
// Purpose: Validate that stdlib concurrency primitives (withCheckedContinuation,
//          withTaskCancellationHandler) propagate caller isolation.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Results Summary:
//   B2 — CONFIRMED: withCheckedContinuation/withUnsafeContinuation body inherits caller isolation
//   B3 — CONFIRMED: withTaskCancellationHandler has nonisolated(nonsending) overload
//
// Date: 2026-02-25

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
// MARK: - Runner
// ============================================================================

@MainActor
func main() async {
    print("=== Stdlib Concurrency Isolation Propagation ===")
    print()

    print("--- B2: withCheckedContinuation isolation propagation ---")
    await testB2()
    print()

    print("--- B3: withTaskCancellationHandler nonsending overload ---")
    await testB3()
    print()

    print("=== All tests complete ===")
}

await main()
