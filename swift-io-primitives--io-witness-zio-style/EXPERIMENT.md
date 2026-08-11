# io-witness-zio-style

<!-- status: CONFIRMED, with significant caveats -->

## Hypothesis

Scala ZIO's `ZIO[R, E, A]` three-parameter effect monad (R = environment, E = error, A = result) translates to Swift 6.3 as `IO<R: Sendable, E: Error, A: Sendable>`. Compiles and supports `map`, `flatMap`, `mapError`, `provide` combinators. **Critical limitation**: the environment `R` must be `Sendable` — ~Copyable descriptors cannot serve as `R` without relaxing ownership semantics. This makes the shape unsuitable as a drop-in for swift-io's file-descriptor-based capability surface.

## Method

Compile-only sketch. Hand-writes `IO<R, E, A>` with four combinators. Demonstrates a pipeline: `readSome(count:).map.flatMap.mapError.provide(env)`.

Build command:
```bash
cd Experiments/io-witness-zio-style
swift build
```

## Result

**CONFIRMED** (Swift 6.3 release, macOS 26 arm64, 2026-04-17).

Build output:
```
[5/7] Linking io-witness-zio-style
Build complete! (0.35s)
```

`IO<R: Sendable, E: Error & Sendable, A: Sendable>` compiles with `map`, `flatMap`, `mapError`, `provide` combinators. **Every combinator closure required explicit typed-throws annotation** — `{ r in try await ... }` fails with "invalid conversion of thrown error type 'any Error' to 'E'" because Swift does not infer the closure's typed-throws from the enclosing generic context. All four combinators use the form `{ (r: R) async throws(E) -> B in ... }`.

This is a significant ergonomic cost for a shape intended to be combinator-heavy. Users would pay it on every combinator definition — the whole point of ZIO-style is chainable combinators, and Swift's current typed-throws inference makes the chain verbose.

Combined with the Sendable-R constraint (ruling out `~Copyable` descriptors), this shape is **unsuitable** as swift-io's core capability.

## Analysis

ZIO's strength is uniform error and environment tracking in pure-computation monads. The weakness for our use case is:

1. **Environment must be Sendable** — forbids ~Copyable descriptors. The environment would have to carry raw integer file descriptors and lose the ownership discipline.
2. **No executor binding** — ZIO's "runtime" (equivalent to the R parameter when fully provided) does not correspond to Swift's `SerialExecutor` / `UnownedSerialExecutor` concept. There is no `io.unownedExecutor` spelling to enable the shared-executor pattern (TCA26).
3. **Monad combinators (map/flatMap) introduce per-call allocation for captured closures** — measurable cost vs direct witness-of-closures.

Expected verdict: compiles, elegant for pure computations, **unsuitable** as swift-io's core capability. May be useful as a higher-level composition layer on top of a witness-based IO (e.g., wrap IO calls in `IO<IOBound, IOError, Int>.readSome(...)` for a domain DSL).

## Related research

- ZIO paper and Scala library documentation
- `swift-foundations/swift-io/Research/io-vs-nio-comparative-analysis.md` — positions swift-io against effect systems generally

## Migration note (2026-04-16)

Audited for the underscored-to-non-underscored closure-storage migration: **no rename needed**. The sole stored closure in `IO<R, E, A>` was already declared as `public let run: (R) async throws(E) -> sending A` (not `_run`), and every combinator (`map`, `flatMap`, `mapError`, `provide`) already calls `self.run(...)`. `swift build` succeeds unchanged.
