# io-witness-eio-style

<!-- status: CONFIRMED -->

## Hypothesis

OCaml Eio's `Stdenv.t` capability-bundle pattern translates to Swift as a plain `Stdenv` struct carrying three `@Witness` sub-capabilities (`NetCapability`, `FileCapability`, `ClockCapability`), entered via a `withStdenv(env) { env in ... }` scope function. Compiles on Swift 6.3 release. The scope form is clean for short-lived I/O but awkward when the capability must flow through longer-lived actor state.

## Method

Compile-only sketch. Declares three `@Witness` sub-capability structs, a plain `Stdenv` bundle, and an `IO.withStdenv` scope entry point.

Build command:
```bash
cd Experiments/io-witness-eio-style
swift build
```

## Result

**CONFIRMED** (Swift 6.3 release, macOS 26 arm64, 2026-04-17).

Build output:
```
[5/7] Linking io-witness-eio-style
Build complete! (1.23s)
```

Three `@Witness` sub-capability structs, a plain `Stdenv` bundle, and `IO.withStdenv` scope compile cleanly.

**Caveat encountered**: The `ClockCapability` with a zero-parameter closure (`_now: () -> UInt64`) did NOT get an auto-generated `now()` method from the `@Witness` macro — the macro requires at least one labeled parameter to synthesize a labeled forwarding method. A manual `extension ClockCapability { public func now() -> UInt64 { _now() } }` is required. This replicates swift-io's `_unownedExecutor` → `unownedExecutor` manual extension pattern (see `swift-io/Sources/IO Core/IO.swift:246–264`).

## Analysis

The scope form is natural for a CLI program's `main` entry point: `withStdenv(env) { env in ... }` mirrors OCaml's `Eio_main.run`. For a long-lived server where the capability is carried by actors that receive requests over time, the scope form forces artificial bookkeeping — actors must either be spawned inside the scope or receive `env` as a stored property, at which point it's equivalent to Shape F's `IOBound` being stored on the actor.

Verdict: scope form is sugar over capability-as-value; not a fundamentally different shape. Useful pattern, but subsumed by `IOBound`.

## Related research

- OCaml Eio library and Effect Handlers (ICFP 2022+)
- `swift-foundations/swift-io/Research/io-witness-design-literature-study.md` — mentions Eio as OCaml 5's effect-based I/O

## Migration note — non-underscored closure storage (2026-04-16)

Migrated the three `@Witness` sub-capabilities from the underscored closure-
storage convention (`_now`, `_connect`, `_open`) to the non-underscored form
(`now`, `connect`, `open`). Build remains clean on Swift 6.3.

**Key outcome — the manual `now()` forwarder is gone.** Previously, because the
`@Witness` macro only synthesises labeled forwarding methods for closures with
labeled parameters, the zero-arg `_now: () -> UInt64` on `Eio.Clock` forced a
hand-written `extension Eio.Clock { public func now() -> UInt64 { _now() } }`.
Under the new convention, the closure is stored directly as a property named
`now`, and the call site `env.clock.now()` is now a closure-call on that
property — no forwarding method needed, no extension to write. That entire
extension block was deleted outright. This is direct, measurable evidence of
the call-site convention change's value: the zero-arg-closure asymmetry between
macro-generated labeled methods and hand-written zero-arg forwarders collapses
into a single uniform "call the stored closure" idiom.

For the labeled closures (`Eio.Net.connect(host:port:)`, `Eio.File.open(path:)`),
the macro continues to synthesise the labeled methods as siblings of the
stored closure, so existing call sites are unchanged.

Files touched: `Sources/Eio.Clock.swift` (rename + delete manual extension),
`Sources/Eio.Net.swift` (rename), `Sources/Eio.File.swift` (rename).
Build: `swift build` clean in 3.14s on Swift 6.3, macOS 26 arm64, 2026-04-16.
