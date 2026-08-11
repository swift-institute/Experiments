//
// Purpose: Emulate Scala ZIO's `ZIO[R, E, A]` three-parameter shape as a
//   Swift value type. R = environment/capability, E = error, A = result.
// Hypothesis: Swift 6.3 region-based isolation may eliminate the original
//   `R: Sendable` constraint via `sending` parameters. If so, `~Copyable`
//   descriptors become viable as R, since `sending` transfers ownership of
//   a region across an isolation boundary without requiring Sendable.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Date: 2026-04-17
//

// ============================================================================
// MARK: - IO<R, E, A> — ZIO-style three-parameter effect monad
// ============================================================================

public struct IO<R, E: Error, A> {
    public let run: (R) async throws(E) -> sending A

    public init(_ run: @escaping (R) async throws(E) -> sending A) {
        self.run = run
    }
}

// ============================================================================
// MARK: - Combinators: map / flatMap / mapError / provide
// ============================================================================

extension IO {
    public func map<B>(_ f: @escaping (sending A) -> sending B) -> IO<R, E, B> {
        IO<R, E, B> { (r: R) async throws(E) -> sending B in
            try await f(self.run(r))
        }
    }

    public func flatMap<B>(_ f: @escaping (sending A) -> IO<R, E, B>) -> IO<R, E, B> {
        IO<R, E, B> { (r: R) async throws(E) -> sending B in
            let a = try await self.run(r)
            return try await f(a).run(r)
        }
    }

    public func mapError<F: Error>(_ f: @escaping (E) -> F) -> IO<R, F, A> {
        IO<R, F, A> { (r: R) async throws(F) -> sending A in
            do throws(E) {
                return try await self.run(r)
            } catch {
                throw f(error)
            }
        }
    }

    public func provide(_ env: sending R) -> IO<Void, E, A> {
        IO<Void, E, A> { (_: Void) async throws(E) -> sending A in
            try await self.run(env)
        }
    }
}
