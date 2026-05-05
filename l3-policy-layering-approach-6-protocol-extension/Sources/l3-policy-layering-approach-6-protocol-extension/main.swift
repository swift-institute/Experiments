// MARK: - Approach 6: Protocol Extension
// Purpose: Test whether protocol-extension dispatch can express L3-policy
//          while preserving consumer call shape `Foo.method()`.
// Hypothesis: Protocol extensions do NOT shadow type-extension methods of
//             the same name. To express policy via protocol, the protocol
//             must declare a DIFFERENT method name (e.g., makeWithPolicy)
//             — which violates criterion (5) "no consumer change".
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: PARTIAL — works mechanically, fails criterion (5)
// Date: 2026-05-02
//
// Build: clean (no warnings)
// Runtime output:
//   Foo.make() (type extension, L2) = L2
//   Foo.makeWithPolicy() (protocol extension, L3) = L3-protocol(L2)
//   Type identity preserved: L3-protocol(L2)
// Exit: 0
//
// Criterion matrix:
//  (1) Type identity:        PASS — Foo flows through L1 unchanged
//  (2) L3-policy resolution: N/A — call shape changed; consumer writes
//                            Foo.makeWithPolicy() to opt into L3, not Foo.make()
//  (3) Type instantiation:   PASS
//  (4) NO @_spi:             PASS
//  (5) NO consumer change:   FAIL — consumer must call makeWithPolicy()
//  (6) Compiles cleanly:     PASS
//
// Critical observation: protocol extensions DO NOT shadow type extensions
// of the same method name. We tried defining `protocol FooPolicy {
// static func makeWithPolicy() ... }` because had we used `make()` the
// protocol-extension default would conflict with Foo's type-extension `make()`
// at dispatch — Swift dispatches to the concrete type method, not the
// protocol extension default, when both are visible. Protocol-extension
// defaults are LATE-RESOLUTION fallbacks; type-extension methods take
// priority. So the protocol approach can only deliver L3 policy via a
// DIFFERENT method name. Equivalent to approach 5 in trade-off: criterion
// (5) violated.

import L3Policy

let l2 = try Foo.make()
print("Foo.make() (type extension, L2) = \(l2.tag)")

let l3 = try Foo.makeWithPolicy()
print("Foo.makeWithPolicy() (protocol extension, L3) = \(l3.tag)")

let typed: Foo = l3
print("Type identity preserved: \(typed.tag)")
