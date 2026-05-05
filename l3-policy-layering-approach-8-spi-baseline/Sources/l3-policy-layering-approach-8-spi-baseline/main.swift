// MARK: - Approach 8: @_spi(Syscall) Baseline (Wave 3.5-Corrective pattern)
// Purpose: Verify that the existing Wave 3.5-Corrective "@_spi(Syscall) at L2 +
//          cross-module same-signature L3 extension" pattern works in minimal form.
// Hypothesis: Consumer sees L3's make(), type identity preserved, L3 internally
//             reaches L2's SPI form for delegation.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: REFUTED — pattern is structurally broken at criterion (2) AND (6)
// Date: 2026-05-02
//
// Build output: warning at L3Policy/Foo+policy.swift:5:
//   "function call causes an infinite recursion"
//
// Runtime: SIGSEGV (exit 139). Within L3Policy's module, the call
//   `try Foo.make()` overload-resolves to L3Policy's OWN local extension
//   declaration (same-signature, same nominal type), not to L2Methods's
//   @_spi(Syscall) declaration. Result: infinite self-recursion → stack
//   overflow → segmentation fault.
//
// CRITICAL — Production verification:
//   /Users/coen/Developer/swift-foundations/swift-posix/Sources/POSIX
//   Kernel File/POSIX.Kernel.File.Open.swift:97 EXHIBITS THE SAME
//   WARNING under clean build. The Wave 3.5-Corrective-2 commit `d8c5877`
//   landed broken delegation; the Stats analogue (commit `0c3545a`,
//   pure-passthrough variant) likely shares the defect but with simpler
//   structure (no retry loop). Tests likely don't exercise the policy
//   path at runtime, hiding the regression.
//
// What it rules out: The "@_spi(Syscall) at L2 + same-signature L3
//   cross-module extension" disambiguation does NOT route the L3 body's
//   self-call through the L2 SPI declaration. @_spi affects consumer-facing
//   visibility (consumer without @_spi import doesn't see L2 method) but
//   does NOT affect overload resolution within L3's module — both
//   declarations are equally-ranked candidates and Swift prefers the
//   local declaration, producing infinite recursion.

import L3Policy

let result = try Foo.make()
print("Foo.make() returned tag = \(result.tag)")

// Type identity check (compile-time): Foo from L3 must be the same type as Foo from L1
let typed: Foo = result
print("Type identity preserved: \(typed.tag)")

// Validation:
// - If output is "L3(L2)" → criterion (2) PASSED (L3 wraps L2)
// - If output is "L2" → criterion (2) FAILED (L3 not selected)
// - If compile-time error → criterion (6) FAILED (ambiguity)
