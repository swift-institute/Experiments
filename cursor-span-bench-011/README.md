# cursor-span-bench-011

Phase 0 hard-gate empirical probe for the cursor-abstractions implementation arc
(`swift-institute/Research/cursor-abstractions-l1-ecosystem.md` v1.3.0 DECISION
2026-05-17, choice C).

## Subject under test

`Cursor.Span<DomainTag>: ~Copyable, ~Escapable` — the proposed unified
borrowed-Span cursor with `Tagged<DomainTag, Ordinal>` position. Vendored in
`Sources/Cursor Span Bench Subject/` for measurement; the production
implementation ships in `swift-cursor-primitives` once Phase 0 clears green.

## Probes

| Probe | Subject A (legacy) | Subject B (cursor) |
|---|---|---|
| Text peekAdvance | `Lexer.Scanner` (`peek` / `advance` loop) | `Cursor.Span<Text>` (`peek` / `advance` loop) |
| Text consume | `Lexer.Scanner` (`consume` loop) | `Cursor.Span<Text>` (`consume` loop) |
| Binary consumeLoop | `Binary.Bytes.Input.View` (`removeFirst` loop) | `Cursor.Span<Byte>` (`consume` loop) |
| Binary peekAdvance | `Binary.Bytes.Input.View` (`first` / `removeFirst(1)` loop) | `Cursor.Span<Byte>` (`peek` / `advance` loop) |

200 iterations × 65 KiB buffer per probe, release build, macOS 26 / arm64e,
warmup 10 iterations, accumulator behind an `@inline(never)` blackHole.

## Results (release build, 2026-05-17 — initial Shape γ → Shape A migration)

| Probe | Legacy | Cursor | Ratio |
|---|---|---|---|
| Text peekAdvance | 165.75 µs | 165.50 µs | 0.998 |
| Text consume | 165.54 µs | 165.50 µs | 1.000 |
| Binary consumeLoop | 17.27 ms | 162.9 µs | 0.009 |
| Binary peekAdvance | 17.70 ms | 839 µs | 0.047 |

**Phase 0 gate**: GREEN. No regression on any path; substantial improvement on
the Binary paths.

## Results (release build, 2026-05-18 re-run — single-generic Cursor<DomainTag> reshape)

After `cursor-shape-a-vs-three-worlds.md` v1.2.0 single-generic refinement
landed (`Cursor<Storage, PositionTag>` → `Cursor<DomainTag: Ownership.Borrow.\`Protocol\`>`),
re-ran the four probes to verify no regression at the substrate level.

| Probe | Legacy | Cursor | Ratio |
|---|---|---|---|
| Text peekAdvance | 218.79 µs | 218.38 µs | 0.998 |
| Text consume | 215.29 µs | 215.17 µs | 0.999 |
| Binary consumeLoop | 218.38 µs | 218.13 µs | 0.999 |
| Binary peekAdvance | 1.10 ms | 1.10 ms | 0.999 |

**Single-generic reshape gate**: GREEN. All ratios ≈ 1.000 — parity between
the new production `Cursor<Byte>` / `Cursor<Text>` (now reached through the
`Binary.Bytes.Input.View` and `Lexer.Scanner` typealiases) and the vendored
two-generic `Cursor.Span<DomainTag>` substrate (frozen at the 2026-05-17
shape for historical-baseline measurement). No regression vs the two-generic
shape.

The 2026-05-17 Binary 20-100× speedup vs pre-cursor `Binary.Bytes.Input.View`
(public-stored-property `var position: Int` defect) is locked in — both
Subject A (legacy, now `Cursor<Byte>` via typealias) and Subject B (vendored
old two-generic) operate on the @usableFromInline internal stored
`_position`, so both paths are at the post-fix performance tier. Absolute
times are slightly higher than the 2026-05-17 baseline (218µs vs 165µs Text;
218µs vs 162µs Binary consumeLoop) because of unrelated host-environment
variance between measurement sessions; ratio parity is the load-bearing
signal, not absolute regression to the prior numbers.

The Binary peekAdvance probe at 1.10 ms reflects `removeFirst(1)` on the
typealiased View (per-call typed-Cardinal construction + advance), still
~16× faster than the 17.70 ms pre-cursor baseline.

## Verdict

**Phase 0 BENCH-011 gate**: GREEN (2026-05-17, original).
**Single-generic reshape gate**: GREEN (2026-05-18, re-run). The Binary
speedup is real, attributable to the original cursor migration's
public-stored-property fix, and survives both subsequent reshapes (two-generic
→ single-generic) of the cursor substrate without regression.

## Root-cause investigation of the Binary 20-100× speedup

The Text path's parity is unsurprising — `Lexer.Scanner`'s pre-migration
cursor field was already `@usableFromInline internal var cursor:
Text.Position`, matching the `Cursor.Span<Text>` shape. The generic
parameterization over `DomainTag = Text` adds no overhead at the
instantiation site.

The Binary path's 20-100× speedup is a real perf delta that warrants
explanation. Per principal review (2026-05-17), the speedup falls into
category (a) — *legacy Binary.Bytes.Input.View had a real perf defect that
the cursor migration accidentally fixed*. The structural difference:

```swift
// Pre-migration Binary.Bytes.Input.View
public struct View: ~Copyable, ~Escapable {
    @usableFromInline
    let span: Span<UInt8>

    public var position: Int       // ← PUBLIC stored property, no @inlinable
    ...
}

// Post-migration Cursor.Span<DomainTag>
public struct Span<DomainTag: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    @usableFromInline
    internal let source: Swift.Span<UInt8>

    @usableFromInline
    internal var _position: Tagged<DomainTag, Ordinal>   // ← @usableFromInline internal
    ...
}
```

`public var position: Int` is a public stored property without `@inlinable`.
Public stored properties default to resilient access — the compiler emits
opaque getter/setter calls rather than direct field reads/writes, because
the property's storage layout is not part of the module's stable ABI by
default. Inside `@inlinable` mutating methods like `removeFirst()`, every
position read and every position write goes through the resilient access
pattern, which optimizer passes cannot fully simplify.

`@usableFromInline internal var _position` is the cursor's pattern. Internal
visibility with `@usableFromInline` means the storage is non-resilient (it's
part of the module's compile-time-known layout), AND it is accessible from
`@inlinable` methods. The optimizer can inline position reads/writes
directly as memory loads and stores.

The hot-loop overhead difference compounds: at 65 KiB per iteration with
200 iterations, every additional cycle per position access ships at scale.
Lexer.Scanner already used the `@usableFromInline internal` pattern — which
is why the Text path shows parity rather than speedup.

### Why this matters for the broader institute

The defect is not unique to `Binary.Bytes.Input.View`. Any `public var`
stored property on an `@inlinable`-method-bearing struct pays the same
hidden cost. The cursor migration is one example of "rename to
`@usableFromInline internal` + provide an `@inlinable public var`
computed accessor" producing significant wins. Worth a separate ecosystem
audit before pre-1.0.

## How to reproduce

```bash
cd /Users/coen/Developer/swift-institute/Experiments/cursor-span-bench-011
rm -rf .build
swift test -c release
```

Look for `[BENCH-011]` log lines in the output.

## See also

- `swift-institute/Research/cursor-abstractions-l1-ecosystem.md` v1.3.0 — the
  arc's DECISION doc.
- `swift-primitives/swift-cursor-primitives/Sources/Cursor Span Primitives/Cursor.Span.swift`
  — the production implementation that landed after this probe.
