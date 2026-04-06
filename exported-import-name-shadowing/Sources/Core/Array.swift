// Core/Array.swift
// Defines a custom Array<Element> that shadows Swift.Array,
// mirroring Array_Primitives_Core.Array.

public struct Array<Element> {
    public var count: Int

    public init() {
        self.count = 0
    }

    /// Marker property — only exists on Core.Array, not Swift.Array.
    /// Used by consumers to verify which Array was resolved.
    public static var isCustom: Bool { true }

    /// Nested type — mirrors Array.Fixed in the real ecosystem.
    public struct Nested {
        public init() {}
    }
}
