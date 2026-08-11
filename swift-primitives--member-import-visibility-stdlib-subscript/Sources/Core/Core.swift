// Core — analogous to Ordinal_Primitives_Core
//
// Defines:
// - Protocol `P` (analogous to Ordinal.Protocol)
// - Concrete type `Concrete: P` (analogous to Ordinal: Ordinal.Protocol)
// - Retroactive conformance `Tagged<Tag, Concrete>: P` (analogous to Tagged<Tag, Ordinal>: Ordinal.Protocol)

public import TypeDefs

// MARK: - Protocol

public protocol P {
    var rawValue: Int { get }
    init(rawValue: Int)
}

// MARK: - Concrete conformer (unconditional)

public struct Concrete: P {
    public var rawValue: Int

    @inlinable
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

// MARK: - Retroactive conditional conformance on Tagged (from TypeDefs module)

extension Tagged: P where Wrapped == Concrete {
    @inlinable
    public var rawValue: Int { wrapped.rawValue }

    @inlinable
    public init(rawValue: Int) {
        self.init(Concrete(rawValue: rawValue))
    }
}
