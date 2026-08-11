// MARK: - Order.Comparator

extension Order {
    /// A reified comparator that determines the relative order of two values.
    ///
    /// Comparators are first-class values that can be stored, composed, and
    /// passed to sorting functions. They encapsulate comparison logic while
    /// ensuring thread safety through `@Sendable` constraints.
    public struct Comparator<T>: Sendable {
        /// The underlying comparison function.
        @usableFromInline
        internal let compare: @Sendable (T, T) -> Comparison.Result

        /// Creates a comparator from a comparison function.
        @inlinable
        public init(_ compare: @escaping @Sendable (T, T) -> Comparison.Result) {
            self.compare = compare
        }

        /// Compares two values using this comparator.
        @inlinable
        public func callAsFunction(_ lhs: T, _ rhs: T) -> Comparison.Result {
            compare(lhs, rhs)
        }
    }
}

// MARK: - Reversal

extension Order.Comparator {
    /// Returns a comparator with reversed ordering.
    ///
    /// Elements that were ordered as less become greater, and vice versa.
    /// Equal elements remain equal.
    @inlinable
    public var reversed: Order.Comparator<T> {
        Order.Comparator { [compare] lhs, rhs in
            compare(lhs, rhs).reversed
        }
    }
}

// MARK: - Lexicographic Chaining

extension Order.Comparator {
    /// Returns a comparator that uses this comparator first, then the other
    /// comparator to break ties.
    @inlinable
    public func then(_ other: Order.Comparator<T>) -> Order.Comparator<T> {
        Order.Comparator { [compare] lhs, rhs in
            compare(lhs, rhs).then(other.compare(lhs, rhs))
        }
    }

    /// Returns a comparator that uses this comparator first, then evaluates
    /// the closure to break ties.
    ///
    /// Lazy variant that avoids computing the secondary comparison when
    /// the primary comparison is decisive.
    @inlinable
    public func then(
        with other: @escaping @Sendable () -> Order.Comparator<T>
    ) -> Order.Comparator<T> {
        Order.Comparator { [compare] lhs, rhs in
            let primary = compare(lhs, rhs)
            if primary.isEqual {
                return other().compare(lhs, rhs)
            }
            return primary
        }
    }
}

// MARK: - Projection (Sendable closure-based only)

extension Order.Comparator {
    /// Creates a comparator using a key-extracting function.
    ///
    /// This is the recommended API for key-based ordering in Swift 6
    /// strict concurrency mode, as KeyPath is not Sendable.
    @inlinable
    public static func by<Value: Comparable>(
        _ selector: @escaping @Sendable (T) -> Value
    ) -> Order.Comparator<T> {
        Order.Comparator { lhs, rhs in
            Comparison.Result(selector(lhs), selector(rhs))
        }
    }

    /// Creates a comparator using a key-extracting function and custom comparator.
    @inlinable
    public static func by<Value>(
        _ selector: @escaping @Sendable (T) -> Value,
        using comparator: Order.Comparator<Value>
    ) -> Order.Comparator<T> {
        Order.Comparator { lhs, rhs in
            comparator(selector(lhs), selector(rhs))
        }
    }
}

// MARK: - Comparable Construction

extension Order.Comparator where T: Comparable {
    /// Creates a comparator using the natural ordering of a Comparable type.
    @inlinable
    public init() {
        self.init { Comparison.Result($0, $1) }
    }

    /// The natural ascending comparator for Comparable types.
    @inlinable
    public static var ascending: Order.Comparator<T> {
        Order.Comparator()
    }

    /// The natural descending comparator for Comparable types.
    @inlinable
    public static var descending: Order.Comparator<T> {
        Order.Comparator().reversed
    }
}

// MARK: - KeyPath-based Projection (NON-SENDABLE VARIANT)
// DISCOVERY: KeyPath<T, Value> is NOT Sendable in Swift 6.
// This section documents the incompatibility and provides a non-Sendable alternative.

extension Order {
    /// A non-Sendable comparator for use with KeyPath-based projections.
    ///
    /// - Important: This type exists because `KeyPath` is not `Sendable` in Swift 6.
    ///   Use `Order.Comparator` with closure-based `by(_:)` for Sendable comparators.
    public struct NonSendableComparator<T> {
        /// The underlying comparison function.
        @usableFromInline
        internal let compare: (T, T) -> Comparison.Result

        /// Creates a comparator from a comparison function.
        @inlinable
        public init(_ compare: @escaping (T, T) -> Comparison.Result) {
            self.compare = compare
        }

        /// Compares two values using this comparator.
        @inlinable
        public func callAsFunction(_ lhs: T, _ rhs: T) -> Comparison.Result {
            compare(lhs, rhs)
        }

        /// Creates a comparator that extracts a key from each element using a KeyPath.
        ///
        /// - Note: This comparator is NOT Sendable because KeyPath is not Sendable.
        @inlinable
        public static func by<Value: Comparable>(
            _ keyPath: KeyPath<T, Value>
        ) -> NonSendableComparator<T> {
            NonSendableComparator { lhs, rhs in
                Comparison.Result(lhs[keyPath: keyPath], rhs[keyPath: keyPath])
            }
        }

        /// Returns a comparator with reversed ordering.
        @inlinable
        public var reversed: NonSendableComparator<T> {
            NonSendableComparator { [compare] lhs, rhs in
                compare(lhs, rhs).reversed
            }
        }

        /// Returns a comparator that uses this comparator first, then the other
        /// comparator to break ties.
        @inlinable
        public func then(_ other: NonSendableComparator<T>) -> NonSendableComparator<T> {
            NonSendableComparator { [compare] lhs, rhs in
                compare(lhs, rhs).then(other.compare(lhs, rhs))
            }
        }
    }
}
