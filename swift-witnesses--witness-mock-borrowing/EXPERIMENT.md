# witness-mock-borrowing

<!-- status: REFUTED (limitation gone — unexpected) -->

## Hypothesis

The `@Witness(.mock)` macro still drops `borrowing`/`consuming` ownership
annotations when synthesizing mock closure literals, so applying it to a
struct whose closures take `borrowing <~Copyable>` parameters fails to
compile with "parameter of noncopyable type '…' must specify ownership".

Expected status: **REFUTED-as-expected (limitation persists)** — the
workaround in `IO Core/IO.swift:92–98` (disable `.mock` generation,
hand-roll `IO.fake()`) remains necessary.

If **CONFIRMED unexpectedly (limitation gone)** the macro can now drive
`IO.fake()` directly — significant ergonomic win for Shape F's testing
story (generator-driven mocks instead of hand-rolled doubles).

## Method

Compile-and-run sketch. Apply `@Witness(.mock)` to a `Sendable` struct with:

- `read: @Sendable (borrowing Resource, Int) async throws(SomeError) -> Int` — `borrowing <~Copyable>`
- `write: @Sendable (borrowing Resource, Int) async throws(SomeError) -> Int` — `borrowing <~Copyable>`
- `close: @Sendable (consuming Resource) async -> Void` — `consuming <~Copyable>` + Void return

mirroring the shape of `IO.read` / `IO.write` / `IO.close` in `swift-io`.
This covers both `borrowing` and `consuming` ownership annotations on
`~Copyable` parameters — the exact set needed to re-enable `.mock` on `IO`.

```bash
cd /Users/coen/Developer/swift-foundations/swift-io/Experiments/witness-mock-borrowing
swift build 2>&1 | tee /tmp/witness-mock-borrowing.log
```

Toolchain: Apple Swift 6.3. Platform: macOS 26 (arm64). Date: 2026-04-16.

## Result

**REFUTED (unexpected).** Build completes cleanly and the mock runs:

```
[1997/2000] Compiling witness_mock_borrowing main.swift
[1998/2000] Linking witness-mock-borrowing
[1999/2000] Applying witness-mock-borrowing
Build complete!

$ .build/debug/witness-mock-borrowing
read returned: 42
write returned: 99
close returned
```

No `"parameter of noncopyable type 'Resource' must specify ownership"`
diagnostic appears for either `borrowing` or `consuming`. The hypothesis
is refuted at the Swift-6.3 level, **and the refutation covers both
ownership kinds on `~Copyable` parameters**.

### Macro expansion (from `-dump-macro-expansions`)

The macro body is unchanged from what it was when IO disabled `.mock`:

```swift
@inlinable
public static func mock(
    read: Int,
    write: Int
) -> Self {
    Self(
        read: { (_, _) throws(SomeError) -> Int in
            read
        },
        write: { (_, _) throws(SomeError) -> Int in
            write
        }
    )
}
```

The parameters are `(_, _)` — no `borrowing` keyword, no type annotation,
no ownership keyword. Yet the closure literal type-checks against
`@Sendable (borrowing Resource, Int) async throws(SomeError) -> Int`.

The observe wrappers (emitted by the same macro run) do annotate:
`{ [witness] (from: borrowing Resource, count) throws(SomeError) -> Int in … }`.
So `borrowing` propagation is supported both via explicit annotation in
`observe` closures AND via pure-anonymous `(_, _)` inference in mock
closures.

## Analysis

**What changed**: not the `@Witness` macro itself — `generateMockClosure`
still calls `closureParameterList(named: false)` → `(_, _)` (no
ownership). What changed is the Swift compiler's inference for
ownership-less `_` placeholders in closure literals targeting function
types with `borrowing <~Copyable>` signatures. Swift 6.3 propagates the
target-type's ownership annotation through the underscored parameter,
treating `{ (_, _) in body }` as semantically equivalent to
`{ (_: borrowing Resource, _: Int) in body }` when the target type
requires it.

**Impact on IO**:

The block comment at `IO Core/IO.swift:92–98` is now stale. `@Witness(.mock)`
can be re-enabled on `IO` and used to drive `IO.fake()` generator-style
instead of hand-rolled. Proposed follow-up:

1. Change `@Witness` → `@Witness(.mock)` on `public struct IO` in
   `swift-io/Sources/IO Core/IO.swift:132`.
2. Remove the "Mock generation … is intentionally not enabled" paragraph
   at `IO.swift:92–98`.
3. Reshape `IO.fake()` in terms of `IO.mock(read:write:close:ready:
   unownedExecutor:)` (or retain the hand-rolled version and offer `.mock`
   as the new recommended path — depends on Shape F design).

**Covered in this experiment**: `borrowing <~Copyable>` (read/write) AND
`consuming <~Copyable>` (close). `unownedExecutor: @Sendable () ->
UnownedSerialExecutor` is the remaining IO closure property; it has no
ownership-annotated parameters, so nothing to check.

**Caveat — Shape F**: `mock` takes the return value as a plain parameter
(`read: Int`), not a closure. This is fine for scalar returns but may be
awkward for `read` returning `Int` where the caller wants *different*
returns per call (e.g., EOF after N bytes). The real Shape F testing
story may still prefer hand-rolled witnesses or `observe` / `.mutation`.
`.mock` is useful; it is not the whole story.

## Related research

- `swift-foundations/swift-io/Sources/IO Core/IO.swift:92–98` — the
  stale "disabled" comment, now contradicted by this experiment.
- `swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md` §6 / §7.
- `swift-foundations/swift-witnesses/Sources/Witnesses Macros Implementation/WitnessMacro.swift:479–488`
  (`generateMockClosure` → `closureParameterList(named: false)` returns
  `(_, _)` with no ownership — unchanged, but now compiles).
