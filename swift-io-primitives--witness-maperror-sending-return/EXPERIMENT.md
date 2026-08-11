# witness-maperror-sending-return

<!-- status: REFUTED-HOLDS (with nuance) -->

## Verdict

Hypothesis **holds** in the "REFUTED still holds" direction, with a single
nuance: **V3 compiles** — but it is not a mapError technique so much as a
**change to the witness shape**. V3 imposes `Sendable` on the leaf error and
`@Sendable` on every stored closure, which is exactly the constraint the
hypothesis flags as "last resort — violates the no-Sendable-constraint
preference". Among the techniques that leave `IO<LeafError: Error>` as-is
(V1 / V2 / V4 / V5), **none compile**. Region inheritance is intrinsic to
closure capture; no recombination at the mapError call site rebases the
stored closures' region.

## Method

Compile-only sketch. Five hand-written `mapError` variants on a minimal
`IO<LeafError>` with three stored closures (`_read` / `_write` / `_close`)
exercising `borrowing`, `consuming`, `async`, and `throws(LeafError)`.
Each variant attempts to return `sending IO<NewError>` (or
`sending SendableIO<NewError>` for V3).

Build command:

```bash
cd Experiments/witness-maperror-sending-return
swift build 2>&1 | tee /tmp/witness-maperror-sending-return.log
```

## Results (Swift 6.3.1 release, macOS 26 arm64, 2026-04-16)

| Variant | Technique | Outcome |
|---------|-----------|---------|
| V1 | `consume self` + reconstruction | FAIL |
| V2 | explicit `@Sendable` wrapper closures | FAIL |
| V3 | `SendableIO` with `LeafError: Sendable` + `@Sendable` closures | **COMPILES** |
| V4 | `withSending` helper (sending parameter) | FAIL |
| V5 | reconstructed closure literals with `[self]` captures | FAIL |

### V1 — `consume self` + reconstruction

Diagnostic:

```
error: task or actor-isolated value cannot be sent
  at `return IO<NewE>( ... )`
```

`consume self` moves ownership but does not rebase region. The closures inside
`consumed` still carry the task-isolated region they had on the original IO;
placing them into a fresh `IO<NewE>` value does not migrate that region.

### V2 — `@Sendable` wrapper closures

Diagnostic:

```
error: capture of 'readFn' with non-Sendable type
       'nonisolated(nonsending) (borrowing Resource) async throws(LeafError) -> Int'
       in a '@Sendable' closure  [#SendableClosureCaptures]
  note: a function type must be marked '@Sendable' to conform to 'Sendable'
```

`@Sendable` on the wrapper requires the captures to be `Sendable`. The stored
closures on `IO<LeafError>` are plain async function values (not
`@Sendable`), so this is a hard stop. Can only be fixed by changing `IO`'s
stored property types (which is V3).

### V3 — `SendableIO` with Sendable leaf error

**Compiles.** But the "fix" is a witness shape change:

- `LeafError: Error & Sendable`
- All three stored closures typed `@Sendable (...)...`
- The container `SendableIO` is itself `Sendable`

Under this shape, the new `SendableIO<NewE>` constructed in `mapError` is
region-fresh, and the `sending` return is legal. Cost: the leaf error must
be `Sendable` at the type level, and every closure used to build a
`SendableIO` must be `@Sendable`. This is not a mapError technique — it is
a change to `IO`'s definition.

### V4 — `sending` helper (withSendingIO)

Two diagnostics, on both sides of the helper:

At the helper body:

```
error: task or actor-isolated value cannot be sent
  at `return IO<NewE>( ... )`
```

At the caller (mapErrorV4):

```
error: sending value of non-Sendable type 'IO<LeafError>' risks causing
       data races  [#SendingRisksDataRace]
  note: Passing task-isolated value of non-Sendable type 'IO<LeafError>'
        as a 'sending' parameter to global function 'withSendingIO(_:transform:)'
        risks causing races inbetween task-isolated uses and uses reachable
        from 'withSendingIO(_:transform:)'
```

The trick pushes the problem one frame up. `IO<LeafError>` is not
`Sendable`, so the caller cannot form a `sending` argument even with
`consume self`. And inside the helper, even if a `sending` argument arrived,
the non-`@Sendable` stored closures re-taint the new struct's region.

### V5 — fresh closure literals with `[self]` captures

Diagnostic:

```
error: task or actor-isolated value cannot be sent
  at `return IO<NewE>( ... )` after `[self]` capture list
```

A "fresh" closure literal still captures `self` — the capture list and the
method call `self._read(...)` in the body both bring `self` into the
closure. Region analysis follows captures, not textual novelty.

## Analysis

The underlying invariant: **region is a property of closure captures and of
the enclosing value's declared Sendability, not of the textual construction
site**. `consume self`, fresh closure literals, `sending` helpers, and
`@Sendable` wrappers all operate at the syntactic surface; none rebase the
region of a closure whose storage type is not `@Sendable`.

The only way to produce `sending IO<NewError>` from `IO<LeafError>` is to
make the witness's stored closures `@Sendable`, which in turn requires the
error type to be `Sendable`. Equivalently: there is no "free" mapError to a
sending return. Either:

1. Accept that `mapError` returns a non-sending `IO<NewError>` (callers who
   need sending must assemble a fresh witness from sending-safe pieces), or
2. Constrain `LeafError: Sendable` and declare all closures `@Sendable` at
   the struct definition (V3 shape).

This result **survives** the swift-witnesses macro change (verbatim names, no
deprecation). The macro-generated shape would be equivalent: the region
behavior comes from Swift's region analysis of non-`@Sendable` stored
closures, independent of how those storage slots are produced.

## Implications

- The REFUTED verdict from `swift-primitives/Experiments/io-witness-generic-error`
  is reinforced. `mapError` on the capability witness cannot produce a
  `sending` return without paying the Sendable-on-leaf-error cost.
- If the capability must be `sending`-returnable (e.g., for actor-crossing
  or `Task.init(sending:)` assembly), adopt the V3 shape at the struct
  definition — do not attempt to retrofit via mapError gymnastics.
- For leaf errors that are already `Sendable` (most of the ecosystem's error
  enums are `Sendable` by synthesis), the V3 shape costs only the
  `@Sendable` annotation on the stored closures. That is likely cheap in
  practice; it is expensive only philosophically (violates the "no explicit
  Sendable constraint" preference on generic parameters).

## Related

- `swift-primitives/Experiments/io-witness-generic-error/` — earlier REFUTED
  result on mapError returning `sending`
- `swift-foundations/swift-io/Research/io-witness-capability-runner-split.md`
  — error mapping identified as an orthogonal enabler
- `feedback_no_sendable_constraint_workaround.md` — general preference
  against adding `Sendable` constraints as workarounds
