// Core module: Tagged struct (mirrors identity-primitives)

@frozen
public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    public var rawValue: RawValue

    @inlinable
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

extension Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable {}
extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}
