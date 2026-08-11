// MARK: - Library Module — Carrier.Protocol + Cardinal + SLI overloads
//
// This module mirrors the production split where Cardinal_Primitives_Core
// (Cardinal + Carrier.Protocol) and Cardinal_Primitives_Standard_Library_Integration
// (the SLI extensions) live in modules separate from the consumer.

/// Stand-in for Carrier.\`Protocol\` matching the production shape — `~Copyable & ~Escapable`
/// Self, `~Copyable & ~Escapable` Underlying, `Domain` associatedtype defaulting to Never,
/// `@_lifetime`-annotated accessor and init.
public protocol CarrierProto<Underlying>: ~Copyable, ~Escapable {
    associatedtype Domain: ~Copyable & ~Escapable = Never
    associatedtype Underlying: ~Copyable & ~Escapable

    var underlying: Underlying {
        @_lifetime(borrow self)
        borrowing get
    }

    @_lifetime(copy underlying)
    init(_ underlying: consuming Underlying)
}

public struct Cardinal: Sendable {
    public let rawValue: UInt
    public init(_ rawValue: UInt) { self.rawValue = rawValue }
}

extension Cardinal: CarrierProto {
    public typealias Domain = Never
    public typealias Underlying = Cardinal
    public var underlying: Cardinal { self }
    public init(_ underlying: Cardinal) { self = underlying }
}

// MARK: - V1: generic protocol-level

extension RangeReplaceableCollection {
    @inlinable
    public mutating func reserveCapacityV1(_ minimumCapacity: some CarrierProto<Cardinal>) {
        self.reserveCapacity(Int(bitPattern: minimumCapacity.underlying.rawValue))
    }
}

// MARK: - V2: per-type non-generic Cardinal on RRC

extension RangeReplaceableCollection {
    @inlinable
    public mutating func reserveCapacityV2(_ minimumCapacity: Cardinal) {
        self.reserveCapacity(Int(bitPattern: minimumCapacity.rawValue))
    }
}

// MARK: - V3: explicit generic + ~Copyable suppression

extension RangeReplaceableCollection {
    @inlinable
    public mutating func reserveCapacityV3<C: CarrierProto<Cardinal> & ~Copyable>(
        _ minimumCapacity: borrowing C
    ) {
        self.reserveCapacity(Int(bitPattern: minimumCapacity.underlying.rawValue))
    }
}

// MARK: - V4: per-type on Swift.Array

extension Swift.Array {
    @inlinable
    public mutating func reserveCapacityV4(_ minimumCapacity: Cardinal) {
        self.reserveCapacity(Int(bitPattern: minimumCapacity.rawValue))
    }
}
