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

## The "small ADD"

One extension on `Sequenceable` (extraction terminal — like `collect`/`first`, it
constrains `Element: Escapable`, admitting `~Copyable & Escapable` elements):

```swift
extension Sequenceable where Self: ~Copyable, Element: Escapable, Iterator.Failure == Never {
    consuming func forEachConsuming(_ body: (consuming Element) -> Void) {
        var iterator = makeIterator()
        while let element = iterator.next() { body(element) }
    }
}
```

(`~Copyable` cannot be re-suppressed on the inherited `Element` in a where-clause —
envelope D3 / `feedback_extension_implies_copyable`; constrain `Self: ~Copyable` +
`Element: Escapable` instead.)

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
  `.forEachConsuming{}` / `while let it.next()`.

**Bonus:** the fold SUPERSEDES the v1.3.0 §6.4 `ConsumeState` `~Copyable`-suppression
reshape escalation — `Sequenceable` is already `~Copyable & ~Escapable`, so routing
`consume()` through it delivers `~Copyable` coverage (via `forEachConsuming`) WITHOUT the
protocol reshape. The fold is strictly better than the reshape.

## Status

RECOMMENDATION → awaiting supervisor sign-off. Deletion is a separate step after sign-off
(user pre-authorizes per [ARCH-LAYER-009]). Until sign-off: HOLD §5 row-3 (do not build
set-ordered's `consume()` on `Sequence.Consume`).
