// MARK: - Approach 5: Sub-namespace at L3 (Foo.Policy.make())
// Purpose: L3-policy methods live at Foo.Policy.* sub-namespace, not on Foo
//          directly. Eliminates same-signature same-nominal-type collision.
// Hypothesis: Different sub-namespace at L3 means L3's body call to L2's
//             `Foo.make()` resolves cleanly (only L2's declaration in scope
//             at that path; L3's is at Foo.Policy.make()).
//
// Trade-off: Consumer migration required — call shape changes from
//            `Foo.make()` to `Foo.Policy.make()`. Violates criterion (5).
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: PARTIAL — passes criteria (1)(3)(4)(6), but criterion (5) FAILED
// Date: 2026-05-02
//
// Build: clean (no warnings)
// Runtime output:
//   Foo.make() (L2 direct) = L2
//   Foo.Policy.make() (L3 wrap) = L3.Policy(L2)
//   Type identity preserved: L3.Policy(L2)
// Exit: 0
//
// Criterion matrix:
//  (1) Type identity:       PASS — Foo from L1Defs flows through unchanged
//  (2) L3-policy resolution: N/A — call shape changed; consumer writes
//                            Foo.Policy.make() to opt into L3, not Foo.make()
//  (3) Type instantiation:  PASS — Foo() works
//  (4) NO @_spi:            PASS — zero @_spi attributes
//  (5) NO consumer change:  FAIL — consumers MUST migrate every Foo.make()
//                            to Foo.Policy.make() to opt into the policy.
//                            For the production case, this means ALL of
//                            Kernel.File.Stats.get(...), Kernel.File.Open.open(...),
//                            etc. become Kernel.File.Stats.Policy.get(...) etc.
//  (6) Compiles cleanly:    PASS — no warnings
//
// What it rules out: This approach mechanically WORKS but at the cost of
// a per-name consumer-cascade migration. For 4 corrective namespaces
// (Stats/Open/Memory.Map/Time) with an unknown number of call sites
// across swift-kernel, swift-memory, swift-file-system, this is non-trivial.
// Useful as a fallback if no criterion-(5)-respecting alternative exists.

import L3Policy

let l2Result = try Foo.make()
print("Foo.make() (L2 direct) = \(l2Result.tag)")

let l3Result = try Foo.Policy.make()
print("Foo.Policy.make() (L3 wrap) = \(l3Result.tag)")

let typed: Foo = l3Result
print("Type identity preserved: \(typed.tag)")
