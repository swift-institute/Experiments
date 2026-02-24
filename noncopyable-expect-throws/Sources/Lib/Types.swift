// Library module — types imported cross-module by tests.

// MARK: - Simple ~Copyable (no deinit)

public struct SimpleBox: ~Copyable {
    public var value: Int = 0
    public enum Err: Error, Equatable { case full }

    public init() {}

    public mutating func fill() throws(Err) {
        guard value < 2 else { throw .full }
        value += 1
    }
}

// MARK: - ~Copyable with deinit

public struct DeinitBox: ~Copyable {
    public var value: Int = 0
    public enum Err: Error, Equatable { case full }

    public init() {}

    public mutating func fill() throws(Err) {
        guard value < 2 else { throw .full }
        value += 1
    }

    deinit {}
}

// MARK: - Value generic + deinit + AnyObject?

public struct GenericBox<let capacity: Int>: ~Copyable {
    public var value: Int = 0
    var _workaround: AnyObject? = nil
    public enum Err: Error, Equatable { case full }

    public init() {}

    public mutating func fill() throws(Err) {
        guard value < capacity else { throw .full }
        value += 1
    }

    deinit {}
}

// MARK: - Nested ~Copyable field with deinit

public struct InnerResource: ~Copyable {
    public var data: Int = 0
    public init() {}
    deinit {}
}

public struct InnerStorage<let cap: Int>: ~Copyable {
    public var slots: (Int, Int, Int, Int) = (0, 0, 0, 0)
    public var used: Int = 0
    public init() {}
    deinit {}
}

// MARK: - Full composition (mirrors Dictionary.Ordered.Static)

public struct CompositeBox<let capacity: Int>: ~Copyable {
    public var _values: InnerStorage<capacity>
    public var _keys: InnerStorage<capacity>
    var _workaround: AnyObject? = nil
    public enum Err: Error, Equatable { case full }

    public init() {
        _values = InnerStorage<capacity>()
        _keys = InnerStorage<capacity>()
    }

    public mutating func set(_ key: Int, _ value: Int) throws(Err) {
        guard _values.used < capacity else { throw .full }
        _values.used += 1
        _keys.used += 1
    }

    deinit {}
}

// MARK: - Deep nesting (Dictionary<K,V>.Ordered.Static<N> pattern)

public enum Outer<Key: Hashable, Value> {
    public struct Inner: ~Copyable {
        public struct Static<let capacity: Int>: ~Copyable {
            public var count: Int = 0
            public var _storage: InnerStorage<capacity>
            public enum Err: Error, Equatable { case full }

            public init() {
                _storage = InnerStorage<capacity>()
            }

            public mutating func set(_ value: Int) throws(Err) {
                guard count < capacity else { throw .full }
                count += 1
            }

            deinit {}
        }
    }
}
