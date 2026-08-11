# Witness Recording Against Non-Underscored Properties

<!--
---
version: 1.0.0
last_updated: 2026-04-16
status: CONFIRMED (all five operators)
---
-->

## Hypothesis

All five swift-witnesses composition operators — `Witness.Recording`,
`Witness.Scope`, `Witness.Values`, `Witness.Sequence`, `Witness.Cycle` — wrap
a `@Witness` value transparently when the stored closure's property name is
**not** underscore-prefixed. The V4 "property-wins" finding from the
[witness-property-method-collision](../../../swift-witnesses/Experiments/witness-property-method-collision/)
experiment only bites on same-signature method+property collisions, which none
of these operators synthesise.

If REFUTED for any operator, the zoo migration and downstream packages would
need to keep underscore prefixes selectively — or invent a workaround.

## Background

The swift-witnesses macro was recently changed so that underscore-prefixed
closure storage is **optional**. The empirical study in
`witness-property-method-collision` (V6 / V7) showed:

- **Labeled closure, non-underscored storage** → the macro generates a
  labeled method as a sibling of the stored-closure property. Both call
  syntaxes coexist because their Swift names differ (`log` vs `log(message:)`).
- **Zero-arg closure, non-underscored storage** → the macro generates only
  the property (a synthesised zero-arg method would collide by Swift name).
- **Underscored storage** → unchanged; the deprecation attribute still
  points at the stripped-name labeled method for backwards compatibility.

This leaves an open question: do the existing **composition operators** in
the Witnesses module still wrap correctly when storage uses non-underscored
names? The downstream shape zoo and the IO migration depend on the answer.

## Methodology

A single executable target (`witness-recording-against-properties`) under
`swift-io/Experiments/` depends on the `swift-witnesses` package via a
`.package(path:)` reference. The subject is a minimal witness with one
non-underscored labeled closure:

```swift
@Witness
public struct Logger: Sendable {
    public let log: @Sendable (_ message: String) -> Void
}

extension Logger: Witness.Key {
    public static var liveValue: Logger { Logger(log: { _ in }) }
}
```

Each variant exercises one operator through both the stored-closure syntax
(`logger.log("…")`) and the macro-synthesised labeled method
(`logger.log(message: "…")`) so any collision surfaces in whichever path
it would affect. Compile success alone would satisfy the hypothesis;
runtime preconditions are added as bonus verification that the wrapping
actually routes calls through the custom closures.

Toolchain: Swift 6.3 (package declares `// swift-tools-version: 6.3`).
Platform: macOS 26 (arm64).
Build command: `swift build` from the experiment directory. Log captured
at `/tmp/witness-recording-against-properties.log`.

## Results

| Variant | Operator | Compile | Runtime | Notes |
|---------|----------|---------|---------|-------|
| V1 | `Witness.Recording<String>` | ✓ | ✓ (2 calls recorded) | Closure literal assignable to non-underscored `log` property |
| V2 | `Witness.Scope(values:)` | ✓ | ✓ (2 calls routed) | `scope.run { … }` consumed; `Witness.Context.current[Logger.self]` retrieves custom Logger |
| V3 | `Witness.Values` subscript | ✓ | ✓ (2 calls routed) | `values[Logger.self] = …` typechecks via `Logger: Witness.Key`; round-trip preserves the closure |
| V4 | `Witness.Sequence<String>` | ✓ | ✓ (4 calls, last element saturates) | `callAsFunction()` composes inside the `log` closure literal |
| V5 | `Witness.Cycle<String>` | ✓ | ✓ (4 calls, wrap-around) | Same compositional shape as Sequence |

```
== Witness Recording Against Non-Underscored Properties ==
V1 Witness.Recording — OK (2 calls)
V2 Witness.Scope — OK (2 calls)
V3 Witness.Values — OK (2 calls)
V4 Witness.Sequence — OK (4 calls)
V5 Witness.Cycle — OK (4 calls)
All five operators composed with non-underscored storage.
```

No diagnostics surfaced against the experiment sources. The only build
warnings originate in `WitnessMacro.swift` (unused locals at lines 238 /
239) and in an unrelated `swift-storage-primitives` resource declaration —
both pre-existing and independent of this experiment.

## Analysis

### Why the operators are indifferent to storage naming

None of the five operators inspects the witness struct's synthesised member
names directly. Their entry points are:

1. **`Witness.Recording<Args>`** — a free-standing recorder the consumer
   feeds from inside a closure literal. It only sees `Args`.
2. **`Witness.Values`** — keyed subscript on the `Witness.Key`
   conformance. The key is the witness type, not its internal property.
3. **`Witness.Scope`** — wraps a `Witness.Values` and runs a caller-provided
   operation; the operation fetches the witness out of `Witness.Context`
   by key, not by property name.
4. **`Witness.Sequence<T>` / `Witness.Cycle<T>`** — producers with
   `callAsFunction()`. They are composed inside the closure body and have
   no knowledge of the surrounding witness struct.

In every case, the call-site syntax that *would* be sensitive to the
underscore-vs-not convention is the consumer's call on the witness
(`logger.log(...)`). That syntax is separately exercised in V1–V5 through
both the stored-closure form and the macro-synthesised labeled method —
both compile and both execute as intended.

### Relation to the V4 collision class

V4 in `witness-property-method-collision` showed that a property + method
with the *same* Swift name silently lets the property win at the call site.
None of the wrapping operators introduces such a same-signature synthesis
around the subject witness, so the V4 failure mode does not apply here.
The only risk class remaining — zero-arg closure + zero-arg method
collision (V5 in the peer experiment) — is a property of the subject
`@Witness` declaration, not of any operator, and is still correctly
rejected by the macro when it arises.

## Conclusion

**Hypothesis CONFIRMED for all five operators.**

Non-underscored closure storage is a safe default for downstream `@Witness`
subjects that participate in the existing composition / recording / scope /
values / sequence / cycle machinery. No operator requires the underscore
convention as a precondition. The zoo migration and downstream IO consumers
can drop the underscore prefix for labeled closures without losing access
to any operator.

The only mechanical reason to keep an underscore prefix on `@Witness`
storage remains the zero-parameter case — where dropping the underscore
would cause a redeclaration error between the property and a
macro-generated zero-arg method sharing the Swift name (V5 in the peer
experiment). That constraint is independent of the operators exercised
here.

## Next Steps

1. Proceed with non-underscored storage in the IO witness shape zoo
   migration for labeled-closure properties.
2. Retain underscore prefixes only where a zero-arg closure collides with
   a macro-synthesised method of the same Swift name.
3. Add a short note to `Research/io-witness-shape-zoo-comparative-analysis.md`
   citing this experiment as the compositional evidence.
