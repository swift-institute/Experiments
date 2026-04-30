// MARK: - Optional+take sending vs Region Isolation
// Purpose: Reproduce and isolate the region isolation error on Optional.take()
//          returning `sending Wrapped?` from a mutating func.
// Hypothesis: The compiler's region isolation analysis cannot prove that a value
//             extracted from `consume self` in a mutating func is disconnected
//             from the caller's region, making `sending` return impossible.
//
// Toolchain: Linux swift:6.3, Linux swiftlang/swift:nightly-main (6.4-dev)
// Platform: Linux aarch64 (Docker)
//
// Context: Linux nightly (Swift 6.4-dev) produces:
//   Optional+take.swift:36:20: error: returning task-isolated 'value' as a
//   'sending' result risks causing data races [#RegionIsolation]
//   macOS (Swift 6.1/6.3) compiles without error.
//
// Result: CONFIRMED — 6.4-dev nightly regression. All variants compile on macOS
//         6.1 and Linux 6.3. On 6.4-dev nightly, every non-Sendable variant
//         with `sending` return fails with #RegionIsolation. Only Sendable-
//         constrained or non-sending variants survive.
//
// Toolchain matrix:
//   macOS 6.1 (Apple Swift 6.1):    all variants PASS (V6 fails — separate issue)
//   Linux 6.3 (swift:6.3):          all variants PASS
//   Linux 6.4-dev nightly:          V1,V3,V4,V7,V8 FAIL — V2,V5,V9 PASS
//
// Swift 6.4-dev: REGRESSED — 6.3 remains stable
//
// Date: 2026-04-09

// MARK: - Shared ~Copyable type for all variants

struct Resource: ~Copyable {
    let id: Int
}

// =============================================================================
// MARK: - V1: Exact reproduction of Optional+take.swift
// Hypothesis: This is the pattern that fails on Linux nightly.
// Result: CONFIRMED — 6.3 PASS, 6.4-dev FAIL
//   error: returning task-isolated 'value' as a 'sending' result risks causing
//   data races [#RegionIsolation]

extension Optional where Wrapped: ~Copyable {
    @inlinable
    mutating func take_v1() -> sending Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            return value
        case .none:
            self = nil
            return nil
        }
    }
}

// =============================================================================
// MARK: - V2: Baseline — same pattern WITHOUT sending
// Hypothesis: Without `sending`, the pattern compiles fine.
// Result: CONFIRMED — 6.3 PASS, 6.4-dev PASS (no sending = no region check)

extension Optional where Wrapped: ~Copyable {
    @inlinable
    mutating func take_v2() -> Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            return value
        case .none:
            self = nil
            return nil
        }
    }
}

// =============================================================================
// MARK: - V3: sending + `consume value` on return
// Hypothesis: Explicit `consume` on the return expression might help the
//             region analysis prove disconnection.
// Result: REFUTED — 6.3 PASS, 6.4-dev FAIL
//   `consume` is about ownership, not regions. Doesn't help.

extension Optional where Wrapped: ~Copyable {
    @inlinable
    mutating func take_v3() -> sending Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            return consume value
        case .none:
            self = nil
            return nil
        }
    }
}

// =============================================================================
// MARK: - V4: sending + return consumed self directly (no pattern match)
// Hypothesis: Avoiding the pattern match eliminates the intermediate binding
//             that the compiler flags as task-isolated.
// Result: REFUTED — 6.3 PASS, 6.4-dev FAIL
//   The issue is the region of self, not the pattern match binding.

extension Optional where Wrapped: ~Copyable {
    @inlinable
    mutating func take_v4() -> sending Wrapped? {
        let result = consume self
        self = nil
        return result
    }
}

// =============================================================================
// MARK: - V5: sending + Sendable constraint
// Hypothesis: Adding Wrapped: Sendable makes region analysis trivial — Sendable
//             types can always cross regions.
// Result: CONFIRMED — 6.3 PASS, 6.4-dev PASS
//   Sendable types bypass region isolation checks entirely.

extension Optional where Wrapped: ~Copyable & Sendable {
    @inlinable
    mutating func take_v5() -> sending Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            return value
        case .none:
            self = nil
            return nil
        }
    }
}

// =============================================================================
// MARK: - V6: consuming func instead of mutating
// Hypothesis: With `consuming`, self is not inout — the value is moved entirely,
//             breaking the region connection to the caller.
// Note: This changes semantics — caller loses access to the variable entirely
//       rather than seeing nil.
// Result: REFUTED on macOS 6.1 — same region isolation error:
//   "returning a task-isolated 'Optional<Wrapped>' value as a 'sending' result"
//   Even consuming doesn't disconnect from the caller's region.

