// ============================================================================
// MARK: - Socket namespace
// ============================================================================

public enum Socket {}

extension Socket {
    /// A ZIO-style computation: read from a socket, returning bytes count.
    ///
    /// Note: we deliberately annotate the closure type explicitly — Swift does
    /// not infer typed throws from a body that does not actually throw, and an
    /// `IO` init expecting `throws(Socket.Error)` would otherwise see a
    /// `throws(Never)` closure.
    public static func read(count: Int) -> IO<Socket.Environment, Socket.Error, Int> {
        IO<Socket.Environment, Socket.Error, Int> {
            (env: Socket.Environment) async throws(Socket.Error) -> sending Int in
            // Real impl: dispatch to blocking/reactor/proactor, return bytes read.
            // For sketch: just return count.
            return count
        }
    }
}
