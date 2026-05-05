// MARK: - Approach 4: @_disfavoredOverload at L2
// Purpose: Test whether @_disfavoredOverload on L2's same-signature method
//          lets L3's local declaration win in overload resolution AND lets
//          L3's body call resolve to L2 (instead of self-recursing).
// Hypothesis: Within L3's module, L3's local make() is non-disfavored;
//             L2's imported make() is disfavored. Swift prefers non-disfavored
//             → L3's body call `Foo.make()` resolves to LOCAL L3 (recursion).
//             Consumer-facing resolution: same problem — L3's local wins, but
//             that's actually the desired direction.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: REFUTED — @_disfavoredOverload does NOT disambiguate L3's body call
// Date: 2026-05-02
//
// Build: same "infinite recursion" warning at L3Policy/Foo+policy.swift:5
// Runtime: SIGSEGV (exit 139) — stack overflow from infinite self-recursion
//
// Behavior at consumer site (NOT exercised by main.swift recursion crash, but
// reasoned from Swift overload-resolution rules): consumer with both L2
// (disfavored) and L3 (preferred) visible → Swift selects L3's make().
// Criterion (2) passes at consumer site. BUT criterion (2) fails at delegation
// site — within L3's module, the call `try Foo.make()` resolves to L3's OWN
// local declaration (the non-disfavored one in scope), not to L2's
// disfavored imported declaration. Same infinite recursion as approach 8.
//
// What it rules out: @_disfavoredOverload addresses overload resolution
// PREFERENCE but does not change the fact that within L3's module, L3's
// own non-disfavored declaration is the closest candidate. The disfavored
// modifier helps consumers pick the right method but does not provide a
// disambiguation path for L3's body to reach L2.

import L3Policy

let result = try Foo.make()
print("Foo.make() returned tag = \(result.tag)")

let typed: Foo = result
print("Type identity preserved: \(typed.tag)")
