//
// V2 — Generic struct with @_owned consuming get returning a fresh value
//
// Shape: Container<T: ~Copyable>: ~Copyable carrying T, exposes @_owned property
//        whose getter returns a freshly-constructed value (NOT T extracted from
//        self — to isolate the "construct + return via consuming getter" path
//        from the "move stored field out of self" path).
// Purpose: the GENERIC STRUCT case — not in prior research.
//

public struct V2_Container<T: ~Copyable>: ~Copyable {
    @usableFromInline
    let stored: T

    @inlinable
    public init(_ stored: consuming T) {
        self.stored = stored
    }

    // Variant A — return a value of an unrelated, copyable type (Int).
    // Tests the generic + @_owned + consuming-getter combination without
    // moving the generic stored field.
    @_owned
    public var marker: Int {
        consuming get { 42 }
    }
}

// Variant B — actually move the generic stored field out via switch/pattern
// would normally require enum payloads; for a struct we can use
// `consuming get { stored }` — this is the V6-equivalent property-form, gated
// by @_owned.
public struct V2_ContainerExtract<T: ~Copyable>: ~Copyable {
    @usableFromInline
    let stored: T

    @inlinable
    public init(_ stored: consuming T) {
        self.stored = stored
    }

    @_owned
    public var value: T {
        consuming get {
            // Move the stored field out of consumed self.
            stored
        }
    }
}

// Call sites — use consuming-parameter wrappers per the prior research's
// suggestion that wrapping the read in a consuming-parameter function avoids
// the "borrowed by a non-Escapable type" diagnostic.

@inlinable
public func extractV2AMarker<T: ~Copyable>(_ c: consuming V2_Container<T>) -> Int {
    c.marker
}

@inlinable
public func extractV2BValue<T: ~Copyable>(_ c: consuming V2_ContainerExtract<T>) -> T {
    c.value
}

@inlinable
public func runV2A() -> Int {
    let c = V2_Container<V1_NC>(V1_NC(99))
    return extractV2AMarker(c) // 42
}

@inlinable
public func runV2B() -> Int {
    let c = V2_ContainerExtract<V1_NC>(V1_NC(99))
    let inner = extractV2BValue(c)
    return inner.payload // 99
}
