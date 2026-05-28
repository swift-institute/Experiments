# consume-fold-into-sequenceable

**Question (supervisor-directed):** Is `Sequence.Consume` (protocol + `Consume.View`)
a load-bearing capability, or does it FOLD into `Sequenceable`? Run a 4-axis
capability-gap check of `Sequence.Consume.View` against **`Sequenceable`'s consuming
`makeIterator`** (the real fold-target — the prior keep-finding compared only against
`drain()`/`forEach`/`Iterator.Borrow`).

**Toolchain:** Apple Swift 6.3, macOS 26 arm64, full ecosystem Swift settings
(`.strictMemorySafety()`, `Lifetimes`, `SuppressedAssociatedTypes`, `ExistentialAny`,
`InternalImportsByDefault`, `MemberImportVisibility`, `NonisolatedNonsendingByDefault`,
`InferIsolatedConformances`, `LifetimeDependence`). Verified **DEBUG and RELEASE**.

## Verdict: NO REAL GAP → FOLD

| Axis | Finding | Gap? |
|------|---------|------|
| **(i) Type-erasure** | Ecosystem grep: **0** production consumers of the concrete `Sequence.Consume.View` type. The only references outside the defining package + the conformers' own `consume()` defs are **4 comments** in set-ordered's `+Iteration.swift`. The supervisor-named "consumers" (Binary.parse, …) use an unrelated `Binary.View.consume()` (byte-cursor), not `Sequence.Consume.View`. The closure-erasure / concrete-storable-cross-backing affordance is unused. | **NO** |
| **(ii) Owned `~Copyable` yield** | `Sequenceable`'s consuming `makeIterator()` → an owned `~Copyable` iterator whose `next()` MOVES owned `~Copyable` elements OUT of OWNED storage (NOT A4's borrowed-span move-out — the iterator owns its storage). Verified: a `~Copyable` `Token`, owned `Drainer` iterator, `next()` via `(base+i).move()`. An owned-consuming `forEach` terminal (`forEachConsuming`, the **"small ADD"**) drives it. Built + ran DEBUG+RELEASE: `sum=60`. | **NO** (small ADD) |
| **(iii) Early-exit cleanup** | The `~Copyable` iterator's `deinit` cleans up remaining elements on early drop — **equivalent** to `Consume.View`'s `State.deinit`. Verified: consumed 2 of 5, dropped → `Drainer.deinit` cleaned up **3 remaining**, DEBUG+RELEASE. | **NO** |
| **(iv) Call-site** | `x.consume().forEach{}` ≡ `x.forEachConsuming{}`; `while let e = view.next()` ≡ `while let e = it.next()`. Both expressible via `Sequenceable` + the `forEachConsuming` terminal. DEBUG+RELEASE green. | **NO** |

## The perfected terminal (supervisor perfection directives 1–3, 5)

The terminal is a plain **`consuming func forEach`** (NOT a compound `forEachConsuming`,
[API-NAME-002]; NOT a `Property.Inout` accessor — see below). It MIRRORS
`Iterable.forEach`'s method shape: typed-throws + a fallible `Either<E, Iterator.Failure>`
overload ([API-ERR-001]), `consuming` instead of `borrowing`. Verified DEBUG + RELEASE.

```swift
extension Sequenceable where Self: ~Copyable, Element: Escapable, Iterator.Failure == Never {
    consuming func forEach<E: Swift.Error>(
        _ body: (consuming Element) throws(E) -> Void
    ) throws(E) {
        var iterator = makeIterator()
        while let element = iterator.next() { try body(element) }
    }
}
extension Sequenceable where Self: ~Copyable, Element: Escapable {     // fallible iterator
    consuming func forEach<E: Swift.Error>(
        _ body: (consuming Element) throws(E) -> Void
    ) throws(Either<E, Iterator.Failure>) { /* fuse closure-E + iterator-Failure */ }
}
```

(`~Copyable` cannot be re-suppressed on the inherited `Element` in a where-clause —
envelope D3 / `feedback_extension_implies_copyable`; constrain `Self: ~Copyable` +
`Element: Escapable` instead. The infallible overload wins resolution for `Never`-failure
conformers, exactly as on `Iterable.forEach`.)

### Why a METHOD, not the `Collection.ForEach` Property.Inout accessor (directives 1 + 3)

The supervisor directed mirroring `Collection.ForEach`'s `forEach.consuming { }` accessor.
**That shape is not viable for `Sequenceable`'s consuming drain on the production compiler
(≤ 6.3.2)** — verified against source:

