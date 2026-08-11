// MARK: - Order.PartialComparator

extension Order {
    /// A comparator for partially ordered types.
    ///
    /// Returns `nil` when two values are incomparable.
    public struct PartialComparator<T>: Sendable {
        @usableFromInline
        internal let compare: @Sendable (T, T) -> Comparison.Result?

        @inlinable
        public init(_ compare: @escaping @Sendable (T, T) -> Comparison.Result?) {
            self.compare = compare
        }

        @inlinable
        public func callAsFunction(_ lhs: T, _ rhs: T) -> Comparison.Result? {
            compare(lhs, rhs)
        }
    }
}
