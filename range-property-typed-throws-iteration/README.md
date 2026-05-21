# range-property-typed-throws-iteration

## Hypothesis

Adding a `range.iterate` verb-as-property whose `callAsFunction<E>(...) throws(E)` is declared on `Property` selects the institute typed-throws path AND preserves the closure's typed-throws shape, WITHOUT competing with stdlib `Range.forEach` for overload resolution.

## Background

Phase A of the byte-arc Item B Option (a) installed a typed-throws `forEach<E>` extension on `Swift.Range` in `swift-vector-primitives`. The file compiled but was unselectable at typed-throws call sites: Swift 6.3.1 overload resolution prefers stdlib's `Sequence.forEach(_:) rethrows` and erases `throws(E)` to `any Error` at the call site. Test sites failed to compile with `error: invalid conversion of thrown error type 'any Error' to 'TestError'`. `@_disfavoredOverload` made the situation worse.

The institute's existing precedent for verb-as-property overload disambiguation is `Vector.ForEach+Property.swift` (in `swift-vector-primitives`), where `vector.forEach { … }` dispatches via `Property` and therefore does not compete with stdlib's `Sequence.forEach` (Vector is not a `Swift.Sequence`).

This experiment empirically validates whether the same Property pattern, applied to `Swift.Range` under a new verb name (`iterate`), preserves typed-throws end-to-end while leaving stdlib `Range.forEach` unchanged.

## Design

**Adapter under test** (`Sources/RangeIterateAdapter/RangeIterateAdapter.swift`):

```swift
extension Swift.Range where Bound: Strideable, Bound.Stride: SignedInteger {
    public enum Iterate {}

    public var iterate: Property<Iterate, Self> { Property(self) }
}

extension Property {
    public func callAsFunction<Bound: Strideable, E: Swift.Error>(
        _ body: (Bound) throws(E) -> Void
    ) throws(E)
    where Bound.Stride: SignedInteger,
          Tag == Swift.Range<Bound>.Iterate,
          Base == Swift.Range<Bound>
    {
        var i = base.lowerBound
        while i < base.upperBound {
            try body(i)
            i = i.advanced(by: 1)
        }
    }
}
```

**Call-site shape**:

```swift
try (0..<rank).iterate { (axis: Int) throws(AxisError) in
    guard axis < bound else { throw .outOfBounds(axis) }
}
```

The Property tag (`Range<Bound>.Iterate`) is nested inside the generic `Range<Bound>`; the `Property` extension's where-clause references it via method-level generic `Bound`. This mirrors `Vector.ForEach+Property.swift`'s shape exactly.

## Predicates

| ID  | Predicate |
|-----|-----------|
| P1  | `range.iterate { (x) throws(MyError) in ... }` compiles + runs |
| P2  | Closure error type is locally inferred as `MyError` (not `any Error`) |
| P3  | Typed catch binds `MyError` directly: `let e: MyError = error` |
| P4  | Stdlib `(0..<3).forEach { ... }` still compiles unchanged (no shadowing harm) |
| P5  | When body throws, the error propagates with the typed shape (not erased) |
| P6  | Property tag nested in generic `Range<Bound>` works (no nested-in-generic resolver issue) |
| P7  | Cross-`Bound` generic: `Range<Int32>` and `Range<UInt>` both select the institute path |
| P8  | Compatible with `ExistentialAny`, `InternalImportsByDefault`, `MemberImportVisibility`, `NonisolatedNonsendingByDefault` (institute baseline) |

## Empirical Validation Matrix ([EXP-017])

The verdict is an adoption verdict (will admit production migration of the pattern into `swift-vector-primitives`), so per [EXP-017] both release-mode and cross-module dimensions are required.

| Configuration | Result | Receipt |
|---------------|--------|---------|
| Single-module debug (initial validation, pre-restructure) | PASS — P1–P7 all green | (superseded by cross-module runs below) |
| Cross-module debug (`swift build` + `swift run`) | PASS — P1–P7 all green | `Outputs/build.txt`, `Outputs/run-debug-crossmodule.txt` |
| Cross-module release (`swift build -c release` + `swift run -c release`) | PASS — P1–P7 all green | `Outputs/build-release.txt`, `Outputs/run-release-crossmodule.txt` |
| Negative control: stdlib `Range.forEach` with `throws(E)` body | FAIL TO COMPILE (as expected) — confirms the competition is real | `Outputs/build-negative-control.txt` |

The cross-module restructure splits the adapter into `Sources/RangeIterateAdapter/` (library target) imported by `Sources/range-property-typed-throws-iteration/` (executable target) per [EXP-017].

## Negative Control

`Sources/NegativeControl/negative.swift` declares:

