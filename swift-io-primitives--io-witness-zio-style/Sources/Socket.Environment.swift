// ============================================================================
// MARK: - Socket.Environment
// ============================================================================
//
// Environment/capability type for Socket computations. No Sendable required —
// with `sending R`, `~Copyable` descriptors could now serve as R as well.
//

extension Socket {
    public struct Environment {
        public let listenerFD: Int32

        public init(listenerFD: Int32) {
            self.listenerFD = listenerFD
        }
    }
}