// extension Optional where Wrapped: ~Copyable {
//     @inlinable
//     consuming func take_v6() -> sending Wrapped? {
//         return consume self
//     }
// }

// =============================================================================
// MARK: - V7: sending + unsafe expression on return
// Hypothesis: `unsafe` suppresses safety checks and may suppress region isolation.
// Result: REFUTED — 6.3 PASS (warning: no unsafe ops), 6.4-dev FAIL
//   `unsafe` suppresses memory safety, not concurrency/region checks.

extension Optional where Wrapped: ~Copyable {
    @inlinable
    mutating func take_v7() -> sending Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            return unsafe value
        case .none:
            self = nil
            return nil
        }
    }
}

// =============================================================================
// MARK: - V8: nonisolated mutating func
// Hypothesis: nonisolated removes the function from any actor isolation,
//             which might affect region analysis.
// Result: REFUTED — 6.3 PASS, 6.4-dev FAIL
//   nonisolated doesn't affect region analysis for value types.

extension Optional where Wrapped: ~Copyable {
    @inlinable
    nonisolated mutating func take_v8() -> sending Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            return value
        case .none:
            self = nil
            return nil
        }
    }
}

// =============================================================================
// MARK: - V9: Two overloads — Sendable gets sending, non-Sendable does not
// Hypothesis: Split the API: Sendable types get `sending` return (safe),
//             non-Sendable types get plain return (correct but less flexible).
// Result: CONFIRMED — 6.3 PASS, 6.4-dev PASS (both overloads compile)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

extension Optional where Wrapped: ~Copyable & Sendable {
    @inlinable
    mutating func take_v9_sendable() -> sending Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            return value
        case .none:
            self = nil
            return nil
        }
    }
}

extension Optional where Wrapped: ~Copyable {
    @inlinable
    mutating func take_v9_general() -> Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            return value
        case .none:
            self = nil
            return nil
        }
    }
}

// =============================================================================
// MARK: - Helpers

func describe(_ r: consuming Resource?) -> String {
    switch consume r {
    case .some(let v): return "Resource(\(v.id))"
    case .none: return "nil"
    }
}

// =============================================================================
// MARK: - Exercise

func exercise() {
    // V1: Exact reproduction
    var r1: Resource? = Resource(id: 1)
    print("V1 (exact repro):      \(describe(r1.take_v1()))")

    // V2: No sending
    var r2: Resource? = Resource(id: 2)
    print("V2 (no sending):       \(describe(r2.take_v2()))")

    // V3: consume value
    var r3: Resource? = Resource(id: 3)
    print("V3 (consume value):    \(describe(r3.take_v3()))")

    // V4: No pattern match
    var r4: Resource? = Resource(id: 4)
    print("V4 (no pattern match): \(describe(r4.take_v4()))")

    // V5: Sendable constraint (uses Int, which is Sendable)
    var i5: Int? = 5
    let v5 = i5.take_v5()
    print("V5 (Sendable):         \(v5.map { "\($0)" } ?? "nil")")

    // V6: consuming func — REFUTED on macOS, commented out

    // V7: unsafe
    var r7: Resource? = Resource(id: 7)
    print("V7 (unsafe):           \(describe(r7.take_v7()))")

    // V8: nonisolated
    var r8: Resource? = Resource(id: 8)
    print("V8 (nonisolated):      \(describe(r8.take_v8()))")

    // V9: Split overloads
    var r9: Resource? = Resource(id: 9)
    print("V9 (general):          \(describe(r9.take_v9_general()))")

    var i9: Int? = 9
    let v9s = i9.take_v9_sendable()
    print("V9 (sendable):         \(v9s.map { "\($0)" } ?? "nil")")
}

exercise()

// MARK: - Results Summary
//
//                          6.3 Linux    6.4-dev Linux
// V1 (exact repro):       PASS         FAIL #RegionIsolation
// V2 (no sending):        PASS         PASS
// V3 (consume value):     PASS         FAIL #RegionIsolation
// V4 (no pattern match):  PASS         FAIL #RegionIsolation
// V5 (Sendable):          PASS         PASS
// V6 (consuming func):    PASS         not tested (fails macOS 6.1 already)
// V7 (unsafe):            PASS         FAIL #RegionIsolation
// V8 (nonisolated):       PASS         FAIL #RegionIsolation
// V9 (split overloads):   PASS         PASS
//
// Conclusion: This is a Swift 6.4-dev nightly regression in #RegionIsolation.
// The compiler can no longer prove that a value extracted from `consume self`
// in a mutating func is disconnected from the caller's region when Wrapped
// is non-Sendable. Adding `Wrapped: Sendable` constraint (V5) or splitting
// into Sendable/non-Sendable overloads (V9) are the only viable workarounds
// that preserve the `sending` return for Sendable types.