```swift
do throws(NegError) {
    try (0..<3).forEach { (i: Int) throws(NegError) in
        if i == 1 { throw .foo }
    }
} catch {
    let _: NegError = error
}
```

Result (`swift build --target NegativeControl`):

```
error: thrown expression type 'any Error' cannot be converted to error type 'NegError'
   10 |         try (0..<3).forEach { (i: Int) throws(NegError) in
```

This is the exact failure mode Phase A hit on `swift-vector-primitives`. The negative control confirms:

1. Stdlib `Range.forEach` selection happens despite the closure being typed-throws — overload resolution chooses `rethrows` over `throws(E)`.
2. The thrown error gets erased to `any Error` at the closure boundary.
3. The downstream typed-catch binding then fails with the diagnostic above.

Empirically proving the failure mode rules out the alternative explanation "the Property pattern works because Swift 6.3.1 silently fixed stdlib typed-throws preservation."

## Verdict

**CONFIRMED**: the Property-accessor pattern on `Swift.Range` empirically escapes stdlib `Sequence.forEach` overload competition for typed throws. The pattern is safe to adopt for production migration of the typed-throws iteration ceremony in `swift-tensor-primitives` and the broader ecosystem.

## Follow-up — full Range bridge batch (2026-05-17)

After the initial `Swift.Range.forEach` bridge landed, the architectural home was canonicalized into a dedicated `swift-range-primitives` package (the empty/temporary `Property Primitives Standard Library Integration` target was retired in favor of one-stdlib-type-one-package). The bridge surface was completed with 7 additional Range verbs:

| File | Verb | Closure shape | Return type |
|------|------|---------------|-------------|
| `Swift.Range+ForEach.swift` | `forEach` | `(Bound) throws(E) -> Void` | `Void` |
| `Swift.Range+Map.swift` | `map` (element) | `(Bound) throws(E) -> T` | `[T]` |
| `Swift.Range+Map.swift` | `map.bounds` (bound) | `(Bound) -> T` | `Range<T>` |
| `Swift.Range+Filter.swift` | `filter` | `(Bound) throws(E) -> Bool` | `[Bound]` |
| `Swift.Range+Reduce.swift` | `reduce` | `(R, Bound) throws(E) -> R` | `R` |
| `Swift.Range+AllSatisfy.swift` | `allSatisfy` | `(Bound) throws(E) -> Bool` | `Bool` |
| `Swift.Range+Contains.swift` | `contains(where:)` | `(Bound) throws(E) -> Bool` | `Bool` |
| `Swift.Range+First.swift` | `first(where:)` | `(Bound) throws(E) -> Bool` | `Bound?` |
| `Swift.Range+CompactMap.swift` | `compactMap` | `(Bound) throws(E) -> T?` | `[T]` |

All 8 bridges verified via `Sources/range-batch-smoke-test/` — 12/12 predicates pass (non-throwing + typed-throws for each verb).

## Optional / Result probe (2026-05-17)

`Sources/optional-result-stdlib-probe/` empirically tested whether Swift 6.3.2's stdlib already preserves typed throws on `Optional` and `Result`. Findings:

| Method | stdlib state (Swift 6.3.2) | Bridge needed? |
|--------|----------------------------|----------------|
| `Optional.map<U, E>(_:)` | Typed throws supported | NO — `try? some.map { (x) throws(E) -> U in ... }` works |
| `Optional.flatMap<U, E>(_:)` | Typed throws supported | NO |
| `Result.map<NewSuccess>(_:)` | Non-throwing transform only | NO (by design — Result already typed-throws via `Failure`) |
| `Result.mapError<NewFailure>(_:)` | Non-throwing transform only | NO (same reasoning) |

Per SE-0413, stdlib rethrows-replacement is "Future Directions" — Optional landed first; Sequence remains pending. Our Range bridges are needed until Sequence is upgraded.

## Performance pass (2026-05-17, release build)

`Sources/range-perf-bench/` compared Property bridges vs stdlib non-throwing baselines + manual while-loops at 10M iters:

| Verb | stdlib non-throwing | Property typed-throws | Manual loop |
|------|---------------------|------------------------|-------------|
| forEach | 0.80 ns/iter | 0.80 ns/iter | 0.80 ns/iter |
| map | 0.40 ns/iter | 0.41 ns/iter | 0.41 ns/iter |
| filter | 1.10 ns/iter | 1.11 ns/iter | — |
| reduce | 0.0 ms total (optimized away) | 0.0 ms total (optimized away) | — |

`@inlinable` + `callAsFunction` collapse to identical codegen. Zero measurable overhead vs stdlib in release.

## Forward compatibility (Swift 6.4+)

When stdlib adds typed throws to `Sequence.forEach` (et al.) per SE-0413's Future Directions, the Property bridge should continue to win overload resolution because:

