// MARK: - Does `sending @escaping` at init relax the DI rule for [weak self]?
// Purpose: Test whether changing the tick parameter from @Sendable to
//          `sending @escaping` relaxes Swift's definite-init check so
//          that `[weak self]` inside the closure literal becomes legal
//          even when self.polling (the only stored property) is the
//          target of the assignment containing that closure.
//
// Hypothesis: `sending` has region semantics but does NOT relax the DI
//          rule. Self-capture (weak or otherwise) before all stored
//          properties are initialised remains an error.
//
// Toolchain: Swift 6.3 (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — sending @escaping at init does NOT relax the DI rule.
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//   Compiler error (Swift 6.3):
//     main.swift:47:50: error: variable 'self.polling' used before being initialized
//         self.polling = FakePolling(tick: { [weak self] in
//                                                  `- error: variable 'self.polling' used before being initialized
//   Command: swift build
//
//   Conclusion: the DI rule is orthogonal to closure isolation /
//   sendability. Replacing @Sendable with `sending` changes nothing
//   at the self-capture site — the rule is about stored-property
//   initialisation order, not about Sendable conformance or region
//   transfer. Any fix must either (a) delay the [weak self] capture
//   until after self.polling is assigned (two-phase API / weak-box),
//   or (b) avoid self-capture entirely.
//
// Date: 2026-04-15

// ============================================================================
// MARK: - Minimal reactor with `sending @escaping` tick at init
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
// MARK: - V1: [weak self] with sending @escaping at init (same DI position)
// ============================================================================
// This mirrors the swift-io situation: the actor's single stored property
// is `polling: FakePolling`, assigned via `Polling(tick: { [weak self] in ... })`.
// At the point of the closure literal, self.polling is NOT yet assigned,
// so self is not fully-initialised. Test whether `sending` relaxes this.

actor Reactor {
    nonisolated let polling: FakePolling
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

let r = Reactor()
print("Compiled: \(type(of: r))")
