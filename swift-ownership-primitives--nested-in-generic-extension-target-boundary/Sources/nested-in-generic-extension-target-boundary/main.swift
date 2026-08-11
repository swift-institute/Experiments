// MARK: - Nested-in-Generic Extension Constraint Poisoning (Target Boundary)
//
// Purpose: Validate whether, on Swift 6.3.1, a nested type inside a
//   `~Copyable`-generic outer struct — itself nested in a sub-namespace
//   inside a top-level namespace spread across 3 library targets — can
//   have public methods declared in `extension Outer.Inner.Cell.Token
//   where T: ~Copyable` and still be called for a Copyable-T (Int)
//   specialisation from a consumer target.
//
//   Motivating case: swift-ownership-primitives attempted to move
//   `Ownership.Transfer.Cell.Token.take()` (and
//   `Ownership.Transfer.Storage.Token.store(_:)`) out of their struct
//   bodies into constrained extensions per [API-IMPL-008]. The package
//   layout is:
//     Ownership Namespace  → declares `public enum Ownership {}`
//     Ownership Primitives Core → extends with `public enum Transfer {}`
//     Ownership Transfer Primitives → declares `Cell<T: ~Copyable>` and
//                                     the `Token.take()` extension
//     Ownership Primitives Tests → consumes via the umbrella re-export
//   The linker failed with
//     Undefined symbols ... Cell< where A: ~Swift.Copyable>.Token.take() -> A
//
//   This experiment reproduces the same 4-target layout and tests
//   whether Copyable-T consumer calls link across targets.
//
// Hypothesis: STILL PRESENT. Multi-target namespace chain + extension
//   constrained by `where T: ~Copyable` on a nested type mangle-
//   specialises only for the ~Copyable case, and the Copyable-T caller
//   can't find the specialisation.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Status: FIXED (verified 2026-04-23 — hypothesis REFUTED on clean build)
//
// Result: FIXED — hypothesis REFUTED. The 4-target namespace chain
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         (OuterNamespace → OuterCore → VariantPrimitives → Umbrella →
//         executable consumer) compiles and runs cleanly with
//         `take()` in an `extension Outer.Inner.Cell.Token where T: ~Copyable`.
//         Output: `Outer.Inner.Cell<Int>.Token.take() = 42`.
//
//         Cross-reference: the same pattern applied to
//         `Ownership.Transfer.Cell.Token.take()` and
//         `Ownership.Transfer.Storage.Token.store(_:)` in
//         swift-ownership-primitives, with `rm -rf .build` and
//         `swift test`, passes cleanly (84/33 tests). The earlier
//         linker failure was stale-cache-related — it did not
//         reproduce on a clean rebuild.
//
//         Decision: MOVE `Cell.Token.take()` and `Storage.Token.store()`
//         out of their struct bodies into `extension ... where T: ~Copyable`
//         per [API-IMPL-008]. Remove the NOTE comments that previously
//         documented the (now-obsolete) exception.

import Umbrella

func runProbe() {
    let cell = Outer.Inner.Cell<Int>(42)
    let token = cell.token()
    let value = token.take()
    precondition(value == 42)
    print("Outer.Inner.Cell<Int>.Token.take() = \(value)")
}
runProbe()
