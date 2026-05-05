// MARK: - Approach 2: Types-Only Module Split at L2
// Purpose: Split L2 into "L2Types" (struct only) + "L2Methods" (typed methods
//          via cross-module extension). L3 publicly re-exports L2Types so
//          consumers see Foo, but internally imports L2Methods so consumers
//          don't see L2's make(). Then L3 declares its own make() with policy.
// Hypothesis: The split addresses consumer-side visibility. But within L3's
//             module body, L2Methods's extension on Foo IS visible (via
//             internal import) — so L3's body call `Foo.make()` may still
//             face same-signature ambiguity → recursion.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: PARTIAL — consumer-side visibility works, but L3-body recursion remains
// Date: 2026-05-02
//
// Build: warning at L3Policy/Foo+policy.swift:8 — "function call causes an
//        infinite recursion" (same defect as approach 8).
// Runtime: SIGSEGV (exit 139) — stack overflow.
//
// Notable consumer-side observations:
//   • Consumer's `import L3Policy` brings in Foo via L3's @_exported import
//     of L2Types. ✓ Type identity preserved.
//   • Consumer cannot see L2Methods's make() because L3 internally imports it.
//     ✓ Consumer-side criterion (2) works at resolution stage.
//   • Compiler emits the recursion warning because L2Methods's make() is
//     visible *inside* L3 (via the internal import) — L3's body still has
//     two same-signature candidates and prefers its local one.
//
// What it rules out: The types-only module split addresses CONSUMER-side
// visibility correctly. Consumers don't see the L2 method. But the
// L3-internal delegation still fails for the same reason as approach 8:
// inside L3's module, both L2's and L3's same-signature extensions are
// candidates, and Swift picks the local. The split doesn't change overload
// resolution within L3.
//
// Architectural conclusion: the split is necessary if you want to hide L2's
// methods from consumers without @_spi, but it is NOT sufficient for the
// L3-delegates-to-L2 case. Combining the split with a different L3-internal
// dispatch mechanism (e.g., a bridge sub-target whose module-scope doesn't
// see L3's local extension) might compose to a working solution — see
// approach 9 (L2 sub-namespace) which closes the gap by giving L2 a
// non-collision call shape (`Foo.Syscall.make()`).

import L3Policy

let result = try Foo.make()
print("Foo.make() returned tag = \(result.tag)")

let typed: Foo = result
print("Type identity preserved: \(typed.tag)")
