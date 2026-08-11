//
// Error-channel operators: mapError, catchAll, orElse, recover.
//

extension IO {

    public func mapError<NewError: Swift.Error>(
        _ transform: @escaping (consuming LeafError) -> NewError
    ) -> IO<Environment, NewError, Value> {
        let run = self.run
        return IO<Environment, NewError, Value> { (env: borrowing Environment) async throws(NewError) -> Value in
            do throws(LeafError) {
                return try await run(env)
            } catch {
                throw transform(error)
            }
        }
    }

    public func catchAll(
        _ recover: @escaping (consuming LeafError) -> IO<Environment, Never, Value>
    ) -> IO<Environment, Never, Value> {
        let run = self.run
        return IO<Environment, Never, Value> { (env: borrowing Environment) async throws(Never) -> Value in
            do throws(LeafError) {
                return try await run(env)
            } catch {
                return await recover(error).run(env)
            }
        }
    }

    public func orElse(
        _ fallback: IO<Environment, LeafError, Value>
    ) -> IO<Environment, LeafError, Value> {
        let run = self.run
        let fallbackRun = fallback.run
        return IO<Environment, LeafError, Value> { (env: borrowing Environment) async throws(LeafError) -> Value in
            do throws(LeafError) {
                return try await run(env)
            } catch {
                return try await fallbackRun(env)
            }
        }
    }

    public func recover(
        _ fallback: @escaping (consuming LeafError) -> Value
    ) -> IO<Environment, Never, Value> {
        let run = self.run
        return IO<Environment, Never, Value> { (env: borrowing Environment) async throws(Never) -> Value in
            do throws(LeafError) {
                return try await run(env)
            } catch {
                return fallback(error)
            }
        }
    }
}
