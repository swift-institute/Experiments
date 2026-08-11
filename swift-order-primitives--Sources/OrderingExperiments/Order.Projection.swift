// MARK: - Order.Projection
// DISCOVERY: The original design proposed Projection<Root, Value> with KeyPath support.
// However, KeyPath is NOT Sendable in Swift 6. This file documents both variants.

extension Order {
    /// A projection that extracts an orderable value from a root type.
    ///
    /// Projections can be composed and transformed before being converted
    /// to comparators, enabling flexible ordering specifications.
    ///
    /// - Important: This type uses a `@Sendable` closure for extraction,
    ///   NOT KeyPath, because KeyPath is not Sendable in Swift 6.
    public struct Projection<Root, Value: Comparable>: Sendable {
        /// The key extraction function.
        @usableFromInline
        internal let extract: @Sendable (Root) -> Value

        /// The direction of ordering.
        public let direction: Direction

        /// Creates a projection with the given extractor and direction.
        @inlinable
        public init(
            _ extract: @escaping @Sendable (Root) -> Value,
            direction: Direction = .ascending
        ) {
            self.extract = extract
            self.direction = direction
        }

        /// Returns a projection with reversed direction.
        @inlinable
        public var reversed: Projection<Root, Value> {
            Projection(extract, direction: direction.reversed)
        }

        /// Converts this projection to a comparator.
        @inlinable
        public var comparator: Order.Comparator<Root> {
            let base = Order.Comparator<Root>.by(extract)
            return direction == .ascending ? base : base.reversed
        }
    }
}

// MARK: - Non-Sendable Projection (KeyPath-based)

extension Order {
    /// A non-Sendable projection that uses KeyPath for extraction.
    ///
    /// - Important: This type exists because `KeyPath` is not `Sendable` in Swift 6.
    ///   Use `Order.Projection` with closure-based extraction for Sendable projections.
    public struct NonSendableProjection<Root, Value: Comparable> {
        /// The key extraction function.
        @usableFromInline
        internal let extract: (Root) -> Value

        /// The direction of ordering.
        public let direction: Direction

        /// Creates a projection from a key path.
        @inlinable
        public init(
            _ keyPath: KeyPath<Root, Value>,
            direction: Direction = .ascending
        ) {
            self.extract = { $0[keyPath: keyPath] }
            self.direction = direction
        }

        /// Creates a projection with the given extractor and direction.
        @inlinable
        public init(
            _ extract: @escaping (Root) -> Value,
            direction: Direction = .ascending
        ) {
            self.extract = extract
            self.direction = direction
        }

        /// Returns a projection with reversed direction.
        @inlinable
        public var reversed: NonSendableProjection<Root, Value> {
            NonSendableProjection(extract, direction: direction.reversed)
        }

        /// Converts this projection to a non-Sendable comparator.
        @inlinable
        public var comparator: Order.NonSendableComparator<Root> {
            let base = Order.NonSendableComparator<Root> { lhs, rhs in
                Comparison.Result(extract(lhs), extract(rhs))
            }
            return direction == .ascending ? base : base.reversed
        }
    }
}
