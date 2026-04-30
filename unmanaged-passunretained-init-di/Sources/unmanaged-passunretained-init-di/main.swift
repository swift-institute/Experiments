// MARK: - Does Unmanaged.passUnretained(self) sidestep DI during init?
//
// Purpose: Test whether wrapping `self` in `Unmanaged.passUnretained(self)`
//          inside the tick closure literal bypasses Swift's definite-init
//          check. Unmanaged is a value-type wrapper over an opaque pointer;
//          in principle it doesn't "capture self" in the reference-counting
//          sense, so maybe DI treats it differently.
//
// Hypothesis: DI is syntactic — it operates on the parse tree before
//          type-checking resolves `Unmanaged.passUnretained`. Any reference
//          to `self` in the closure body (even through a method call) is
//          flagged as self-capture. Unmanaged does NOT bypass DI.
//
// Toolchain: Swift 6.3 (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — observed diagnostic (Swift 6.3):
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//     main.swift:41:42: error: 'self' captured by a closure before all
//     members were initialized
//     main.swift:37: note: 'self.polling' not initialized
//   Plus strict-memory-safety warning on Unmanaged use.
//
//   `self` inside the closure triggers DI regardless of what it is passed
//   to. Unmanaged.passUnretained(self) does not sidestep DI — the
//   reference to `self` during the init of `self.polling` is the
//   violation, not the subsequent method call.
//
// Date: 2026-04-15

enum Outcome: Sendable { case `continue`, halt }

@safe
final class FakePolling: @unsafe @unchecked Sendable {
    private nonisolated(unsafe) var tick: (() -> Outcome)?

    init(tick: sending @escaping () -> Outcome) {
        unsafe (self.tick = tick)
    }
}

actor Reactor {
    nonisolated let polling: FakePolling
    var counter: Int = 0

    init() {
        self.polling = FakePolling(tick: {
            // Attempt: reference self via Unmanaged, not a closure capture
            let box = Unmanaged.passUnretained(self).takeUnretainedValue()
            return box.assumeIsolated { isolated in
                isolated.counter += 1
                return .continue
            }
        })
    }
}

let r = Reactor()
print("Compiled: \(type(of: r))")
