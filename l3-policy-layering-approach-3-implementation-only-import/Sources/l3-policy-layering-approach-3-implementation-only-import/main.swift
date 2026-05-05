// MARK: - Approach 3: @_implementationOnly import
// Purpose: Test the @_implementationOnly variant (deprecated in favor of
//          `internal import`, but historically used for this purpose).
//          The hypothesis: @_implementationOnly hides L2 from consumers
//          completely, even from interface stability — strictly stronger
//          than `internal import`.
// Hypothesis: Same result as approach 2 — L2 hidden from consumers, but
//             same-signature L3 extension recurses inside L3's body.
//             @_implementationOnly is a stricter form of `internal import`,
//             so it inherits all the same behavioral characteristics for
//             our case.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: REFUTED — same recursion + deprecated mechanism
// Date: 2026-05-02
//
// Build: TWO warnings:
//   1. infinite recursion at L3Policy/Foo+policy.swift:8 (same defect)
//   2. @_implementationOnly is DEPRECATED (Swift 5.9+); diagnostic ID
//      [#ImplementationOnlyDeprecated]. Compiler instructs use of
//      `internal import` instead.
// Runtime: SIGSEGV (exit 139) — stack overflow.
//
// What it rules out: @_implementationOnly is the older, stricter form of
// what `internal import` provides. Swift 5.9+ deprecates it in favor of
// `internal import`. Behaviorally identical to approach 1 / approach 2
// for our case — L2's methods are visible inside L3 (via the import) but
// not re-exported, so L3's body still sees both candidates and recurses.
// This approach is doubly disqualified: same defect AS approach 8 PLUS a
// deprecated mechanism that the compiler steers away from.

import L3Policy

let result = try Foo.make()
print("Foo.make() returned tag = \(result.tag)")

let typed: Foo = result
print("Type identity preserved: \(typed.tag)")
