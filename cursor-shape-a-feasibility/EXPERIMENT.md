# cursor-shape-a-feasibility

Empirical test of Shape A — single generic `Cursor<Storage>` — for the Three-Worlds cursor architecture in `swift-institute/Research/cursor-abstractions-l1-ecosystem.md` v1.4.0.

## Hypothesis

The doc rejected Shape A as "structurally impossible — Swift offers no way to make `Escapable` conditional on a generic parameter." `Tagged<Tag, Underlying>` at swift-tagged-primitives empirically refutes the literal claim (declared `~Copyable & ~Escapable`, conditionally Copyable/Escapable via where clauses on Underlying). This experiment tests whether the underlying conclusion (Three Worlds, not Shape A) survives a more careful empirical examination.

## Method

Six variants, incrementally constructed per [EXP-004a], in `Sources/CursorShapeASubject/`:

| Variant | Hypothesis | Verdict |
|---|---|---|
| V1 — Bare type | `Cursor<Storage>: ~Copyable, ~Escapable` + conditional Copyable/Escapable via Tagged-style where clauses compiles | **CONFIRMED** |
| V2 — Multi-arity | Multi-arity `Cursor<Storage, PositionTag>` compiles; W2 typealias separates DomainTag from Storage | **CONFIRMED** for compile; reveals W2-Copyable bug |
| V3 — Same-type Mode discriminator | `extension Cursor: Copyable where Mode == Owned` discriminates W2 (~Copyable) from W3 (Copyable) | **REFUTED** — `error: conditional conformance to suppressible protocol 'Copyable' cannot depend on 'Mode == X'` |
| V4 — Protocol-conformance Mode discriminator | `extension Cursor: Copyable where Mode: OwnedMode` (custom marker protocol) | **REFUTED** — `error: conditional conformance to suppressible protocol 'Copyable' cannot depend on 'Mode: OwnedMode'` |
| V5 — ~Copyable Storage wrapper | Wrap `Span<UInt8>` in a `~Copyable` proxy (`BorrowedBytes`) so Storage-driven inheritance gives W2 ~Copyable correctly | **CONFIRMED** |
| V6 — Operation surfaces via conditional extensions | peek/advance/consume gated on `Storage == BorrowedBytes` for W2 and `Storage == [Element]` for W3 | **CONFIRMED** |
| V7 — Cross-module + release-mode per [EXP-017] | Instantiation works from a separate target in `-c release` | **CONFIRMED** |

## Result: PARTIAL — Shape A is structurally achievable, but with a non-obvious caveat

**The original doc's reasoning is wrong** (V1, V2 refute it): Swift DOES allow conditional Copyable/Escapable conformance on generic parameters. Tagged proves it; this experiment reproduces the pattern for a Storage-parameterized cursor.

**But a discriminator-based unification fails** (V3, V4): The compiler explicitly rejects `Mode == X` (same-type) AND `Mode: SomeProtocol` (custom-protocol-conformance) constraints in suppressible-protocol conditional conformance. The relevant diagnostic text:

```
error: conditional conformance to suppressible protocol 'Copyable' cannot depend on 'Mode == CursorV3.Owned'
error: conditional conformance to suppressible protocol 'Copyable' cannot depend on 'Mode: CursorV4_OwnedMode'
```

This is the load-bearing structural finding. The language permits suppressible-protocol conformance to inherit from the parameter's OWN suppressible-protocol conformance (Tagged pattern), but does NOT permit discrimination via auxiliary same-type or custom-protocol constraints.

**Shape A IS achievable** (V5, V6, V7): by introducing a `~Copyable` wrapper struct (`BorrowedBytes`) around `Span<UInt8>`. Then:
- W1 (owned `~Copyable` storage) → cursor ~Copyable via Storage's ~Copyable
- W2 (BorrowedBytes wrapper around Span) → cursor ~Copyable via wrapper's ~Copyable
- W3 (`[Element]` storage) → cursor Copyable via Storage's Copyable

All three Worlds collapse into one `Cursor<Storage, PositionTag>` type. Operation surfaces add via conditional extensions per `Storage`.

## Recommendation

The Three-Worlds decision in `cursor-abstractions-l1-ecosystem.md` v1.4.0 should be revisited in light of these findings. Specifically:

1. **The v1.4.0 doc's Shape A rejection reasoning is empirically refuted.** "Swift offers no way to make Escapable conditional on a generic parameter" is false. The actual constraint is narrower: discriminator-based conditional conformance is forbidden, but parameter-inherited conditional conformance is the Tagged pattern and works.

2. **Shape A is structurally achievable**, contingent on accepting a `~Copyable` `BorrowedBytes` wrapper for W2's Span-substrate case. This is a real cost — every W2 construction adds one wrapping layer at the call site, mitigated by a convenience init.

3. **The trade-off becomes a design judgment, not a forced shape**: one generic type with conditional extensions (Shape A, V5+V6 shape) vs three distinct types with cleaner local surfaces (Three Worlds, currently shipping). Phase 4 Shape ι expansion can land EITHER shape — they're now equivalents on structural feasibility, distinguished only by trade-offs.

Recommend a follow-up `/research-process` arc to revisit the v1.4.0 Three-Worlds decision with this empirical evidence in hand. Specifically: does Shape A's "single generic + conditional extensions" win on legibility, build time, generic specialization, and Phase 4 expansion cost — or does Three Worlds still win on per-World local clarity? The experiment proves the question is now a trade-off, not a structural verdict.

## Toolchain

Swift 6.3.1 (Apple Swift 6.3), macOS 26 / arm64e, 2026-05-18.

## How to reproduce

```bash
cd /Users/coen/Developer/swift-institute/Experiments/cursor-shape-a-feasibility
rm -rf .build
swift build              # V1, V2, V5, V6 compile clean
swift run -c release     # V7 cross-module + release-mode validates
# To reproduce V3 / V4 refutation: restore V3_ModeDiscriminator.swift and
# V4_ProtocolDiscriminator.swift from git history (deleted to unblock V5
# build). Each produces the diagnostic quoted above.
```

## See also

- `swift-institute/Research/cursor-abstractions-l1-ecosystem.md` v1.4.0 — the Three-Worlds decision this experiment empirically tests.
- `swift-primitives/swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift` — the empirical Tagged precedent that motivated revisiting the doc's reasoning.
- `swift-institute/Experiments/cursor-span-bench-011/README.md` — the Phase 0 perf probe whose numbers a Shape-A re-design would need to match.
