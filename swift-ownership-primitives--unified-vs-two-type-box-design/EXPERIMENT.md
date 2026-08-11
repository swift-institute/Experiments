# Experiment: Unified vs Two-Type Box Design

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: CONFIRMED
tier: 2
---
-->

## Context

Pre-0.1.0 design decision for `swift-ownership-primitives`: should we model
heap-owned boxes as a single unified `Box<Value: ~Copyable>: ~Copyable` with
conditional `Copyable` (array-primitives-style), or as two separate types —
a raw-pointer-backed `UniqueBox<V: ~Copyable>: ~Copyable` and a class-backed
CoW `Box<V: Copyable>` (Apple SE-0517 style)?

The unified approach is attractive on ergonomic grounds (one name, pattern
parity with array-primitives). The two-type approach matches Apple's
explicit architectural choice in SE-0517 + presumptive future `Swift.Box`.

This experiment empirically tests whether the two approaches are actually
equivalent, or whether the unified approach gives up something architecturally
important.

## Hypothesis

H: The unified `Box<V: ~Copyable>: ~Copyable` with `extension Box: Copyable
where V: Copyable` can implement the same API surface and semantics as the
two-type split, specifically including SE-0517's `consuming func consume() -> Value`.

## Method

Constructed eight sub-hypotheses (H1–H8), each testing a specific claim.
Implemented in a single Swift package (`main.swift` + `H7b_same_name.swift`).
Each sub-hypothesis has its own result with empirical evidence (compile
behavior, runtime output, or Swift diagnostic).

## Findings

| ID | Hypothesis | Result | Evidence |
|----|-----------|--------|----------|
| H1 | Unified class-backed Box with conditional Copyable compiles | CONFIRMED | Build succeeds; `Box<Int>` (Copyable) and `Box<H1_Handle>` (~Copyable) both instantiate |
| H2 | `final class _Storage { var value: V }` with `V: ~Copyable` compiles | CONFIRMED | Build succeeds on 6.3.1 |
| H3 | Class-backed Box has larger heap footprint than raw-pointer UniqueBox | CONFIRMED (heap-level); REFUTED (struct-level) | Struct size identical (8 bytes = 1 word). Heap-level: class adds ~16-byte object header per instance |
| H4 | Conditional-Copyable Box shares storage on struct-copy | CONFIRMED | `let box2 = box1; box1._storage.value = 200` → `box2._storage.value == 200`. Reference semantics, not CoW. |
| H5 | consume() of ~Copyable Value via class-backed storage is impossible | CONFIRMED | Swift diagnostic: `'storage.value' is borrowed and cannot be consumed`. Moving a class stored property is forbidden. |
| H6 | `isKnownUniquelyReferenced` compiles in `where V: ~Copyable` extension | CONFIRMED | Returns `true` for unique, `false` for shared Copyable Box, `true` always for ~Copyable Box |
| H7 | Two conditional extensions defining same-named accessor | CONFIRMED (with caveat) | Swift accepts both; resolves by specificity. ~Copyable path has call-site restrictions (no `let v = box.value`) |
| H8 | No explicit struct deinit needed; ARC manages class storage | CONFIRMED | Storage.deinit fires exactly once at refcount=0 per runtime trace |

## The decisive finding — H5

The hypothesis "unified consume() is strained on Copyable Box" was weaker
than reality. The actual finding is: **consume() for `Value: ~Copyable` with
class-backed storage is UNIMPLEMENTABLE in Swift** — not merely awkward.

Empirically, the compiler rejects any attempt to extract a `~Copyable` value
from a class's stored property:

```
error: 'storage.value' is borrowed and cannot be consumed
note: consumed here
```

Why: Swift classes expose their stored properties through a borrowing
dispatch. You can read (borrow) them; you cannot consume (move out of) them.
This is a language-level property of class storage, not an API choice.

SE-0517's `UniqueBox<Value: ~Copyable>` must therefore use a non-class
storage representation to implement `consuming func consume() -> Value`.
Raw `UnsafeMutablePointer<Value>.move()` is the canonical mechanism —
SE-0517 almost certainly uses this shape internally.

## What this rules out

- "Unified Box<V: ~Copyable>: ~Copyable with class-backed storage and SE-0517 API parity" — **ruled out** by H5.
- "Unified Box<Copyable V> with Apple-like CoW-on-mutate by default" — ruled out by H4 (default is reference semantics; CoW would have to be added explicitly via accessor specialisation, and while that compiles (H7b), call-site ergonomics diverge between paths).

## What remains viable

Three coherent designs survive the experimental evidence:

1. **Two separate types** (SE-0517 match): `Ownership.Box.Unique<V: ~Copyable>: ~Copyable` with raw-pointer storage and working `consume()`, plus a separate class-backed `Ownership.Box<V: Copyable>` (or similar). This is Apple's architectural choice. Matches SE-0517 semantics faithfully.

2. **Unified class-backed, reduced API**: A single `Box<V: ~Copyable>: ~Copyable` with class-backed storage. Drops `consume()` entirely (or replaces with `withValue`/`withMutableValue` closures for borrowed access). Still provides `clone()` via the `where V: Copyable` extension. Loses SE-0517 API parity for the ~Copyable case.

3. **Unified hybrid storage**: class-backed for Copyable Value, raw-pointer for ~Copyable Value. Requires conditional storage representation based on generic constraints, which Swift does not support (no conditional stored properties). Not viable.

## Interpretation

The two-type approach is **architecturally necessary** if we want to ship
SE-0517's full API (specifically `consume() -> Value` for ~Copyable Value).
It is not merely an aesthetic preference.

The unified approach remains possible only if we accept a restricted API
(no SE-0517 `consume()` for ~Copyable Value) — in which case we are shipping
a materially different contract from SE-0517 despite the name alignment.

The array-primitives pattern does not transfer directly because arrays'
heap storage is always managed externally (ManagedBuffer / Buffer), so
array operations never need to consume a value out of a class stored
property — they work over the buffer's unsafe pointer internals. Box has
no such indirection: its storage IS the single value, and that value must
be moveable to implement SE-0517 `consume()`.

## Promotion

Finding promoted to `swift-ownership-primitives/Research/naming-box-ecosystem-survey.md`
as the empirical basis for the two-type recommendation.

## References

- SE-0517: UniqueBox — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0517-uniquebox.md
- Companion research: `Research/naming-box-ecosystem-survey.md`
- Companion research: `Research/naming-unique-to-box.md` (superseded)
- array-primitives' conditional-Copyable pattern: `swift-array-primitives/Sources/Array Primitives Core/Array.swift`

## Provenance

Commissioned 2026-04-24 to empirically validate the two-type recommendation
against the user's counter-proposal of a unified conditional-Copyable Box.
