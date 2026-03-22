// MARK: - Nonsending Closure Type Constraints
// Purpose: Determine where nonisolated(nonsending) can be applied to closure types.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Results Summary:
//   B1a — CONFIRMED: nonisolated(nonsending) async closures can be stored in structs
//   B1b — CONFIRMED: nonisolated(nonsending) async closures can be stored in actors
//   B1d — CONFIRMED: nonisolated(nonsending) CANNOT be used on sync function types
//
// Key Discovery: nonisolated(nonsending) ONLY applies to async function types.
//   This means sync operator closures (map, filter, scan, etc.) cannot use it.
//   Only async operator closures (map(async:), filter(async:)) benefit.
//
// Date: 2026-02-25

// ============================================================================
// MARK: - B1a: Stored async nonsending closure in a struct
// Hypothesis: nonisolated(nonsending) closures CAN be stored as struct properties
//             when the function type is async.
// Result: CONFIRMED — Build Succeeded, Output: B1a-struct: 42
// ============================================================================

struct StoredNonsendingAsync {
    let operation: nonisolated(nonsending) (Int) async -> Int

    init(_ operation: nonisolated(nonsending) @escaping (Int) async -> Int) {
        self.operation = operation
    }

    func apply(_ value: Int) async -> Int {
        await operation(value)
    }
}

// ============================================================================
// MARK: - B1b: Stored async nonsending closure in an actor
// Hypothesis: nonisolated(nonsending) closures CAN be stored as actor properties
//             (the operator state pattern).
// Result: CONFIRMED — Output: B1b-actor: 21, 42
// ============================================================================

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
// MARK: - Runner
// ============================================================================

@MainActor
func main() async {
    print("=== Nonsending Closure Type Constraints ===")
    print()

    print("--- B1: Stored nonisolated(nonsending) async closures ---")
    await testB1()
    print()

    print("--- B1d: Sync closures cannot be nonsending (see commented code) ---")
    print("B1d: CONFIRMED — compiler rejects nonisolated(nonsending) on sync function types")
    print()

    print("=== All tests complete ===")
}

await main()