1. Property accessor is a `var` (different member kind than stdlib's `func`).
2. Property accessor is a direct extension on `Swift.Range` (not inherited from `Sequence`); direct extensions outrank protocol inheritance for member lookup.

If at some future point overload ambiguity does manifest, the bridges can be conditionally compiled with `#if !canImport(_typed_throws_Sequence_stdlib)` or similar feature-detection. To revalidate: re-run `Outputs/build-negative-control.txt` against the future toolchain — if it compiles clean (stdlib now preserves typed throws), the bridge becomes redundant but doesn't conflict.

### Why the pattern wins overload resolution

`Range<Bound>` conforms to `Swift.Sequence` (stdlib), so stdlib's `Sequence.forEach(_:) rethrows` is visible on `range.forEach`. Adding our own `forEach<E>` on the same type (Phase A) creates a same-name overload that Swift 6.3.1 cannot distinguish on `throws`-cost — it ties and prefers stdlib, erasing `throws(E)` to `any Error`.

The Property pattern *moves the method to a different type*. `range.iterate` returns `Property<Range.Iterate, Range<Bound>>`. `Property` is not a `Swift.Sequence`. The `callAsFunction<E>(...) throws(E)` declared on `Property` (with `Tag == Range<Bound>.Iterate, Base == Range<Bound>`) has no competing overload anywhere — stdlib doesn't extend `Property`. Overload resolution is unambiguous: there is exactly one applicable method.

Behaviorally, `range.iterate { … }` invokes `range.iterate.callAsFunction({ … })`, which loops with the typed `throws(E)` clause intact.

## Recommendation

Adopt **Option (c.2 refined): Property accessor** as the canonical institute pattern for typed-throws iteration on `Swift.Range`.

**Implementation arc** (to be authorized separately):

1. Add the adapter to `swift-vector-primitives/Sources/Vector Primitives Core/Swift.Range+Iterate.swift` mirroring `Vector.ForEach+Property.swift`'s shape (with `@inlinable`, since the Property import will be `@_exported public import` from the Core's `exports.swift`, satisfying the `@inlinable` access-control constraint).
2. Remove the dead `Swift.Range+ForEach.swift` (Phase A's unsuccessful extension) — keeping it violates [IMPL-060] discipline.
3. Migrate the two typed-throws iteration sites in `swift-tensor-primitives` (`Tensor.Broadcast+Align.swift`, `Tensor.Index+Linearize.swift`) from `Vector<Int>(transform:count:).forEach` ceremony to `(0..<n).iterate { ... }`.
4. Migrate the 6 cross-package sites in `swift-affine-geometry-primitives` + `swift-algebra-linear-primitives`.
5. Retire Item A.1 in `tensor-primitives-implementation-follow-ups.md` (no longer needed — the pattern is structural, not a typed-throws-exemption request).

## Constraints honored

- Repo stays private; no `git push`, no `git tag`, no public dissemination.
- Institute Experiments package conventions: kebab-case dir name matching `Package.name` matching executable target name ([EXP-003d]); macOS 26 + Swift 6.3 ([EXP-003a]); header anchor ([EXP-007a]); ecosystem swiftSettings.
- No research-doc modifications, no consumer migrations performed in this session.

## Files

```
Package.swift
Sources/RangeIterateAdapter/RangeIterateAdapter.swift   (library target — the adapter under test)
Sources/NegativeControl/negative.swift                  (intentional compile-fail; proves competition is real)
Sources/range-property-typed-throws-iteration/main.swift (executable — runs P1–P7)
Outputs/build.txt
Outputs/build-release.txt
Outputs/run-debug-crossmodule.txt
Outputs/run-release-crossmodule.txt
Outputs/build-negative-control.txt
```

## Cross-references

- Skill **implementation** [IMPL-020], [IMPL-021], [IMPL-026] — Property pattern canon
- Skill **code-surface** [API-NAME-001] — Nest.Name (Range.Iterate)
- Skill **code-surface** [API-ERR-001], [API-ERR-005] — typed throws + stdlib compatibility
- Skill **experiment-process** [EXP-017] — release-mode + cross-module validation
- Existing precedent: `swift-vector-primitives/Sources/Vector Primitives Core/Vector.ForEach+Property.swift`
- Prior failure: `swift-vector-primitives/Sources/Vector Primitives Core/Swift.Range+ForEach.swift` (dead — to be removed in migration arc)

## Blog Potential

This experiment has been captured as a blog idea:
- [BLOG-IDEA-104: Overloading by member kind: coexisting with the standard library](../../../swift-institute/Blog/_index.json) — currently in `In Progress` (draft at `Blog/Draft/overloading-by-member-kind.md`)
