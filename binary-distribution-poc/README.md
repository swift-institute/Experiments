# Binary distribution POC

**Experiment date:** 2026-01-14 · **Category:** Architecture Patterns

Proof-of-concept for distributing Swift packages as binary artifacts: whether ecosystem L1
primitives can be shipped to downstream consumers as `.xcframework`s rather than as source.

Layout is a multi-target POC with **no single root `Package.swift`** — each consumer is its own
package:

- `test-consumer/` — consumes `IdentityPrimitives.xcframework` via `.binaryTarget`
- `test-numeric/` — consumes `NumericPrimitives.xcframework` via `.binaryTarget`
- `IdentityPrimitives.xcframework/`, `NumericPrimitives.xcframework/` — the distributed
  frameworks (module interfaces retained; see below)
- `identity/`, `numeric/` — per-target build outputs

## What was measured

The POC established that L1 primitives **can** be built as static archives, wrapped in an
`.xcframework` with their `.swiftmodule` / `.swiftinterface`, and consumed by a downstream
SwiftPM package through `.binaryTarget(path:)`. Both consumer packages above are the
demonstration of that consumption path, and their manifests and sources are unchanged.

**Toolchain of record:** Apple Swift **6.2.3** (`swiftlang-6.2.3.3.21`), macOS arm64.

## ⚠️ The compiled archives were removed on 2026-07-25

The five `lib*.a` static archives — three copies of `libIdentity_Primitives.a`, two of
`libNumeric_Primitives.a` — **have been deleted from this directory.** They embedded **128
absolute build paths** from the machine that produced them, in a public repository.

They were removed rather than rebuilt because **a faithful rebuild is not possible**:

1. **The original compiler is unavailable and disallowed.** The archives were built with Swift
   6.2.3; that toolchain is not installed, and pinning `TOOLCHAINS` to obtain it is prohibited
   by standing workspace policy. In an experiment about binary distribution, the compiler is a
   variable under test — rebuilding with a different one produces a different experiment, not a
   redacted artifact.
2. **Three of the five archives have no source.** `swift-identity-primitives` no longer exists
   anywhere in the workspace, so `libIdentity_Primitives.a` could only be fabricated from
   something else.
3. **The remaining source has moved on.** `swift-numeric-primitives` has advanced by 8 commits
   since 2026-01-14; a rebuild would compile different code under the same filename.
4. **No build invocation was ever recorded.** There is no script, `Makefile` or note giving the
   flags that produced these archives, so faithfulness could not be established even with the
   right compiler and source.

An artifact that can be neither regenerated nor verified is a relic rather than a
demonstration. **The finding above — what was built, how it was consumed, and that the path
works — is the part with lasting value, and it is preserved here in prose.**

### Consequence: the consumer packages no longer build

`test-consumer` and `test-numeric` are retained deliberately, as the record of the consumption
pattern. **Both now reference `.binaryTarget` paths whose libraries are absent**, so neither
resolves or builds as it stands. Restoring a runnable POC means rebuilding the archives from
current sources on the current toolchain and re-dating this as a new measurement — not
recovering the 2026-01-14 one.

### Residue: this cleared the working tree, not the history

**The removal clears the current tip only.** These archives are committed, so **all 128
occurrences remain in this repository's git history** and are reachable from earlier commits.
That residue is recorded as a known open item for a future history-disposal pass; it is **not**
resolved by this deletion, and `Experiments` should not be counted as fully cleared.
