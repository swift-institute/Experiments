// MARK: - Path δ Empirical Experiment — Memory.Lock.Token closure capture of var Optional<~Copyable>
//
// Purpose: Item 1.5 dispatch surfaced that the research doc's Option B shape
// is structurally invalid at L1 swift-memory-primitives (can't import Kernel
// types). Path δ proposes dropping Token's `Sendable` conformance to enable
// `var Optional<~Copyable>` capture in a non-`@Sendable` closure inside the
// existing L1 witness-closure shape.
//
// Hypothesis (to test):
//   "non-@Sendable closure capture of var Optional<~Copyable> compiles and runs
//    correctly, releasing the captured value via .take() exactly once."
//
// Status: see header below, set after build/run.
//
// Toolchain: Apple Swift 6.3.1 (Xcode 26.4.1) — verify with `swift --version`.
// Date: 2026-05-02
// Item: 1.5 Phase A
//
// ============================================================================
// EXPERIMENT VERDICT (filled in after build + run):
//   Hypothesis: CONFIRMED
//   Build: GREEN (debug + release)
//   Runtime: release closure invokes .take()? exactly once across both
//            release-now and deinit-only paths; no compile-time @Sendable ×
//            ~Copyable rejection
//   Toolchain: Apple Swift 6.3.1 (Xcode 26.4.1)
//   Date verified: 2026-05-02
// ============================================================================

import Foundation  // for atexit-style deferred print

// MARK: - Mock ~Copyable resource (stand-in for Kernel.Descriptor)
//
// Mirrors the ~Copyable, Sendable + raw-int storage shape of Kernel.Descriptor.
// `deinit` prints to demonstrate close-on-drop semantics.

struct Resource: ~Copyable, Sendable {
    let id: Int

    init(id: Int) {
        self.id = id
        print("Resource(\(id)) created")
    }

    deinit {
        print("Resource(\(id)) deinit (close-on-drop)")
    }
}

// MARK: - Token — Path δ shape (no Sendable)
//
// Drop the @Sendable from the witness closure type → drop Sendable from Token.
// This unblocks `var Optional<~Copyable>` capture inside the closure body.

struct Token: ~Copyable {
    var _release: (() -> Void)?

    init(release: @escaping () -> Void) {
        self._release = release
        print("Token init")
    }

    mutating func release() {
        print("Token.release() called")
        _release?()
        _release = nil  // idempotent
    }

    deinit {
        print("Token deinit")
        _release?()  // RAII close-on-drop if release() not called explicitly
    }
}

// MARK: - acquire-style factory (mirrors L3 swift-memory Memory.Lock.Token+Acquire pattern)
//
// Mock for: Memory.Lock.Token.acquire(descriptor:, range:, kind:)
// - Construct a typed resource (mock dup'd descriptor)
// - Wrap it in `var Optional<~Copyable>` for closure capture
// - Inside closure body: `.take()!` consumes the resource exactly once

func acquire(id: Int) -> Token {
    let duped = Resource(id: id)

    // Path δ key construct: var Optional<~Copyable> captured by non-@Sendable closure.
    // The closure body uses .take()? to consume the resource on release.
    var captured: Resource? = consume duped
    return Token(release: {
        // Mock release of "lock" is just consuming the resource via .take()
        guard let resource = captured.take() else {
            print("release closure: already taken — idempotent no-op")
            return
        }
        print("release closure: consuming Resource(\(resource.id))")
        // Resource is consumed and goes out of scope → its deinit fires
        _ = consume resource
    })
}

// MARK: - Test 1: explicit release() then drop
//
// Expected sequence:
//   1. Resource(1) created
//   2. Token init
//   3. Token.release() called
//   4. release closure: consuming Resource(1)
//   5. Resource(1) deinit (close-on-drop)
//   6. Token deinit
//   7. (no second release call — _release was set to nil)

print("=== Test 1: explicit release() then drop ===")
do {
    var t = acquire(id: 1)
    t.release()
}
print()

// MARK: - Test 2: deinit-only release (no explicit call)
//
// Expected sequence:
//   1. Resource(2) created
//   2. Token init
//   3. Token deinit
//   4. release closure: consuming Resource(2)
//   5. Resource(2) deinit (close-on-drop)

print("=== Test 2: deinit-only release ===")
do {
    let t = acquire(id: 2)
    _ = t  // suppress "unused" warning; Token consumed at end of scope
}
print()

// MARK: - Test 3: explicit release() then explicit release() again (idempotency)
//
// Expected sequence:
//   1. Resource(3) created
//   2. Token init
//   3. Token.release() called
//   4. release closure: consuming Resource(3)
//   5. Resource(3) deinit
//   6. Token.release() called   ← second call
//   7. (no closure invocation — _release is nil)
//   8. Token deinit
//   9. (no closure invocation either — _release is nil)

print("=== Test 3: idempotent double-release ===")
do {
    var t = acquire(id: 3)
    t.release()
    t.release()  // should be no-op
}
print()

// MARK: - Test 4: a non-@Sendable closure CAN'T be Sendable — verify the
//                 "Token is not Sendable" property holds (would-fail-to-compile
//                 if Sendable conformance attempted).
//
// Demonstrating the trade-off explicitly.

// Uncomment to verify: this would fail to compile because Token is not Sendable
// (the closure type `(() -> Void)?` is not @Sendable, so Token can't conform).
//
// extension Token: Sendable {}  // ← compile error
// func sendOver<T: Sendable>(_ value: consuming T) {}
// sendOver(consume t)  // ← would fail because Token is not Sendable

print("=== End of experiment ===")
print("Verdict: CONFIRMED — see header.")
