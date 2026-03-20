// Variant types for testing different operator configurations.
// Each variant duplicates Path's structure with different operator sets.

// MARK: - Variant A: Three overloads (original bug scenario)
// Path / Component, Path / Path, Path / String

public struct PathA: Copyable, Sendable, Hashable {
    public var string: String
    public init(_ string: String) { self.string = string }

    public struct Component: Copyable, Sendable, Hashable, ExpressibleByStringLiteral,
        ExpressibleByStringInterpolation
    {
        public var string: String
        public init(_ string: String) { self.string = string }
        public init(stringLiteral value: String) { self.init(value) }
    }

    @inlinable
    public static func / (lhs: PathA, rhs: Component) -> PathA {
        PathA(lhs.string + "/" + rhs.string)
    }

    @_disfavoredOverload
    @inlinable
    public static func / (lhs: PathA, rhs: PathA) -> PathA {
        PathA(lhs.string + "/" + rhs.string)
    }

    @_disfavoredOverload
    @inlinable
    public static func / (lhs: PathA, rhs: String) -> PathA {
        PathA(lhs.string + "/" + rhs)
    }
}

extension PathA: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}

extension PathA: ExpressibleByStringInterpolation {}

// MARK: - Variant B: Only Path / Component (Option 1: remove Path / Path)

public struct PathB: Copyable, Sendable, Hashable {
    public var string: String
    public init(_ string: String) { self.string = string }

    public struct Component: Copyable, Sendable, Hashable, ExpressibleByStringLiteral,
        ExpressibleByStringInterpolation
    {
        public var string: String
        public init(_ string: String) { self.string = string }
        public init(stringLiteral value: String) { self.init(value) }
    }

    @inlinable
    public static func / (lhs: PathB, rhs: Component) -> PathB {
        PathB(lhs.string + "/" + rhs.string)
    }

    // No Path / Path operator
}

extension PathB: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}

extension PathB: ExpressibleByStringInterpolation {}

// MARK: - Variant C: Both operators, no Path literal (Option 2: remove Path: ExpressibleByStringLiteral)

public struct PathC: Copyable, Sendable, Hashable {
    public var string: String
    public init(_ string: String) { self.string = string }

    public struct Component: Copyable, Sendable, Hashable, ExpressibleByStringLiteral,
        ExpressibleByStringInterpolation
    {
        public var string: String
        public init(_ string: String) { self.string = string }
        public init(stringLiteral value: String) { self.init(value) }
    }

    @inlinable
    public static func / (lhs: PathC, rhs: Component) -> PathC {
        PathC(lhs.string + "/" + rhs.string)
    }

    @_disfavoredOverload
    @inlinable
    public static func / (lhs: PathC, rhs: PathC) -> PathC {
        PathC(lhs.string + "/" + rhs.string)
    }
}

// PathC does NOT conform to ExpressibleByStringLiteral

// MARK: - Variant D: Three overloads without @_disfavoredOverload

public struct PathD: Copyable, Sendable, Hashable {
    public var string: String
    public init(_ string: String) { self.string = string }

    public struct Component: Copyable, Sendable, Hashable, ExpressibleByStringLiteral,
        ExpressibleByStringInterpolation
    {
        public var string: String
        public init(_ string: String) { self.string = string }
        public init(stringLiteral value: String) { self.init(value) }
    }

    @inlinable
    public static func / (lhs: PathD, rhs: Component) -> PathD {
        PathD(lhs.string + "/" + rhs.string)
    }

    @inlinable
    public static func / (lhs: PathD, rhs: PathD) -> PathD {
        PathD(lhs.string + "/" + rhs.string)
    }

    @inlinable
    public static func / (lhs: PathD, rhs: String) -> PathD {
        PathD(lhs.string + "/" + rhs)
    }
}

extension PathD: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}

extension PathD: ExpressibleByStringInterpolation {}
