//
// Traversal: sequence, traverse.
//

extension IO {

    public static func sequence(
        _ ios: [IO<Environment, LeafError, Value>]
    ) -> IO<Environment, LeafError, [Value]> {
        IO<Environment, LeafError, [Value]> { (env: borrowing Environment) async throws(LeafError) -> [Value] in
            var results: [Value] = []
            results.reserveCapacity(ios.count)
            for io in ios {
                results.append(try await io.run(env))
            }
            return results
        }
    }

    public static func traverse<Input>(
        _ inputs: [Input],
        _ transform: @escaping (consuming Input) -> IO<Environment, LeafError, Value>
    ) -> IO<Environment, LeafError, [Value]> {
        IO<Environment, LeafError, [Value]> { (env: borrowing Environment) async throws(LeafError) -> [Value] in
            var results: [Value] = []
            results.reserveCapacity(inputs.count)
            for input in inputs {
                results.append(try await transform(input).run(env))
            }
            return results
        }
    }
}
