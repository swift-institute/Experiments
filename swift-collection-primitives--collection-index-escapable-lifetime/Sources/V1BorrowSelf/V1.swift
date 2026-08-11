// MARK: - V1 (control): ~Escapable-admitting Index with @_lifetime(borrow self)
// Reproduces, in isolation, the annotation used in the real-package #4 edit and
// the prior /tmp spike. Validates that this minimal harness faithfully captures
// the documented failure (so a V2 pass is meaningful, not an artifact).
// Status: EXPECT REFUTED — `formIndex` lifetime-escape
// Toolchain: Apple Swift 6.3.2
// Result: REFUTED — error: lifetime-dependent variable 'i' escapes its scope
//   (note: it depends on the lifetime of argument 'self'). V1.swift:33.
//   Cmd: swift build --target V1BorrowSelf
public import Comparison_Primitives

public enum ExpCollection {}

extension ExpCollection {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable
        associatedtype Index: Comparison.`Protocol` & ~Escapable

        var startIndex: Index { get }
        var endIndex: Index { get }
        subscript(_ position: Index) -> Element { get }

        // borrow-self: result borrows `self`. Writing it into caller-owned `inout`
        // lets a self-borrow escape — the documented break.
        @_lifetime(borrow self)
        func index(after i: Index) -> Index
    }
}

extension ExpCollection.`Protocol` where Self: ~Copyable {
    @inlinable
    public var isEmpty: Bool { startIndex == endIndex }

    @inlinable
    public func formIndex(after i: inout Index) {
        i = index(after: i)
    }
}
