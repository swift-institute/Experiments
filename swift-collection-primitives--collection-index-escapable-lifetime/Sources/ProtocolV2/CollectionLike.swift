// MARK: - V2: ~Escapable-admitting Index associatedtype with @_lifetime(copy i)
// Hypothesis: copy-i (the successor's lifetime derives from the INPUT index, not
//   from a fresh borrow of self) lets the generic `formIndex` default typecheck
//   where @_lifetime(borrow self) (V1) does not.
// Status: (see ../collection-index-escapable-lifetime/main.swift)
// Toolchain: Apple Swift 6.3.2
// Result: CONFIRMED — `swift build --target ProtocolV2` exit 0; the generic
//   `formIndex` default typechecks under @_lifetime(copy i) (Build Succeeded).
public import Comparison_Primitives

public enum ExpCollection {}

extension ExpCollection {
    /// Mirrors the real `Collection.\`Protocol\`` requirement set, with the
    /// proposed change: `Index` is a `~Escapable`-admitting associatedtype.
    public protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable

        // The proposed change under test (suppressed bound, no default — the
        // default `= Index<Element>` is uninvolved in the formIndex typecheck
        // and is dropped per [EXP-004] reduction to isolate the behavior).
        associatedtype Index: Comparison.`Protocol` & ~Escapable

        var startIndex: Index { get }
        var endIndex: Index { get }
        subscript(_ position: Index) -> Element { get }

        // copy-i: the result's lifetime is that of the input index `i`.
        @_lifetime(copy i)
        func index(after i: Index) -> Index
    }
}

extension ExpCollection.`Protocol` where Self: ~Copyable {
    @inlinable
    public var isEmpty: Bool { startIndex == endIndex }

    /// The storable-index contract: write the successor back into caller storage.
    /// This is the exact default that broke under V1 (borrow-self).
    @inlinable
    public func formIndex(after i: inout Index) {
        i = index(after: i)
    }
}
