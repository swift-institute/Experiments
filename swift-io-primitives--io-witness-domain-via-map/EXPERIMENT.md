# io-witness-domain-via-map

<!-- status: CONFIRMED, with one caveat -->

## Hypothesis

A domain-specific witness (`Socket.IO`) can be constructed from the generic `IO` via an `io.map { io -> Socket.IO in ... }` composition. The resulting `Socket.IO`:

1. Compiles on Swift 6.3 release with `~Copyable` descriptor parameters and typed throws.
2. Requires no SPI into the `IO` substrate's backing actor.
3. Works across all three strategies (blocking / events / completions) because `io.ready` carries strategy-specific semantics internally and the post-ready sync syscall runs on the caller's pinned executor via the shared-executor pattern.

## Method

Compile-only sketch. Declares `IO` and `Socket.IO` as two `@Witness` structs, an `extension IO { func map(...) }`, and a `makeSocketIO(from:)` factory that wires `Socket.IO`'s closures to call `io.ready` plus a simulated accept syscall.

Build command:
```bash
cd Experiments/io-witness-domain-via-map
swift build
```

## Result

**CONFIRMED** (Swift 6.3 release, macOS 26 arm64, 2026-04-17).

Build output:
```
[5/7] Linking io-witness-domain-via-map
Build complete! (1.33s)
```

**Caveats encountered**:

1. **Tuples with `~Copyable` elements are unsupported**. Attempting `async throws(IOError) -> (Descriptor, PeerAddress)` where `Descriptor` is `~Copyable` fails with "tuple with noncopyable element type 'Descriptor' is not supported". This sketch falls back to Copyable `Descriptor` to keep the focus on composition. A real `Socket.IO` would wrap the accept result in a named `~Copyable` struct (`Socket.Accepted`).
2. **Typed-throws inference** from closure literal parameters is fragile. Explicit closure-parameter type annotations (`{ (listener: borrowing Descriptor) async throws(IOError) -> T in ... }`) are required when the closure is used as a `SocketIO`-init argument; the `_` form fails inference.
3. **Unified error type** (IOError used for both the generic and socket-domain) keeps the sketch simple. A real two-layer error hierarchy (SocketError wrapping IOError) requires either typed-throws-aware catch blocks or further explicit annotations.

## Analysis

If CONFIRMED: the SPI escape hatch proposed in `io-witness-capability-runner-split.md` is not strictly necessary for socket domain composition. The trade-off is a two-round-trip for proactor accept (POLL_ADD + sync accept instead of `IORING_OP_ACCEPT`). This is orthogonal to the witness shape and can be optimized later by extending the factory, not the API.

## Related research

- `swift-foundations/swift-io/Research/io-witness-capability-runner-split.md`
- `swift-foundations/swift-io/Research/perfect-api.md` (Tier 0 — affects the `map` signature)

## Migration to non-underscored storage

2026-04-16: Migrated closure storage in `IO` and `Socket.IO` from underscored (`_read`, `_write`, `_close`, `_ready`, `_accept`, `_connect`, `_shutdown`) to non-underscored (`read`, `write`, `close`, `ready`, `accept`, `connect`, `shutdown`). The swift-witnesses macro no longer strips underscores and now generates labeled methods as siblings of labeled closure-properties; call sites in the `.map` body (e.g., `io.ready(from:interest:)`) are unchanged because the synthesized labeled-method name matches both before and after migration. No zero-arg closures in this experiment. Build: `Build complete! (2.58s)` on Swift 6.3 release.
