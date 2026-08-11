# io-witness-domain-generic-substrate

<!-- status: CONFIRMED, but REDUNDANT with io-witness-domain-via-map -->

## Hypothesis

A domain witness generic over the IO substrate — `SocketIO<Substrate: Sendable>` — compiles on Swift 6.3 release. However, because protocols are forbidden, the generic `Substrate` parameter is **opaque**: consumer code cannot call `substrate.ready(...)` without a protocol constraint. The workaround is to store projection closures alongside the substrate, at which point the generic parameter buys little over just carrying the closures directly (as `io-witness-domain-via-map` does).

## Method

Compile-only sketch. Declares `IO` (concrete substrate) and `SocketIO<Substrate>` (generic over substrate), with a specialization to `SocketIO<IO>`. Shows that the substrate is opaque — accept must be implemented via an explicit `(borrowing Substrate, borrowing Descriptor) async throws(IOError) -> Descriptor` closure stored on the `SocketIO`.

Build command:
```bash
cd Experiments/io-witness-domain-generic-substrate
swift build
```

## Result

**CONFIRMED (compile-wise); REDUNDANT in practice** (Swift 6.3 release, macOS 26 arm64, 2026-04-17).

Build output:
```
[6/8] Linking io-witness-domain-generic-substrate
Build complete! (0.65s)
```

`SocketIO<Substrate: Sendable>` compiles with the substrate stored as a field and a projection closure stored alongside. As predicted, `Substrate` is opaque — the projection closure IS the substrate's exposed API. Effectively this is `io-witness-domain-via-map` with an extra storage field and an extra type parameter buying nothing.

Recommendation: prefer `io-witness-domain-via-map` (closure capture of the substrate inside the domain witness's own closures) over this shape.

## Analysis

Expected CONFIRMED for compile, but the shape is REDUNDANT compared to `io-witness-domain-via-map`. The map shape captures substrate ops directly in the domain witness's closures (closure capture). The substrate-generic shape stores the substrate explicitly plus projection closures. They achieve the same runtime behavior but the map shape is simpler because it drops the generic parameter.

Recommendation after this experiment: prefer `io-witness-domain-via-map` (non-generic closure capture) over `io-witness-domain-generic-substrate` (generic with explicit projection) unless a future language feature lets us constrain `Substrate` without a protocol.

## Related research

- `swift-foundations/swift-io/Research/io-witness-capability-runner-split.md`

## Migration note (2026-04-16)

Dropped `_` prefix from closure-storage properties per institute naming conventions. `IO._read/_write/_ready/_close` → `IO.read/write/ready/close`; `Socket.IO._accept` → `Socket.IO.accept`. The stored closure `accept` now shadows the `accept(on:)` method inside its own body, so the forwarding method disambiguates via `self.accept(substrate, listener)`. Consumer call site in the `.on(_:)` specialization updated (`substrate._ready` → `substrate.ready`). Build: `Build complete! (0.51s)`.
