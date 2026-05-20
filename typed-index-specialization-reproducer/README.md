# typed-index-specialization-reproducer

Reproducer scaffold for the typed-index specialization audit
(`swift-institute/Research/typed-index-specialization-audit.md`).

**Status**: SCAFFOLD. No reproducer code written yet. Filing
artifacts staged for principal disposition; construction of the
actual minimal reproducer is gated on principal authorization
(per `/Users/coen/Developer/HANDOFF-typed-index-specialization-audit.md`
Phase 5 — "filing venue + timing is principal's call").

## Hypothesis under test (if construction is authorized)

> Swift's release-mode optimizer fails to specialize four generic
> functions on cross-module call paths, producing per-call
> witness-table dispatch on hot paths even when all legitimate
> institute-side annotations (`@inlinable`, `@frozen`,
> `@usableFromInline`, `public import`, `@_alwaysEmitIntoClient`)
> are present:
>
> 1. `Cursor.peek<DomainTag>() -> Byte?` (cross-module generic
>    constrained by `Memory.Contiguous.Borrowed.Protocol`)
> 2. `Lexer.Scanner.peek<X: Byte.Protocol>() -> X?` (cross-module
>    generic over a witness-table-dispatched conversion init)
> 3. `Tagged.retag<New>(_:to:) -> Tagged<New, Underlying>`
>    (cross-module phantom-coercion delegating to a
>    non-`@inlinable` `init(_unchecked:)`)
> 4. `_CarrierProtocol.underlying` per-conformer witness
>    (auto-synthesized witness thunk for stored-property
>    requirement; not directly fixable via annotations on the
>    conformer)

## Minimum reproducer shape (if/when constructed)

Per `[ISSUE-002]`: single `swiftc`-buildable file preferred; for
cross-module specialization defects, SwiftPM with ≥2 small
modules is required by construction (a single file cannot
exercise cross-module dispatch).

Anticipated package layout:

```
typed-index-specialization-reproducer/
├── Package.swift
├── Sources/
│   ├── ReproCarrier/          # carrier-protocol mock + a stored-property conformer
│   ├── ReproTagged/           # phantom-typed wrapper mocking Tagged.retag<A>
│   ├── ReproCursor/           # generic-bounded peek() over a "byte storage" protocol
│   └── repro-bench/           # the consumer; runs hot loop on canada-shape input
└── README.md
```

## Evidence to attach (already gathered)

These exist in the parent audit and the bench binary:

- `swift-foundations/swift-json/Research/parse-performance-canada-anomaly.md`
  v1.4.1 §"Pre-Gate 1" — SIL spot-check (binary symbol inspection
  on `parse-performance-bench` release binary, 65,356 demangled
  symbols).
- `swift-foundations/swift-json/Research/parse-performance-canada-anomaly.md`
  v1.4.0 §"Time Profiler evidence" — 618-sample xctrace recording
  showing ~27.8% of total samples in Swift runtime metadata
  machinery (`_getWitnessTable`, generic metadata cache lookups,
  Tagged instantiation, ARC).
- Pre-fix annotation audit (this audit's Phase 1): all 4 sites
  carry `@inlinable` + `@usableFromInline` + `public import`
  correctly; the gaps are `@frozen` (Cursor, Lexer.Scanner) and
  the `Tagged.init(_unchecked:)` callee.
- Post-fix wall-clock measurement: NULL DELTA (236 ms unchanged
  from v1.4.1 baseline 235.62 ms) after the carrier-primitives
  default-impl `@_alwaysEmitIntoClient` fix.

## Why this is held pending principal disposition

The brief is explicit (and reaffirmed by the principal on
2026-05-20): **NO upstream filing without explicit approval**.
The four sites' verdicts are not yet "all CONFIRMED-COMPILER-BUG"
— three institute-side annotation levers remain unfired:

| Lever | Site(s) | Blocker |
|-------|---------|---------|
| `@frozen` on `Cursor` | Site 1 | ABI-shape change, principal ratification |
| `@frozen` on `Lexer.Scanner` | Site 2 | ABI-shape change, principal ratification |
| `@inlinable` on `Tagged.init(_unchecked:)` | Site 3 | swift-tagged-primitives has parallel-session WIP under `Lint/` at audit time |

After those three land, re-running the SIL/wall-clock methodology
against the same canada workload determines whether the four
sites remain unspecialized. Only then is the
CONFIRMED-COMPILER-BUG verdict applicable, and only then would
the reproducer construction be authorized.

## References

- Parent audit: `swift-institute/Research/typed-index-specialization-audit.md`
- Dispatch: `/Users/coen/Developer/HANDOFF-typed-index-specialization-audit.md`
- Upstream investigation: `swift-foundations/swift-json/Research/parse-performance-canada-anomaly.md` v1.4.1
- `[ISSUE-002]` minimal reproducer discipline (skill: `issue-investigation`)
- `[ISSUE-025]` in-package verification of synthetic-reproducer claims
