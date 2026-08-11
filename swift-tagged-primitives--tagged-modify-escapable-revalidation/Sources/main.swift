// MARK: - Tagged.modify with ~Escapable RawValue Revalidation
// Purpose:  Verify whether `package mutating func modify(_:)` on Tagged
//           can be widened to `RawValue: ~Copyable & ~Escapable` on
//           Swift 6.3.1, or whether the documented "closure-parameter
//           -lifetime gap for ~Escapable types" still blocks it.
// Hypothesis: Declaring `modify` with `RawValue: ~Copyable & ~Escapable`
//             and `inout RawValue` closure parameter fails to compile on
//             Swift 6.3.1. If it compiles, the workaround in Tagged.swift
//             lines 49-54 can be removed.
//
// Toolchain: Apple Swift 6.3.1 (Xcode 26.4.1 default; swiftlang-6.3.1.1.2)
// Platform:  macOS 26.0 (arm64)
// Date:      2026-04-24
//
// Result: FIXED — the minimal Variant 2 (~Escapable RawValue + inout closure)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         compiles and runs. The production `modify` extension in
//         Tagged.swift was widened accordingly in commit following this
//         experiment. 59/59 tagged-primitives tests continue to pass.
//
// Evidence (swift run output):
//   modifyEscapable result: 42
//   modifyAny result: 99
//   VERDICT: FIXED on Swift 6.3.1 — modifyAny (~Escapable RawValue) compiles

// ============================================================================
// MARK: - Minimal Tagged (mirroring tagged-primitives' shape)
// ============================================================================

@frozen
public struct Tagged<Tag: ~Copyable & ~Escapable, RawValue: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    public var rawValue: RawValue

    @inlinable
    @_lifetime(copy rawValue)
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

extension Tagged: Copyable where Tag: ~Copyable & ~Escapable, RawValue: Copyable & ~Escapable {}
extension Tagged: Escapable where Tag: ~Copyable & ~Escapable, RawValue: Escapable & ~Copyable {}

// ============================================================================
// MARK: - Variant 1 (Control): Escapable RawValue — the production scope
// ============================================================================
//
// This is the current Tagged.swift scope. Should compile unconditionally.

extension Tagged where Tag: ~Copyable & ~Escapable, RawValue: ~Copyable {
    @inlinable
    package mutating func modifyEscapable<T>(_ body: (_ rawValue: inout RawValue) -> T) -> T {
        body(&self.rawValue)
    }
}

// ============================================================================
// MARK: - Variant 2 (Test): ~Escapable RawValue — the widened scope
// ============================================================================
//
// The widened form. The comment in Tagged.swift lines 49-54 claims this
// hits a "closure-parameter-lifetime gap for ~Escapable types" on 6.3.
// If this compiles on 6.3.1, the claim is FIXED.

extension Tagged where Tag: ~Copyable & ~Escapable, RawValue: ~Copyable & ~Escapable {
    @inlinable
    package mutating func modifyAny<T>(_ body: (_ rawValue: inout RawValue) -> T) -> T {
        body(&self.rawValue)
    }
}

// ============================================================================
// MARK: - Smoke test
// ============================================================================

private enum TagA {}

private var t = Tagged<TagA, Int>(__unchecked: (), 0)
private let result = t.modifyEscapable { value in
    value = 42
    return value
}
print("modifyEscapable result: \(result)")

private let result2 = t.modifyAny { value in
    value = 99
    return value
}
print("modifyAny result: \(result2)")

// If we reach this line, both variants compiled — claim is FIXED.
print("VERDICT: FIXED on Swift 6.3.1 — modifyAny (~Escapable RawValue) compiles")
