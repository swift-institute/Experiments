// MARK: - Phase 1 — Toy container substrate protocols

// MARK: Memory.Contiguous — the span substrate
// Real: Memory.ContiguousProtocol — associatedtype Element: ~Copyable, var span: Span<Element>.
// Span<Element> forces Element: Escapable (verified Phase 1), so Element here is
// ~Copyable-allowed but Escapable-required. Backing for routes 1 & 2; a borrowing forEach
// can also read span[i] for ~Copyable Escapable elements (route 3 without the memory bridge).

public enum Memory {}

public extension Memory {
    protocol Contiguous: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        var span: Span<Element> { @_lifetime(borrow self) get }
    }
}

// MARK: Collection.`Protocol` — subscript + index (intrinsic family-protocol refinement target)
// Real: Collection.Index keeps & ~Escapable; subscript yields a borrow of a ~Copyable element.

public enum Collection {}

public extension Collection {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype Index: ~Escapable
        var startIndex: Index { @_lifetime(borrow self) get }
        var endIndex: Index { @_lifetime(borrow self) get }
        @_lifetime(borrow self)
        borrowing func index(after i: Index) -> Index
        // Protocol subscripts allow only get/set; the borrowing read is a witness detail.
        subscript(position: Index) -> Element { get }
    }
}
