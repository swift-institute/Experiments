//
// Purpose: Emulate OCaml Eio's `Stdenv.t` pattern — a single bundle of nested
//   sub-capabilities (net, file, clock) passed to a scope closure. Tests
//   whether the effect-handler scope pattern competes with free-standing
//   value-type capability passing.
// Hypothesis: Compiles cleanly with @Witness for each sub-capability plus a
//   plain Eio.Stdenv bundle and an `Eio.with(stdenv:)` scope function. The
//   scope style forces all I/O into a single closure, which can be awkward
//   when the capability must survive across async boundaries (e.g., across
//   actor methods). Value-type capability passing (Shape F / domain-via-map)
//   is more ergonomic for Swift's structured concurrency.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//

// Construct an Eio.Stdenv (would be `Eio_main.run` in OCaml).
let env = Eio.Stdenv(
    net:   .unimplemented(),
    file:  .unimplemented(),
    clock: .unimplemented()
)

// Use the scope form.
let result: Void = try await Eio.with(stdenv: env) { env throws(IO.Error) in
    let t0 = env.clock.now()
    _ = t0
    // Real code: env.net.connect(host: "example.com", port: 443)
    //            env.file.open(path: "/tmp/data")
}
_ = result

print("Eio-style Stdenv with scope compiles. Scope closure awkward when capability must survive async boundaries.")
