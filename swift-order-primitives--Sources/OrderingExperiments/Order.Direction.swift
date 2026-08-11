// MARK: - Order.Direction

extension Order {
    /// Direction of ordering: ascending or descending.
    public enum Direction: Sendable, Hashable, CaseIterable {
        /// Smaller values come first.
        case ascending

        /// Larger values come first.
        case descending

        /// Returns the opposite direction.
        @inlinable
        public var reversed: Direction {
            switch self {
            case .ascending: return .descending
            case .descending: return .ascending
            }
        }
    }
}
