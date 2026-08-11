// ============================================================================
// MARK: - Socket.Error
// ============================================================================

extension Socket {
    public enum Error: Swift.Error {
        case closed
        case refused
    }
}
