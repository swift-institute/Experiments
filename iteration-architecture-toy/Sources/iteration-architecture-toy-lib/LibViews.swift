// MARK: - Phase 7 (Gap c) — CROSS-MODULE: the ~Escapable view types ([EXP-017] requires the view
// type(s) to live in the second target). CopyView backs D1; SpanView backs route-3 forEach (C).

// MARK: Memory.CopyView — a ~Escapable span view with a @_lifetime(copy self) makeIterator (D1).
public extension Memory {
    @frozen
    struct CopyView<Element>: ~Copyable, ~Escapable {
        @usableFromInline let span: Span<Element>
        @_lifetime(copy span)
        @inlinable public init(_ span: consuming Span<Element>) { self.span = span }
    }
}

extension Memory.CopyView: IterableByCopy {
    public typealias Iterator = iteration_architecture_toy_lib.Iterator.Chunk<Element>
    @_lifetime(copy self)
    public borrowing func makeIterator() -> iteration_architecture_toy_lib.Iterator.Chunk<Element> {
        iteration_architecture_toy_lib.Iterator.Chunk(span)
    }
}

// MARK: Memory.SpanView — a ~Escapable span view conforming BorrowForEachable (route-3 leaf).
public extension Memory {
    @frozen
    struct SpanView<Element: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline let span: Span<Element>
        @_lifetime(copy span)
        @inlinable public init(_ span: consuming Span<Element>) { self.span = span }
    }
}

extension Memory.SpanView: BorrowForEachable where Element: ~Copyable {
    @inlinable
    public borrowing func forEach(_ body: (borrowing Element) -> Void) {
        for i in 0..<span.count { body(span[i]) }
    }
}
