// MARK: - Phase 2 REVISIT — D1 runtime proof: copy-lifetime makeIterator DELEGATION via Backing
// Overturns the earlier "makeIterator delegation REFUTED": delegation works AND is checker-clean
// when the backing's makeIterator is @_lifetime(copy self) (not @_lifetime(borrow self)).

// A ~Escapable backing view conforming IterableByCopy (copy-lifetime makeIterator over a span).
public extension Memory {
    @frozen
    struct CopyView<Element>: ~Copyable, ~Escapable {
        @usableFromInline let span: Span<Element>
        @_lifetime(copy span)
        @inlinable public init(_ span: consuming Span<Element>) { self.span = span }
    }
}

extension Memory.CopyView: IterableByCopy {
    public typealias Iterator = iteration_architecture_toy.Iterator.Chunk<Element>
    @_lifetime(copy self)
    public borrowing func makeIterator() -> iteration_architecture_toy.Iterator.Chunk<Element> {
        iteration_architecture_toy.Iterator.Chunk(span)
    }
}

// A concrete ~Copyable container whose makeIterator is inherited from the FamD family default
// (makeIteratorD1) — the body lives ONCE on the family protocol and delegates through `view`.
public struct FamDImpl: ~Copyable {
    @usableFromInline var storage: [Int]
    @inlinable public init(_ storage: [Int]) { self.storage = storage }
}

extension FamDImpl: FamD.`Protocol` {
    public typealias Element = Int
    public typealias View = Memory.CopyView<Int>
    public var view: Memory.CopyView<Int> {
        @_lifetime(borrow self) get { Memory.CopyView(storage.span) }
    }
    // makeIteratorD1() inherited from FamD.`Protocol` default — delegates view.makeIterator().
}

// MARK: Unification boundary (REFUTED) — an ESCAPABLE OWNED container CANNOT conform the
// copy-self makeIterator protocol by direct construction. Its iterator (Iterator.Chunk) is
// ~Escapable (borrows self), so the witness needs an annotation; but @_lifetime(borrow self)
// does NOT satisfy the @_lifetime(copy self) requirement (the ~Escapable result escapes the
// copy-self "immortal" contract), and @_lifetime(copy self) is invalid on an Escapable self.
// Exact diagnostic (with @_lifetime(borrow self) witness):
//   error: lifetime-dependent value escapes its scope   (Iterator.Chunk(self.span))
// So @_lifetime(copy self) is NOT a single unifying shape: owned containers stay on borrow-self
// Iterable (direct construction, Shape b); the copy-self protocol is for the ~Escapable VIEW the
// family delegates THROUGH (D1). Owned containers EXPOSE a copy-self view; they don't conform it.
//
//   public struct EscByCopy: ~Copyable {            // Escapable, ~Copyable, owns the storage
//       var storage: [Int]
//       var span: Span<Int> { @_lifetime(borrow self) get { storage.span } }
//   }
//   extension EscByCopy: IterableByCopy {
//       @_lifetime(borrow self)                      // ❌ escapes vs the copy-self requirement
//       borrowing func makeIterator() -> Iterator.Chunk<Int> { Iterator.Chunk(self.span) }
//   }
