# property-view-pair-attempt

Empirical verification of the `swift-pair-primitives/Research/property-primitives-api-design.md` (v1.1.0 DECISION) structural blockers for adopting property-primitives accessor namespaces (`pair.map.first { ... }`) on `Pair<First, Second>: ~Copyable`.

## Hypotheses Tested

| Variant | Hypothesis | Result | Primary Diagnostic |
|---------|------------|--------|--------------------|
| V1 — Property.Typed two-generic where-clause | A bare `Property.Typed<First>` extension can bind both `First` (= Element) and `Second` as free variables in its where-clause | **REFUTED** | `error: cannot find type 'Second' in scope` |
| V2 — PairLike protocol bridge (Copyable tier) | Adding a `PairLike` protocol with associated types `First, Second` lets a `Property.Typed<Element>` extension reach `Base.Second` via the protocol | **CONFIRMED (partial)** | Builds; runtime confirms `Base.Second` reachable. Caveat: ~Copyable tier additionally requires `SuppressedAssociatedTypes` experimental feature for `~Copyable` associated types; even with bridge, V3-V5 type-changing transforms remain blocked |
| V3 — Type-changing method on Property.Typed View (Copyable tier) | A consuming method on the bridged Property.Typed View can return `Pair<NewFirst, Base.Second>` | **REFUTED** | `<unknown>:0: error: 'self' is borrowed and cannot be consumed` (SIL-level). Pair is nominally `~Copyable`; the implicit copy that powers the README's Stack example does not fire for nominally-~Copyable types |
| V4 — Property.Consume with explicit `consume()` (Copyable tier) | Property.Consume's explicit `consume() -> Base?` can extract the Pair, allowing type-changing reconstruction | **REFUTED** | `'p.map' is borrowed and cannot be consumed` at the call site. The `_read { yield ... }` accessor produces a borrow that cannot host a `consume()` call inside a method body |
| V5 — Property.Inout (~Copyable tier) | Property.Inout's `_modify` yield can host a consuming method that returns a different-typed Pair | **REFUTED** | `field 'pair.map' was consumed but not reinitialized; the field must be reinitialized during the access`. The borrow contract requires the inout reference be re-yielded at scope-exit; consuming methods on the View destroy the borrow lender |

## Consolidated Finding

The empirical pattern across V1–V5 is consistent and decisive:

1. **Without a protocol bridge** (V1), `Property.Typed<Element>` cannot bind two free type generics. Confirms `swift-property-primitives/Research/case-study-dictionary-primitives-migration-failure.md` §4.2.
2. **With a `PairLike` bridge** (V2), the binding works for the Copyable tier and read-only methods — but the bridge is a non-trivial architectural addition for a foundational primitive (Pair would gain a public protocol it does not need). Matches `case-study-dictionary-primitives-migration-failure.md` §4.2.1's "Protocol Witness" approach, which that case rejected as "complexity without sufficient benefit."
3. **Type-changing transformations are blocked at the Swift-language level**, independent of the two-generic question. The View's borrow contract (whether via `_read`/`_modify` coroutines or `_read { yield }`) requires the yielded reference to live for the borrow scope and be returned in the same type. Methods that consume the View to produce a different-typed return either:
   - Conflict with the implicit-copy mechanism (Pair is nominally `~Copyable`; copy doesn't fire) — V3, V4
   - Conflict with the `_modify` borrow contract ("consumed but not reinitialized") — V5
4. **The ~Copyable tier is doubly blocked**: even granting the bridge, `~Copyable` associated types require `SuppressedAssociatedTypes` experimental feature, and `Property.Inout`'s `~Escapable` returns interact with mutating accessors in ways that require `Lifetimes` + `LifetimeDependence`. These flags are enabled in the experiment; even so, V5 fails on the consumed-not-reinitialized error.

## Decision Cross-Reference

The `property-primitives-api-design.md` (DECISION, v1.1.0, 2026-05-08) Option C is the structurally-correct shape: labeled-method renames (`map(first:)` / `map(second:)` / `map(first:second:)`) without Property.View adoption. This experiment provides the empirical receipts for the decision's load-bearing claims:

- Two-generic blocker → V1 + V2 (refuted without bridge; bridge has architectural cost)
- Type-changing-transform blocker → V3 + V4 + V5 (refuted across all View variants)
- Conditionally-~Copyable Pair vs property-primitives implicit-copy → V3 + V4 (a separate axis of friction not previously surfaced; relevant for any `~Copyable`-aware primitive considering property-primitives adoption)

## Build & Run

```bash
cd Experiments/property-view-pair-attempt
swift build --target variant-1-property-typed       # Expected: REFUTED with diagnostic
swift run variant-2-pairlike-bridge                 # Expected: CONFIRMED with output
swift build --target variant-3-type-changing-method # Expected: REFUTED
swift build --target variant-4-property-consume     # Expected: REFUTED
swift build --target variant-5-property-inout       # Expected: REFUTED
```

Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102).
Platform: macOS 26 (arm64).
Date: 2026-05-08.
