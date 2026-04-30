// MARK: - Does `var polling: Polling! = nil` satisfy DI without nonisolated(unsafe)?
//
// Purpose: Test whether replacing `nonisolated let polling` with
//          `nonisolated var polling: Polling! = nil` (default value) allows
//          [weak self] to be used in a subsequent assignment — since at the
//          point of that assignment, all stored properties have a default
//          value, so `self` should be fully-initialized per the DI rule.
//
// Hypothesis:
//   V1 — `nonisolated var polling: Polling! = nil` on an actor is rejected
//        by Swift 6.3: nonisolated mutable state on an actor requires
//        `nonisolated(unsafe)` marking (supervisor rule #2 explicitly forbids
//        this on `polling`).
//   V2 — Dropping `nonisolated` and using `var polling: Polling! = nil` on
//        the actor makes polling actor-isolated. The `unownedExecutor`
//        accessor cannot read it without an isolation hop, defeating the
//        zero-hop design.
//   V3 — Using a non-actor class `Actor` with plain stored state (no actor
//        isolation) and a `var polling: Polling! = nil` default would avoid
//        DI, but regresses from compile-time actor isolation to manual
//        synchronization — violates [IMPL-069] isolation hierarchy.
//
// Toolchain: Swift 6.3 (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — observed diagnostics:
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//   V1 (ENABLE_V1): "'nonisolated' cannot be applied to mutable stored
//     properties" — compiler suggests `nonisolated(unsafe)` (rule #2
//     forbids on `polling`).
//   V2 (ENABLE_V2): "cannot access property 'polling' here in nonisolated
//     initializer" — actor-isolated var is not reachable from the
//     nonisolated init expression that assigns it.
//   V3 (default): "passing closure as a 'sending' parameter risks causing
//     data races" — even dropping the actor, Swift 6 strict concurrency
//     requires explicit sync for shared state in the tick closure.
//     Would compile only by adding locks (rank 4 vs rank 1 — regression).
//
// Conclusion: no path through `var polling = nil` avoids a supervisor-rule
//   violation or isolation-hierarchy regression on Swift 6.3.
//
// Date: 2026-04-15

// ============================================================================
// MARK: - Minimal types
// ============================================================================

enum Outcome: Sendable { case `continue`, halt }

@safe
final class FakePolling: @unsafe @unchecked Sendable {
    private nonisolated(unsafe) var tick: (() -> Outcome)?

    init(tick: sending @escaping () -> Outcome) {
        unsafe (self.tick = tick)
    }
}

// ============================================================================
// MARK: - V1: `nonisolated var polling: Polling! = nil` with [weak self]
// ============================================================================
// Attempt: declare polling as a nonisolated var with nil default, so all
// stored props have values at init entry. Then assign polling with [weak self]
// in the init body.

#if ENABLE_V1
actor ReactorV1 {
    nonisolated var polling: FakePolling! = nil   // EXPECTED: rejected
    var counter: Int = 0

    init() {
        self.polling = FakePolling(tick: { [weak self] in
            guard let self else { return .halt }
            return self.assumeIsolated { isolated in
                isolated.counter += 1
                return .continue
            }
        })
    }
}
#endif

// ============================================================================
// MARK: - V2: actor-isolated `var polling` — loses nonisolated accessor
// ============================================================================
// Attempt: drop `nonisolated` from polling. Self-capture now works (because
// default value means self is init'd at body entry). But `unownedExecutor`
// cannot be computed from actor-isolated state without a hop.

#if ENABLE_V2
actor ReactorV2 {
    var polling: FakePolling! = nil
    var counter: Int = 0

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        // EXPECTED: cannot access actor-isolated `polling` from nonisolated
        unsafe UnownedSerialExecutor(ordinary: polling)
    }

    init() {
        self.polling = FakePolling(tick: { [weak self] in
            guard let self else { return .halt }
            return self.assumeIsolated { isolated in
                isolated.counter += 1
                return .continue
            }
        })
    }
}
#endif

// ============================================================================
// MARK: - V3: non-actor class Actor — regresses isolation
// ============================================================================
// Attempt: replace `actor Actor` with `final class Actor`. No actor isolation
// needed; [weak self] works. But: all methods need manual sync (locks).
// This is [IMPL-069] rank 4 (Mutex), down from rank 1 (Actor).

final class ReactorV3 {
    var polling: FakePolling! = nil
    var counter: Int = 0        // now needs lock for thread-safe access

    init() {
        self.polling = FakePolling(tick: { [weak self] in
            guard let self else { return .halt }
            self.counter += 1   // needs lock for concurrent safety
            return .continue
        })
    }
}

// V3 COMPILES but regresses compile-time actor isolation to programmer-
// verified mutex discipline — violates [IMPL-069] rank-1-first rule.

print("V3 class-regression compiles: \(type(of: ReactorV3()))")
