// Eio.with(stdenv:_:) — scope-based entry point. Mirrors OCaml's
// `Eio_main.run { env -> ... }` main-program style.
//
// The `sending R` return annotation is load-bearing: without it the compiler
// rejects the closure's return value as region-mixing when R is non-Sendable.

extension Eio {
    public static func with<R, E: Swift.Error>(
        stdenv env: Stdenv,
        _ body: (Stdenv) async throws(E) -> sending R
    ) async throws(E) -> sending R {
        try await body(env)
    }
}
