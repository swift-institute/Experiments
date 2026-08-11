//
// Reader-monad structure: ask, provide, local.
//

extension IO {

    public func provide(
        _ env: consuming Environment
    ) -> IO<Void, LeafError, Value> {
        let run = self.run
        return IO<Void, LeafError, Value> { [env] (_: borrowing Void) async throws(LeafError) -> Value in
            try await run(env)
        }
    }

    public func local<WiderEnvironment>(
        _ narrow: @escaping (borrowing WiderEnvironment) -> Environment
    ) -> IO<WiderEnvironment, LeafError, Value> {
        let run = self.run
        return IO<WiderEnvironment, LeafError, Value> { (wider: borrowing WiderEnvironment) async throws(LeafError) -> Value in
            try await run(narrow(wider))
        }
    }
}

/// Produce the current environment as a value.
public func ask<Environment, LeafError: Swift.Error>()
    -> IO<Environment, LeafError, Environment>
{
    IO { (env: borrowing Environment) async throws(LeafError) -> Environment in
        copy env
    }
}
