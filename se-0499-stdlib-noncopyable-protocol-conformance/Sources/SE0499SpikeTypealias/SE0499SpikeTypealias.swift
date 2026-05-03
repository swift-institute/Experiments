// SE-0499 namespace-adoption-typealias spike.
//
// Question: After SE-0499 lands, can `Equation.Protocol` be replaced with
// `typealias \`Protocol\` = Swift.Equatable` while consumer conformance
// declarations like `extension T: Equation.\`Protocol\`` keep resolving?
//
// This is the actual deployment shape proposed for swift-equation-primitives,
// swift-hash-primitives, and swift-comparison-primitives once SE-0499 is GA.

// MARK: - Namespace + typealias (the proposed deployment shape)

public enum Equation {}
extension Equation { public typealias `Protocol` = Swift.Equatable }

public enum Hash {}
extension Hash { public typealias `Protocol` = Swift.Hashable }

public enum Comparison {}
extension Comparison { public typealias `Protocol` = Swift.Comparable }

// MARK: - Conformance via the typealias name

public struct EqAlias: ~Copyable, Equation.`Protocol` {
    public let id: Int
    public init(id: Int) { self.id = id }
    public static func == (lhs: borrowing EqAlias, rhs: borrowing EqAlias) -> Bool {
        lhs.id == rhs.id
    }
}

public struct HashAlias: ~Copyable, Hash.`Protocol` {
    public let id: Int
    public init(id: Int) { self.id = id }
    public static func == (lhs: borrowing HashAlias, rhs: borrowing HashAlias) -> Bool {
        lhs.id == rhs.id
    }
    public borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct CmpAlias: ~Copyable, Comparison.`Protocol` {
    public let id: Int
    public init(id: Int) { self.id = id }
    public static func == (lhs: borrowing CmpAlias, rhs: borrowing CmpAlias) -> Bool {
        lhs.id == rhs.id
    }
    public static func < (lhs: borrowing CmpAlias, rhs: borrowing CmpAlias) -> Bool {
        lhs.id < rhs.id
    }
}

// MARK: - Generic constraints via typealias name

public func aliasEqual<T: Equation.`Protocol` & ~Copyable>(
    _ lhs: borrowing T,
    _ rhs: borrowing T
) -> Bool {
    lhs == rhs
}

public func aliasSmaller<T: Comparison.`Protocol` & ~Copyable>(
    _ lhs: borrowing T,
    _ rhs: borrowing T
) -> Bool {
    lhs < rhs
}
