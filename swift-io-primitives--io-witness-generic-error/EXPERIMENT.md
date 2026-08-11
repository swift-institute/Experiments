# io-witness-generic-error

<!-- status: CONFIRMED -->

## Hypothesis

A hand-written `IO<LeafError: Error & Sendable>` struct with `throws(LeafError)` closures compiles on Swift 6.3 release. It supports `~Copyable` descriptor parameters and `Sendable` conformance. A `mapError(_:)` extension produces a new `IO<NewError>` that wraps the original error via a user-supplied transform — enabling domain packages to specialize the error vocabulary (`IO<Sockets.Error>`, `IO<File.Error>`) from a base `IO<GenericIOError>`.

## Method

Compile-only sketch. Hand-writes `IO<LeafError>` without the `@Witness` macro (since the macro does not propagate generic parameters — see `io-witness-macro-generic-compat`). Declares three error taxonomies (`GenericIOError`, `SocketError`, `FileError`) and derives `IO<SocketError>` and `IO<FileError>` from `IO<GenericIOError>` via `mapError`.

Build command:
```bash
cd Experiments/io-witness-generic-error
swift build
```

## Result

**CONFIRMED** (Swift 6.3 release, macOS 26 arm64, 2026-04-17).

Build output:
```
[6/8] Linking io-witness-generic-error
Build complete! (0.98s)
```

`IO<LeafError: Error & Sendable>` compiles with `~Copyable` descriptor parameters. `mapError(_:)` produces `IO<NewError>` from `IO<LeafError>` via two `do throws(LeafError) { ... } catch { throw transform(error) }` blocks (one per operation closure). The `close` closure is error-agnostic so it is forwarded directly.

Note: given the surprise result from `io-witness-macro-generic-compat`, this same shape could also be expressed with `@Witness public struct IO<LeafError: Error & Sendable>` and rely on the macro. The hand-written form remains useful as the reference implementation.

## Analysis

If CONFIRMED: error-generic witnesses are viable. Open question then: is the generic parameter viral through consumer APIs? Function signatures like `func foo(io: IO<SocketError>)` spell the error type at every call site. Whether this is annoying in practice is a separate ergonomics experiment (deferred).

If the hypothesis holds, this shape can layer on top of the Shape F capability/runner split — the capability is `IO<LeafError>` and the runner is `IORunner` (error-agnostic). Together: `IOBound<LeafError>` — generic bundle.

## Related research

- `swift-foundations/swift-io/Research/io-witness-capability-runner-split.md`
- `swift-foundations/Research/nio-inspired-capability-additions.md` — mentions error mapping as an orthogonal enabler

## Migration to non-underscored storage

Migrated 2026-04-16 for canonical-style consistency with the new convention: closure-property names drop the leading underscore. Since this sketch is hand-written (no `@Witness` macro), the migration is purely stylistic — no macro behavior changed.

Changes in `IO.swift`:

- Renamed stored closure properties `_read` / `_write` / `_close` → `read` / `write` / `close` (declarations, init parameter assignments).
- The hand-written forwarding methods `read(from:into:)`, `write(to:from:)`, `close(_:)` collided with the renamed closure properties (same base name `read` / `write` / `close`). Per the migration plan's simplest-path recommendation, the forwarding methods were dropped. Consumer call sites invoke the closure-properties directly — Swift's labeled closure call syntax `io.read(from: fd, into: buf)` works because the closure type carries argument labels.
- Updated `mapError` body to call `self.read(fd, buf)` and `self.write(fd, buf)` in place of the former `self._read` / `self._write`, and forwards `self.close` directly.

Build verified:

```
[9/11] Linking io-witness-generic-error
[10/11] Applying io-witness-generic-error
Build complete! (0.55s)
```
