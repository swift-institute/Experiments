// MARK: - Resumption ~Copyable + ~Escapable Experiment
// Purpose: Validate that Async.Waiter.Resumption can become ~Copyable + ~Escapable
// Toolchain: Apple Swift 6.2.4
// Platform: macOS 26.0 (arm64)
// Date: 2026-03-02
//
// Result: All 7 variants CONFIRMED — pattern works in isolation.
//
// PRODUCTION STATUS: REVERTED. The ~Escapable was temporarily applied to
// Async.Waiter.Resumption but reverted because swift-cache-primitives and
// swift-pool-primitives collect Resumptions into [Async.Waiter.Resumption]
// (Swift.Array / Array_Primitives) for batch-resume-outside-lock patterns.
// Dynamic arrays are heap-backed and require Element: Escapable (confirmed
// blocker #1 from nonescapable-storage-mechanisms.md research).
//
// LESSON (EXP-011): Minimal experiments validate that a pattern works.
// They CANNOT validate that a workaround works at scale. The 5 swift-io
// call sites all use single-inline-consume, but cache/pool use batch-collect.
// The full dependency graph must be verified before production deployment.

// ============================================================================
// V1: Basic ~Copyable + ~Escapable + Sendable struct with @_lifetime(immortal)
// Mirrors: Async.Waiter.Resumption struct declaration
// ============================================================================

struct Resumption: ~Copyable, ~Escapable, Sendable {
    @usableFromInline
    let _resume: @Sendable () -> Void

    @_lifetime(immortal)
    @inlinable
    init(_ action: @escaping @Sendable () -> Void) {
        self._resume = action
    }

    @inlinable
    consuming func resume() {
        _resume()
    }
}

func testV1() {
    print("=== V1: Basic ~Copyable + ~Escapable + Sendable ===")
    let r = Resumption { print("  V1: resumed") }
    r.resume()
    print("  RESULT: compiles and executes")
}

// ============================================================================
// V2: Optional<Resumption> (mirrors resumeNext() -> Resumption?)
// Mirrors: IO.Handle.Waiters.resumeNext() -> Async.Waiter.Resumption?
// ============================================================================

@_lifetime(immortal)
func makeOptional() -> Resumption? {
    Resumption { print("  V2: resumed from optional") }
}

func testV2() {
    print("\n=== V2: Optional<Resumption> ===")
    let maybeR = makeOptional()
    if let r = maybeR {
        r.resume()
    }
    print("  RESULT: Optional<~Copyable + ~Escapable> works")
}

// ============================================================================
// V3: Consuming parent creates and returns Resumption
// Mirrors: Entry.resumption(with:) -> Async.Waiter.Resumption
// ============================================================================

struct Entry: ~Copyable, Sendable {
    let value: Int

    @_lifetime(immortal)
    consuming func resumption() -> Resumption {
        let v = self.value
        _ = consume self
        return Resumption { print("  V3: resumed with value \(v)") }
    }
}

func testV3() {
    print("\n=== V3: Consuming parent returns Resumption ===")
    let entry = Entry(value: 42)
    let r = entry.resumption()
    r.resume()
    print("  RESULT: consuming func returning ~Escapable works")
}

// ============================================================================
// V4: Resumption created and consumed inside closure body
// Mirrors: drainAll { entry in entry.resumption(with: ()).resume() }
// [IMPL-EXPR-001] / [IMPL-030]: single-expression chain
// ============================================================================

func drainPattern() {
    print("\n=== V4: Inline create + consume in closure ===")
    for i in 1...3 {
        let entry = Entry(value: i)
        entry.resumption().resume()  // single-expression chain per [IMPL-030]
    }
    print("  RESULT: inline chain compiles and executes")
}

// ============================================================================
// V5: Let-binding then consuming call
// Mirrors: let resumption = entry.resumption(with: ()); resumption.resume()
// ============================================================================

func letBindPattern() {
    print("\n=== V5: Let-bind then consume ===")
    let entry = Entry(value: 99)
    let resumption = entry.resumption()
    resumption.resume()
    print("  RESULT: let-bind + consume works")
}

// ============================================================================
// V6: Resumption inside drain closure (consuming closure parameter)
// Mirrors: flagged.drain { entry, reason in entry.resumption(with: ...).resume() }
// ============================================================================

func closureDrainPattern(_ body: (consuming Entry) -> Void) {
    body(Entry(value: 77))
}

func testV6() {
    print("\n=== V6: Consuming closure parameter ===")
    closureDrainPattern { entry in
        entry.resumption().resume()  // single-expression chain per [IMPL-030]
    }
    print("  RESULT: consuming closure parameter works")
}

// ============================================================================
// V7: Optional binding — if let r = resumeNext() { r.resume() }
// Mirrors: IO.Handle.Waiters pattern
// ============================================================================

func testV7() {
    print("\n=== V7: Optional binding ===")
    if let r = makeOptional() {
        r.resume()
    }

    // Also test nil case
    let nilCase: Resumption? = nil
    if let r = nilCase {
        r.resume()
    } else {
        print("  V7: nil case handled correctly")
    }
    print("  RESULT: optional binding works")
}

// ============================================================================
// Run all variants
// ============================================================================

testV1()
testV2()
testV3()
drainPattern()
letBindPattern()
testV6()
testV7()

print("\n=== SUMMARY ===")
print("V1: Basic ~Copyable + ~Escapable + Sendable struct     — PASS")
print("V2: Optional<Resumption>                                — PASS")
print("V3: Consuming parent returns Resumption                 — PASS")
print("V4: Inline create + consume in closure                  — PASS")
print("V5: Let-bind then consume                               — PASS")
print("V6: Consuming closure parameter                         — PASS")
print("V7: Optional binding                                    — PASS")
print("\nAll 7 variants compile and execute on Swift 6.2.4.")
print("Resumption can safely become ~Copyable + ~Escapable + Sendable.")
