// MARK: - Runtime ~Copyable Shutdown Experiment
// Purpose: Can we make double-shutdown a compile-time error via ~Copyable?
// Hypothesis: A ~Copyable token can enforce single-shutdown at the type level
//
// Toolchain: Xcode 26.0 / Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — V3/V4/V5 all work. V1 (actor ~Copyable) REFUTED.
//         Gate fix (Async.Gate) solves idempotency structurally without
//         the API surface change. Token pattern is viable for future
//         redesign that removes shutdown() from Selector entirely.
// Date: 2026-04-04

import Synchronization

// ============================================================================
// MARK: - Variant 1: ~Copyable Actor
// Hypothesis: An actor can be declared ~Copyable
// Result: REFUTED — "actors cannot be '~Copyable'" (compiler error)
// ============================================================================

// Uncomment to test. Expected: actors are reference types, ~Copyable rejected.
// actor NoncopyableRuntime: ~Copyable {
//     consuming func shutdown() async { }
// }

// ============================================================================
// MARK: - Variant 2: ~Copyable Wrapper (no deinit) — consuming shutdown
// Hypothesis: A ~Copyable struct wrapping an actor can provide consuming shutdown.
//             After consuming close(), the wrapper is dead — no second call.
// Result: CONFIRMED — consuming shutdown prevents second call at compile time
// ============================================================================

actor MockRuntime2 {
    func performShutdown() async {
        print("V2: shutdown performed")
    }
}

struct RuntimeHandle2: ~Copyable, Sendable {
    let runtime: MockRuntime2

    consuming func shutdown() async {
        await runtime.performShutdown()
        // self is consumed — compiler rejects a second call
    }
}

// ============================================================================
// MARK: - Variant 3: ~Copyable Token (separated from Selector)
// Hypothesis: Shutdown capability as a ~Copyable token, separate from the
//             Copyable Selector. Channels share the Selector; only Scope
//             holds the token. No shutdown() on Selector at all.
// Result: CONFIRMED — clean separation of shared handle vs single-use capability
// ============================================================================

// The token has no deinit — it's pure capability. Dropping it without
// execute() means shutdown doesn't happen through this path.
// Emergency cleanup is the Scope's deinit responsibility (sync-only halt).

actor MockRuntime3 {
    func performShutdown() async {
        print("V3: shutdown performed")
    }
}

struct ShutdownToken3: ~Copyable, Sendable {
    let runtime: MockRuntime3

    consuming func execute() async {
        await runtime.performShutdown()
    }
}

struct MockSelector3: Sendable {
    let runtime: MockRuntime3
    // No shutdown() — channels use this freely
    func register() { print("V3: register") }
}

// ============================================================================
// MARK: - Variant 4: Scope with ~Copyable token + deinit coordination
// Hypothesis: Scope holds the token in an Optional, consuming close() takes
//             the token and executes it. Deinit provides sync emergency cleanup.
//
// Challenge: ~Copyable struct with deinit cannot partially consume self.
//            The take() pattern (Optional + nil) is the workaround.
// Result: CONFIRMED — Mutex<Token?> + take() works around partial-consume limitation
// ============================================================================

// Simulates the actual Scope pattern: consuming close() + deinit for emergency.

struct ShutdownToken4: ~Copyable, Sendable {
    let _execute: @Sendable () async -> Void

    consuming func execute() async {
        await _execute()
    }
}

struct MockScope4: ~Copyable {
    let selector: MockSelector3

    // Token wrapped in Mutex to avoid partial-consume-with-deinit limitation.
    // The Mutex makes the take() operation safe across consuming/deinit paths.
    private let _token: Mutex<ShutdownToken4?>

    private let _haltFlag: Atomic<Bool> = Atomic(false)

    init(selector: MockSelector3, token: consuming ShutdownToken4) {
        self.selector = selector
        self._token = Mutex(token)
    }

    consuming func close() async {
        let taken: ShutdownToken4? = _token.withLock { $0.take() }
        if let token = taken {
            await token.execute()
        }
        // deinit fires after this — _token is nil, haltFlag not needed
    }

    deinit {
        let taken: ShutdownToken4? = _token.withLock { $0.take() }
        if taken != nil {
            // Emergency: close() was never called. Can't run async shutdown.
            // Set halt flag synchronously — poll thread checks this.
            _haltFlag.store(true, ordering: .releasing)
            print("V4: emergency deinit — halt flag set")
        }
    }
}

// ============================================================================
// MARK: - Variant 5: Scope WITHOUT deinit — pure consuming close()
// Hypothesis: If Scope has no deinit, consuming close() can directly consume
//             the token field without the partial-consume limitation.
//             Trade-off: no emergency cleanup on drop.
// Result: CONFIRMED — cleanest pattern but loses deinit safety net
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

struct MockScope5: ~Copyable {
    let selector: MockSelector3
    var token: ShutdownToken3  // NOT optional — must be consumed

    consuming func close() async {
        await token.execute()
        // token consumed, self consumed — done
    }

    // No deinit — if dropped without close(), token leaks
    // The #require(consume scope) pattern or ~Escapable could catch this
}

// ============================================================================
// MARK: - Execution
// ============================================================================

@main
struct Main {
    static func main() async {
        print("=== Variant 2: ~Copyable Wrapper (no deinit) ===")
        do {
            let handle = RuntimeHandle2(runtime: MockRuntime2())
            await handle.shutdown()
            // Uncommenting the next line should be a compile error:
            // await handle.shutdown()  // error: 'handle' used after consume
            print("V2: double call prevented at compile time\n")
        }

        print("=== Variant 3: ~Copyable Token (no Scope) ===")
        do {
            let runtime = MockRuntime3()
            let token = ShutdownToken3(runtime: runtime)
            let selector = MockSelector3(runtime: runtime)
            selector.register()
            await token.execute()
            // Uncommenting the next line should be a compile error:
            // await token.execute()  // error: 'token' used after consume
            print("V3: double call prevented at compile time\n")
        }

        print("=== Variant 4: Scope + Mutex<Token?> + deinit ===")
        do {
            let runtime = MockRuntime3()
            let selector = MockSelector3(runtime: runtime)
            let scope = MockScope4(
                selector: selector,
                token: ShutdownToken4(_execute: { print("V4: shutdown performed") })
            )
            await scope.close()
            // scope consumed — cannot call close() again
            print("V4: consuming close + deinit coordination works\n")
        }

        print("=== Variant 4b: Scope dropped without close ===")
        do {
            let runtime = MockRuntime3()
            let selector = MockSelector3(runtime: runtime)
            let _ = MockScope4(
                selector: selector,
                token: ShutdownToken4(_execute: { print("V4b: should NOT print") })
            )
            // scope dropped — deinit fires, sets halt flag
            print("V4b: emergency deinit handled\n")
        }

        print("=== Variant 5: Pure consuming (no deinit) ===")
        do {
            let runtime = MockRuntime3()
            let selector = MockSelector3(runtime: runtime)
            let scope = MockScope5(selector: selector, token: ShutdownToken3(runtime: runtime))
            await scope.close()
            // scope consumed — cannot call close() again
            print("V5: pure consuming close works\n")
        }
    }
}