- `Collection.ForEach`'s `.borrowing`/`.consuming` are **index-based**
  (`Collection.ForEach+Property.Inout.swift`): `while index < endIndex { body(base.value[index]); … }`;
  `.consuming` borrow-iterates by index then `removeAll` — it **never consumes self** and
  **never holds an iterator across the loop**. It needs `Base.Index: Escapable` + `Clearable`.
- Even the Iterable-routed variant **delegates to `Iterable.forEach`**, NOT a held iterator —
  `Collection.ForEach+Property.Inout.Iterable.swift:19–29` states verbatim: driving
  `makeIterator()` across a `while` loop "does not typecheck on the production compiler:
  `Property.Inout`'s `base.value` is yielded by a `_read` coroutine (statement-scoped) …
  the exact constraint documented by `Iterable+ForEach.swift` and its `Canary` test."
- `Iterable.forEach` ITSELF is a `borrowing func`, not the accessor, for this reason
  (`Iterable+ForEach.swift:6–16`).
- `Sequenceable` has **no indices** and `makeIterator()` is **consuming-self** — a
  `Property.Inout` `&self` borrow-view can neither consume self nor hold the iterator across
  the loop. So it cannot mirror `Collection.ForEach`; it mirrors `Iterable.forEach` (the
  method shape). A normal `consuming func` holds the iterator fine (no coroutine wall).

**Axis-3 read (recommendation):** a *unified `forEach.{borrowing,consuming}` accessor* across
Iterable/Sequenceable/Collection is **NOT** the evergreen — the Property accessor only hosts
**index-based** iteration on the production compiler; the two **iterator-based** protocols
(`Iterable` borrowing, `Sequenceable` consuming) both use the **`func forEach` method** shape
(Iterable already does; Sequenceable mirrors it). The unification is at the **name** (`forEach`)
and the **typed-throws contract**, not a shared accessor. Revisit the accessor only when the
SE-0507 `borrow` accessor reaches a production compiler (the gated-out fix the floor cites).
This is **not a one-off**: it makes Sequenceable consistent with Iterable (its orthogonal sibling).

## Migration cost (if FOLD is signed off)

- **7 buffer conformers' `+Consume.swift`** (delete the `Sequence.Consume.Protocol`
  conformance + the heap-class `ConsumeState` + `consume()`): `Buffer.Linear`, `.Bounded`,
  `Buffer.Linked`, `Buffer.Ring`, `.Bounded`, `Buffer.Slab`, `.Bounded` (Inline/Small carry
  `ConsumeState` classes too).
- **set-ordered's 4 `+Sequence.Consume.swift`** (base/Fixed/Static/Small) + the
  `+Iteration.swift` `consume()` delegations (+ the `takeBuffer` interim — already slated
  for deletion in §5 row 3).
- **`Sequence.Consume` itself**: protocol + `View` + the `Sequence Consume Primitives`
  module — DELETE outright (no deprecation / alias / re-export / compat shim, user directive).
- Conformers' tests: migrate `.consume().forEach{}` / `while let view.next()` →
  `.forEach{}` (consuming) / `while let it.next()`.

### Deletion safety (directive 4, [SUPER-026]) — reference-count-near-zero is NOT rm-safe

Import-graph check: the ONLY importer of `Sequence_Consume_Primitives` is the **umbrella**.
Deletion therefore also requires (verified, swift-sequence-primitives):

- Remove `@_exported public import Sequence_Consume_Primitives` from
  `Sources/Sequence Primitives/exports.swift:14` (umbrella re-export — else the umbrella
  won't compile).
- Remove the Package.swift entries: the `.library(name: "Sequence Consume Primitives")`
  product (L38), the `.target` (L205), the umbrella's dep on it (L250), and the
  `Sequence Consume Primitives Tests` target (L355–356).

No other module imports it; no consumer beyond the umbrella re-export + the conformers'
own `consume()` defs.

**Bonus:** the fold SUPERSEDES the v1.3.0 §6.4 `ConsumeState` `~Copyable`-suppression
reshape escalation — `Sequenceable` is already `~Copyable & ~Escapable`, so routing
`consume()` through it delivers `~Copyable` coverage (via `forEachConsuming`) WITHOUT the
protocol reshape. The fold is strictly better than the reshape.

## Status

RECOMMENDATION → awaiting supervisor sign-off. Deletion is a separate step after sign-off
(user pre-authorizes per [ARCH-LAYER-009]). Until sign-off: HOLD §5 row-3 (do not build
set-ordered's `consume()` on `Sequence.Consume`).
