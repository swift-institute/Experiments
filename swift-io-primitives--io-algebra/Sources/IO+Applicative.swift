//
// Applicative structure: zip.
//

extension IO {

    public func zip<Other>(
        _ other: IO<Environment, LeafError, Other>
    ) -> IO<Environment, LeafError, (Value, Other)> {
        let selfRun = self.run
        let otherRun = other.run
        return IO<Environment, LeafError, (Value, Other)> { (env: borrowing Environment) async throws(LeafError) -> (Value, Other) in
            let a = try await selfRun(env)
            let b = try await otherRun(env)
            return (a, b)
        }
    }
}
