//
// Monad + Functor structure: pure, map, flatMap, andThen.
// Plain algebra. No @Sendable, no sending, no Sendable constraints.
//
// Closure literals carry explicit `(env) async throws(L) -> V in`
// annotations because Swift 6.3 cannot infer typed throws through
// generic closure literals.
//

extension IO {

    public static func pure(_ value: consuming Value) -> IO<Environment, LeafError, Value> {
        IO { [value] (_: borrowing Environment) async throws(LeafError) -> Value in
            value
        }
    }

    public func map<New>(
        _ transform: @escaping (consuming Value) -> New
    ) -> IO<Environment, LeafError, New> {
        let run = self.run
        return IO<Environment, LeafError, New> { (env: borrowing Environment) async throws(LeafError) -> New in
            transform(try await run(env))
        }
    }

    public func flatMap<New>(
        _ transform: @escaping (consuming Value) -> IO<Environment, LeafError, New>
    ) -> IO<Environment, LeafError, New> {
        let run = self.run
        return IO<Environment, LeafError, New> { (env: borrowing Environment) async throws(LeafError) -> New in
            let value = try await run(env)
            return try await transform(value).run(env)
        }
    }

    public func andThen<New>(
        _ next: IO<Environment, LeafError, New>
    ) -> IO<Environment, LeafError, New> {
        let run = self.run
        let nextRun = next.run
        return IO<Environment, LeafError, New> { (env: borrowing Environment) async throws(LeafError) -> New in
            _ = try await run(env)
            return try await nextRun(env)
        }
    }
}
