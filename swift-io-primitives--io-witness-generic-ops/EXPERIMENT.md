# io-witness-generic-ops

<!-- status: CONFIRMED -->

## Hypothesis

A hand-written `IO<Ops: Sendable>` struct carrying an operation-set record as a stored property compiles on Swift 6.3 release. The generic parameter propagates virally through consumer APIs — every function taking an `IO<SocketOps>` names the specialization, and there is no protocol-free opaque spelling that covers "some IO with any ops".

## Method

Compile-only sketch. Declares `IO<Ops>`, two concrete ops records (`SocketOps`, `FileOps`), and three consumer functions:

1. `runEchoServer(listener:io:)` — specialized to `IO<SocketOps>`.
2. `compactFile(fd:io:)` — specialized to `IO<FileOps>`.
3. `runBoth(...)` — takes both `IO<SocketOps>` and `IO<FileOps>` — the virality is visible here.

Build command:
```bash
cd Experiments/io-witness-generic-ops
swift build
```

## Result

**CONFIRMED** (Swift 6.3 release, macOS 26 arm64, 2026-04-17).

Build output:
```
[6/8] Linking io-witness-generic-ops
Build complete! (0.67s)
```

`IO<Ops: Sendable>` compiles with `SocketOps` and `FileOps` as distinct specializations. Consumer functions like `runEchoServer(listener:io:)` and `compactFile(fd:io:)` explicitly name `IO<SocketOps>` / `IO<FileOps>` — virality of the generic parameter is confirmed at every call site. No opaque `some` spelling covers both because that would require a protocol, which is forbidden.

Ergonomic mitigation at the domain-package level: `public typealias Sockets.IO = IO<SocketOps>` and `public typealias File.IO = IO<FileOps>` — this hides the generic at the consumer surface but does not eliminate it from the underlying type. Each domain package names its own specialization once and exports the alias.

## Analysis

If CONFIRMED (expected): shape compiles, but the ergonomic cost is real — every consumer names `IO<X>` explicitly. This rules out `IO<Ops>` as a single-type spelling that crosses domains. Possible mitigation: typealias `Sockets.IO = IO<SocketOps>` and `File.IO = IO<FileOps>` at domain-package level. Documentation footprint grows.

If REFUTED (surprise): compile error would show Sendable or type-parameter issues that need diagnosis.

## Related research

- `swift-foundations/swift-io/Research/io-witness-capability-runner-split.md` — contextualizes this alternative to the non-generic Shape F.

## Migration to non-underscored storage

2026-04-16: Migrated closure-storage properties and init parameters on `Socket.Ops` and `File.Ops` from underscored (`_accept`, `_connect`, `_read`, `_write`, `_close`, `_seek`, `_pread`, `_pwrite`, `_fsync`) to non-underscored (`accept`, `connect`, `read`, `write`, `close`, `seek`, `pread`, `pwrite`, `fsync`). Purely cosmetic alignment with the new canonical style used by the `@Witness` macro; this experiment is a hand-written sketch, so the change was a direct rename of stored-property declarations, init parameter labels, init-body bindings, and call sites in `main.swift` / `Socket.swift` / `File.swift`. `IO<Ops>` generic shape, `sending IO<...>` consumer parameters, and the virality demonstration are preserved. Rebuild confirmed clean (`Build complete! (0.49s)`).
