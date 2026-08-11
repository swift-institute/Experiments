# Parked — Heap.MinMax (future heap-template round)

`Heap.MinMax` (the double-ended min-max heap) is PARKED here, retained in-tree as the
future-sibling seed for the **heap-template round** (Research/adt-tower.md §9.3 heap row,
adt-tower.md:1246: "MinMax stays parked as a sibling for the heap-template round").

It is **out of the build graph** (no SwiftPM target) because:

1. Its baseline was already pre-existing RED under the W5 quarantine (2026-06-11): the
   host `Heap.MinMax` struct body was commented out in the old `Heap.swift`, so the
   `Heap MinMax Primitive`/`Primitives` targets did not compile on `main` (`Peek`/`Min`/
   `Max` not in scope; `extension Heap.MinMax where …` on a non-existent nested type).
2. It was declared as `Heap<Element>.MinMax` (nested in the base `Heap` STRUCT) and
   references the old shape-E `Heap.Index` / `Heap.Navigate` / `Heap.MinMax.Property`.
   The ADT-tower W2 reshape dissolves `Heap` into a generic-instantiation typealias
   (`Heap<E> = __Heap<…Linear>`), which structurally cannot host a nested `MinMax` type
   or those extensions — so MinMax cannot survive the reshape in its nested form.

At the heap-template round it will be hoisted to its own sibling carrier
(`__HeapMinMax<S: ~Copyable>` + a `Heap<E>.MinMax` nest alias), mirroring the family-
cluster idiom (D4.1 sense (b) / §9.2 family-cluster landing). Nothing about the parked
plan changed in this wave — deleting the non-functional `Heap.Min`/`Heap.Max` stubs did
NOT delete the MinMax plan.
