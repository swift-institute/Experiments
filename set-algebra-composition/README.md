# set-algebra-composition

**Claim.** After deleting the bundled `Set.Buildable.Protocol` (2026-05-30), the real
ordered-set variants inherit the orthogonal set algebra purely by composition —
*builder-primitives × set-primitives* — with no set-specific buildable protocol.

This experiment is the cross-variant integration coverage that the decoupling
invariant (`set-ordered ⊥ set-algebra`, library **and** test) forbids from living in
either source package. It depends on **both** `swift-set-ordered-primitives` and
`swift-set-algebra-primitives` and exercises:

- **Growable constructive** — `Set.Ordered` / `.Small` inherit `union` /
  `intersection` / `subtracting` / `symmetricDifference` (composed
  `where Self: Set.Protocol & Buildable & Iterable`).
- **Cross-variant constructive** — `Ordered.union(Small)`, `Ordered.intersection(Static)`
  (a different variant as the `Other` operand).
- **Cross-variant predicates** — `isSubset` / `isDisjoint` / `isEqual` across
  Ordered × Static / Small / Fixed (bounded variants are predicates-only).
- **Powerset lattice** — `Set.Ordered.powerset()` join = ∪, meet = ∩.
- **DSL** — all four variants build via builder-primitives' `@Builder`
  (growable free; bounded throwing).

```
swift test
```

Backs the `cross-layer-capability-protocol-model.md` decoupling. See the SIL receipt
(`/tmp/set-decouple-sil/SIL-RECEIPT.md`) for the companion 0-`witness_method`
specialization proof on the same composition.
