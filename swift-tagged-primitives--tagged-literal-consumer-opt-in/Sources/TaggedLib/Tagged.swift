// Simulates identity-primitives: Tagged + no literal conformance.

public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    public var rawValue: RawValue
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

extension Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable {}

extension Tagged: Equatable where Tag: ~Copyable, RawValue: Equatable {
    public static func == (lhs: Tagged, rhs: Tagged) -> Bool { lhs.rawValue == rhs.rawValue }
}
extension Tagged: Comparable where Tag: ~Copyable, RawValue: Comparable {
    public static func < (lhs: Tagged, rhs: Tagged) -> Bool { lhs.rawValue < rhs.rawValue }
}
extension Tagged: Strideable where Tag: ~Copyable, RawValue: Strideable {
    public func advanced(by n: RawValue.Stride) -> Tagged {
        Tagged(__unchecked: (), rawValue.advanced(by: n))
    }
    public func distance(to other: Tagged) -> RawValue.Stride {
        rawValue.distance(to: other.rawValue)
    }
}
