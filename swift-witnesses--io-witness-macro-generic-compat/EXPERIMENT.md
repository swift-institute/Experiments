# io-witness-macro-generic-compat

<!-- status: REFUTED (in the SURPRISING direction — macro DOES handle generics) -->

## Hypothesis

The `@Witness` macro does **not** propagate generic parameters into synthesized members (init, `unimplemented()`, `Calls`, `Observe`). Applying `@Witness` to a generic struct `GenericIO<LeafError: Error>` should fail compilation with a diagnostic referring to an undeclared `LeafError` in one of the synthesized extensions.

If the experiment compiles successfully, the hypothesis is REFUTED in the opposite direction (the macro does handle generics — a useful and unexpected finding).

## Method

Compile-only sketch. Declares `@Witness public struct GenericIO<LeafError: Error>` with a single generic-error-typed closure, then attempts to construct `GenericIO<IOError>.unimplemented()`.

Build command:
```bash
cd Experiments/io-witness-macro-generic-compat
swift build 2>&1 | tee /tmp/io-witness-macro-generic-compat.log
```

## Result

**REFUTED in the SURPRISING direction** (Swift 6.3 release, macOS 26 arm64, 2026-04-17). The macro DOES propagate generic parameters — `@Witness public struct GenericIO<LeafError: Error & Sendable>` compiled cleanly, and `GenericIO<IOError>.unimplemented()` resolved as expected.

Build output:
```
[1997/2000] Linking io-witness-macro-generic-compat
Build complete! (90.77s)
```

**Implication**: the exploration finding that the macro "does not access `structDecl.genericParameterClause`" was misread. The macro expansion runs in the context of the original struct declaration, so generic parameters ARE in scope for the synthesized code even without the macro explicitly reading them — extensions on the generic struct use its parameters automatically.

This reshapes the downstream experiments: `io-witness-generic-error`, `io-witness-generic-ops`, `io-witness-domain-generic-substrate` could in principle all be macro-based instead of hand-written. Kept hand-written in this zoo to demonstrate the raw shape without macro sugar.

The 90.77s build time is notable — macro expansion over generic structs is expensive during a cold build but does not produce errors.

## Analysis

Either result is valuable. If CONFIRMED, the generic-variant experiments downstream (`io-witness-generic-error`, `io-witness-generic-ops`, `io-witness-domain-generic-substrate`) must be hand-written, not macro-based — which is exactly how they are scaffolded in this zoo. If REFUTED, all four generic variants can use the macro, collapsing the hand-written vs macro-based decision into a single choice.

## Related research

- `swift-foundations/swift-io/Sources/IO Core/IO.swift:92–98` — documents a related macro limitation (ownership annotations in mock synthesis).
- `swift-foundations/swift-witnesses/Sources/Witnesses Macros Implementation/WitnessMacro.swift` — macro expansion code; the exploration noted that `structDecl.genericParameterClause` is not accessed during expansion.

## Migration to non-underscored storage

Migrated 2026-04-16 following the swift-witnesses macro change that keeps closure-storage names verbatim (no underscore prefix) and generates labeled sibling methods only for labeled closures.

Change: renamed the single zero-arg closure `_op` → `op` on `IO<LeafError>`. The `@Witness` macro continues to propagate the generic parameter into synthesized members (init, `unimplemented()`, etc.), confirming the earlier surprising-direction finding still holds under the new naming convention.

No call sites required a `.op` → `.op()` rewrite: `main.swift` only constructs `IO<Sample.Error>.unimplemented()` and never invokes the closure, so the zero-arg no-synthesized-method rule did not surface here. A downstream consumer that reads `instance.op` to invoke the closure would now need to write `instance.op()` (closure call via the stored property) since no synthesized method exists for zero-arg closures.

Build: `swift build` succeeds in 2.31s (incremental, after the macro-host was already built).
