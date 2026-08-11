// MARK: - Mock Comparison.Result (from comparison-primitives)
// This is a mock implementation to test ordering-primitives in isolation

/// Namespace for comparison-related types.
public enum Comparison: Sendable {}

extension Comparison {
    /// The result of a three-way comparison between two values.
    public enum Result: Int, Sendable, Hashable, CaseIterable {
        /// The left-hand side is less than the right-hand side.
        case less = -1

        /// The left-hand side is equal to the right-hand side.
        case equal = 0

        /// The left-hand side is greater than the right-hand side.
        case greater = 1

        /// Creates a comparison result from two comparable values.
        @inlinable
        public init<T: Comparable>(_ lhs: T, _ rhs: T) {
            if lhs < rhs {
                self = .less
            } else if lhs > rhs {
                self = .greater
            } else {
                self = .equal
            }
        }

        /// Returns the reversed comparison result.
        @inlinable
        public var reversed: Result {
            switch self {
            case .less: return .greater
            case .equal: return .equal
            case .greater: return .less
            }
        }

        /// Returns `true` if this result indicates equality.
        @inlinable
        public var isEqual: Bool {
            self == .equal
        }

        /// Returns `true` if this result indicates less than.
        @inlinable
        public var isLess: Bool {
            self == .less
        }

        /// Returns `true` if this result indicates greater than.
        @inlinable
        public var isGreater: Bool {
            self == .greater
        }

        /// Chains comparison results: returns this result if not equal,
        /// otherwise returns the other result.
        @inlinable
        public func then(_ other: @autoclosure () -> Result) -> Result {
            if self == .equal {
                return other()
            }
            return self
        }
    }
}
