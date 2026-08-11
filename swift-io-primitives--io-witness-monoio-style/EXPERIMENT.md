# io-witness-monoio-style

<!-- status: CONFIRMED -->

## Hypothesis

The monoio (Rust io_uring runtime) "rental" buffer pattern — `read(fd, buf) -> (buf, count)` — translates to Swift as a witness closure taking `consuming Buffer` and returning `(Buffer, Int)`. Compiles on Swift 6.3 release. The ergonomic cost in buffer-reuse loops is the required re-bind of `buf` from the returned tuple on every iteration.

## Method

Compile-only sketch. Hand-writes an `IO` struct whose read/write closures take `consuming Buffer` and return `(Buffer, Int)`. A sample `readLoop` function iterates N times, re-binding `buf = returnedBuf` each cycle.

Build command:
```bash
cd Experiments/io-witness-monoio-style
swift build
```

## Result

**CONFIRMED** (Swift 6.3 release, macOS 26 arm64, 2026-04-17).

Build output:
```
[6/8] Linking io-witness-monoio-style
Build complete! (0.58s)
```

The rental shape with `consuming Buffer` parameter and `(Buffer, Int)` tuple return compiles. The sample `readLoop(io:fd:iterations:)` demonstrates the `buf = returnedBuf` re-bind pattern on every iteration.

Note: this sketch uses a Sendable `Buffer` struct rather than `~Copyable` Buffer because the `(Buffer, Int)` tuple would not be representable with `~Copyable Buffer` (same tuple-noncopyable limit encountered in `io-witness-domain-via-map`). Monoio's real Rust equivalent has the compiler-enforced move semantics for free; in Swift, the sketch demonstrates the SHAPE — a real implementation would return a named `~Copyable` struct bundling the buffer + count.

## Analysis

Monoio's rental pattern is motivated by io_uring's buffer-ownership contract: the kernel holds the buffer pointer from SQE submission to CQE consumption. Returning the buffer in the result signals "the kernel is done with it; here's your buffer back."

Swift alternatives that achieve the same safety:
1. **Current swift-io approach**: borrow Memory.Buffer with a documented "stable address until try await returns" contract. Multi-CQE cancel handshake ensures buffer is not freed mid-flight. No re-bind required.
2. **Monoio rental approach (this sketch)**: consume Buffer, return Buffer in tuple. Compile-time safe but requires re-bind every call.

Verdict: the rental approach is more pedantically correct at the type level, but swift-io's approach with the cancellation handshake achieves equivalent safety with better ergonomics. Rental is **rejected** on ergonomic grounds.

## Related research

- monoio and glommio Rust documentation
- `swift-foundations/swift-io/Research/io-proactor-buffer-ownership.md` — swift-io's cancellation handshake alternative
- `swift-foundations/swift-io/Sources/IO Core/IO.swift:37–71` — stable-address contract

## Migration note (2026-04-16)

Dropped the underscore prefix on the closure storage: `_read`/`_write` → `read`/`write`. Because Swift synthesizes call-as-method for closure-typed properties, the forwarding extension methods (`read(from:into:)`, `write(to:from:)`) were redundant once the storage names matched the desired call surface; both extension methods were removed. The consumer `readLoop` call site switched from labelled `io.read(from: fd, into: consume buf)` to positional `io.read(fd, consume buf)` to match the closure's own parameterless signature. Rental-shape semantics preserved: `consuming Memory.Buffer` parameter, `(Memory.Buffer, Int)` tuple return, `Memory.Buffer: Sendable`, and the re-bind loop demo are unchanged. Verified `swift build` still succeeds.
