//
// Additional factories: fail, from.
//

extension IO {

    public static func fail(
        _ error: consuming LeafError
    ) -> IO<Environment, LeafError, Value> {
        IO { [error] (_: borrowing Environment) async throws(LeafError) -> Value in
            throw error
        }
    }

    public static func from(
        _ body: @escaping (borrowing Environment) async throws(LeafError) -> Value
    ) -> IO<Environment, LeafError, Value> {
        IO(body)
    }
}
