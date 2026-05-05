// MARK: - Minimal Tagged stand-in
// Mirrors swift-tagged-primitives' Tagged just enough to test
// constrained-extension nested-type-lookup behavior under cross-instantiation.

public struct Tagged<Tag, RawValue> {
    public let rawValue: RawValue
    public init(_ rawValue: RawValue) { self.rawValue = rawValue }
}

// Two distinct tag types so each leg can declare its own Tagged variant.
public enum TagA {}
public enum TagB {}

// Two distinct RawValue types so the constrained extensions are on
// genuinely different generic instantiations (mirrors production:
// Tagged<Memory, Ordinal> vs Tagged<POSIX, Stats>).
public struct RawA { public let v: Int; public init(_ v: Int) { self.v = v } }
public struct RawB { public let v: String; public init(_ v: String) { self.v = v } }

// Distinct Error nested types each leg's constrained extension will
// typealias under the same name `Error`.
public enum NestedAError: Error { case a }
public enum NestedBError: Error { case b }
