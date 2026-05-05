// MARK: - Leg A: First constrained-extension nested typealias
// Mirrors swift-memory-primitives shape: a constrained extension on
// Tagged with where Tag == TagA, RawValue == RawA declaring nested
// typealias Error.

public import TaggedCore

extension Tagged where Tag == TagA, RawValue == RawA {
    public typealias Error = NestedAError
}
