// MARK: - Approach 9: L2 Sub-Namespace (Foo.Syscall.make() at L2)
// Purpose: Eliminate the same-signature L2/L3 collision by giving L2 a
//          DIFFERENT call path — `Foo.Syscall.make()` — so L3 can declare
//          `Foo.make()` directly without conflict. Variant of [PLAT-ARCH-008e]
//          Phase A rename pattern, applied via sub-namespace nesting rather
//          than method renaming.
// Hypothesis: With L2 at Foo.Syscall and L3 at Foo, no overload-resolution
//             collision exists. L3's body call `Foo.Syscall.make()` resolves
//             cleanly to L2 (no L3 declaration at that path). Consumer's
//             Foo.make() resolves cleanly to L3 (no L2 declaration at that
//             path). All six criteria satisfiable.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — passes ALL six criteria
// Date: 2026-05-02
//
// Build: clean (no warnings)
// Runtime output:
//   Foo.make() = L3(L2.Syscall)
//   Foo.Syscall.make() = L2.Syscall
//   Type identity preserved: L3(L2.Syscall)
// Exit: 0
//
// Criterion matrix:
//  (1) Type identity:        PASS — Foo declared at L1, flows unchanged to consumer
//  (2) L3-policy resolution: PASS — Foo.make() routes to L3's wrapper, which
//                            successfully delegates to Foo.Syscall.make()
//                            (output "L3(L2.Syscall)" proves wrap-and-delegate)
//  (3) Type instantiation:   PASS
//  (4) NO @_spi:             PASS — zero @_spi attributes; grep confirms
//  (5) NO consumer change:   PASS — consumer call shape `Foo.make()` is
//                            IDENTICAL to single-module form. Consumer code
//                            requires no migration. Power-user access to raw
//                            L2 form is at `Foo.Syscall.make()` — equivalent
//                            in spirit to @_spi(Syscall) but via namespace
//                            nesting rather than visibility attribute.
//  (6) Compiles cleanly:     PASS — no warnings, no ambiguity
//
// Mechanism: L2 declares its method at `Foo.Syscall.make()` (sub-namespace
// nested inside Foo). L3 declares its user-facing method at `Foo.make()`
// directly. The two declarations occupy DIFFERENT namespace paths:
//   • Foo.Syscall.make() — only L2 declares here
//   • Foo.make() — only L3 declares here
// No same-signature collision; Swift overload resolution is unambiguous.
// L3's body calls `Foo.Syscall.make()` to delegate — resolves cleanly to L2.
//
// Architectural alignment: This is structurally a variant of [PLAT-ARCH-008e]
// Phase A rename. Phase A renames L2's method (e.g., `flush` → `fsync`) to
// free the user-facing name for L3. Approach 9 sub-namespaces L2's method
// (e.g., `make` → `Syscall.make`) — same goal (eliminate name collision),
// different mechanism. Sub-namespace is preferred when:
//   • The L2 method's name is already spec-literal (can't be renamed without
//     violating [API-NAME-003] specification-mirroring)
//   • Multiple L2 methods need the same de-collision treatment
//     (a single sub-namespace handles them all uniformly)
//   • The team wants a single mechanical rule applied uniformly across the
//     four corrective namespaces (Stats, Open, Memory.Map, Time) without
//     case-by-case Phase A rename decisions
//
// What it confirms: There IS a Swift layering pattern that achieves all
// three goals from the handoff (type identity preserved, L3-policy method
// wrapping, NO @_spi at L2). The pattern is NAMESPACE-based, not import-
// attribute-based — placing L2's typed forms at a sub-namespace under the
// type sidesteps overload resolution entirely.

import L3Policy

// Consumer call: Foo.make() — resolves to L3 (the only declaration at Foo.make())
let l3 = try Foo.make()
print("Foo.make() = \(l3.tag)")

// Power-user call: Foo.Syscall.make() — bypasses L3 policy (== @_spi access)
let l2 = try Foo.Syscall.make()
print("Foo.Syscall.make() = \(l2.tag)")

// Type identity check
let typed: Foo = l3
print("Type identity preserved: \(typed.tag)")
