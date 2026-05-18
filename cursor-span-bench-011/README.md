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

## Results (release build, 2026-05-17)

| Probe | Legacy | Cursor | Ratio |
|---|---|---|---|
| Text peekAdvance | 165.75 µs | 165.50 µs | 0.998 |
| Text consume | 165.54 µs | 165.50 µs | 1.000 |
| Binary consumeLoop | 17.27 ms | 162.9 µs | 0.009 |
| Binary peekAdvance | 17.70 ms | 839 µs | 0.047 |

**Phase 0 gate**: GREEN. No regression on any path; substantial improvement on
the Binary paths.

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

## Verdict

Phase 0 BENCH-011 gate: **GREEN**. The Binary speedup is real and
attributable to a structural fix in the migration, not a benchmark anomaly
or compiler quirk. Documented here to record the source of the perf delta —
the abstraction did not magic; the public-stored-property pattern had been
costing real cycles.

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
