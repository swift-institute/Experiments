# io-witness-tokio-style

<!-- status: CONFIRMED -->

## Hypothesis

Tokio's `AsyncRead` / `AsyncWrite` split — separate traits per capability — translates to Swift witnesses as three `@Witness` structs (`Reader`, `Writer`, `Closer`). Compiles cleanly, each witness is independently substitutable, but consumers that need more than one capability must thread multiple parameters or consume a bundle struct. There is no single-type spelling for "Reader + Writer" without a combining type.

## Method

Compile-only sketch. Declares three `@Witness` structs and a plain `ReadWriteClose` bundle. Two consumer functions demonstrate the spectrum: `drain` takes only `Reader`; `proxy` takes the full bundle.

Build command:
```bash
cd Experiments/io-witness-tokio-style
swift build
```

## Result

**CONFIRMED** (Swift 6.3 release, macOS 26 arm64, 2026-04-17).

Build output:
```
[1998/2000] Linking io-witness-tokio-style
Build complete! (106.98s)
```

Three `@Witness` structs and the bundle compile cleanly. Build time is significant (~107s) due to three macro expansions in one file.

The split-witness shape is ergonomically clean for single-capability consumers (`drain(reader:)` takes just `Reader`) but forces all-or-bundle for multi-capability consumers. In swift-sockets' actual call patterns (accept → read → write → close are invariably used together on a connection), the bundle is the common case — which means the split is paying extra surface area for substitution granularity that is rarely exercised independently.

## Analysis

The split-witness shape is useful when consumers genuinely only need one capability (e.g., a pure consumer of an `AsyncSequence` only needs `Reader`). The cost is every multi-capability consumer either takes all three parameters or takes the bundle. Compared to a single unified `IO` witness, this is slightly more work at API surface but adds granular substitution (a test can fake just the Writer).

Compared to Shape F: Shape F has ONE capability witness `IO` that carries read/write/close/ready together. Tokio-style splits those into 3–4 witnesses. Shape F wins for uniformity; tokio-style wins for test granularity. In swift-sockets' actual usage, the capability set is always used together (accept → read → write → close), so Shape F's bundled shape fits better.

## Related research

- `swift-foundations/swift-io/Research/io-vs-nio-comparative-analysis.md` — Tokio row in the comparison table
- Rust `tokio::io::AsyncRead` / `AsyncWrite` trait definitions

## Migration note (2026-04-16)

Closure storage dropped the underscore prefix to match the updated `@Witness` macro, which now generates sibling call-through methods alongside the non-underscored properties. `IO.Reader._read` → `IO.Reader.read`, `IO.Writer._write` → `IO.Writer.write`, `IO.Closer._close` → `IO.Closer.close`. Consumer call sites in `main.swift` / `Demo` were unchanged — they already invoked the macro-generated methods (`reader.read(from:into:)`, `writer.write(to:from:)`). Verified with `swift build` (clean rebuild succeeds).
