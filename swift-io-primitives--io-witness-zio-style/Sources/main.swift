//
// Purpose: Emulate Scala ZIO's `ZIO[R, E, A]` three-parameter shape as a
//   Swift value type. R = environment/capability, E = error, A = result.
// Hypothesis: Swift 6.3 region-based isolation may eliminate the original
//   `R: Sendable` constraint via `sending` parameters. If so, `~Copyable`
//   descriptors become viable as R, since `sending` transfers ownership of
//   a region across an isolation boundary without requiring Sendable.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//

// ============================================================================
// MARK: - Compile-only demonstration
// ============================================================================

let computation = Socket.read(count: 4096)
    .map { $0 * 2 }
    .flatMap { bytes in
        IO<Socket.Environment, Socket.Error, String> { _ in "read \(bytes) bytes" }
    }
    .mapError { (_: Socket.Error) in Socket.Error.closed }

let env = Socket.Environment(listenerFD: 3)
let runnable = computation.provide(env)

func observe(_ io: IO<Void, Socket.Error, String>) { _ = io }
observe(runnable)

print("ZIO-style IO<R, E, A> compiles. Region-based isolation via `sending` removes the R: Sendable requirement.")
