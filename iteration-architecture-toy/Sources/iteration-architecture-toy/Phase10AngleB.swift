// MARK: - Phase 10 (Angle B) — TWO conditional family defaults gated by Backing.Iterator escapability,
// under ONE family protocol. One protocol provides two makeIterator defaults selected by a constraint
// on whether the Backing's iterator is ~Escapable (span/piecewise/borrow-walker → copy-self default)
// or Escapable (plain owning walker → plain default). Hypothesis: conditional defaults let ONE protocol
// serve both the span-projecting family AND the traversal-only (plain-iterator) family.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0
//
// NOTE on the framing: Angle A already showed that MOST traversal-only structures (flat/heap trees A1,
// hashes A3, boxed trees with a real span A2b) are span-projecting and ride the SAME copy-self default
// as arrays — so they do NOT need a second default. Angle B targets the residual case: a backing whose
// iterator is genuinely ESCAPABLE (a plain owning walker, e.g. one that copies node values into an owned
// buffer, or a Copyable-element drain). Can ONE family protocol carry BOTH a copy-self default (for
// ~Escapable backing iterators) AND a plain default (for Escapable backing iterators), dispatched by the
// escapability of Backing.Iterator?

// A unified family protocol whose Backing exposes BOTH an Element and an Iterator associated type, with
// NO @_lifetime on the protocol requirement itself (each default supplies its own lifetime shape).
public enum FamB {}
public extension FamB {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype Backing: ~Copyable & ~Escapable
        var backing: Backing { @_lifetime(borrow self) get }
    }
}

// A capability the Escapable-iterator backings expose: a PLAIN (non-lifetime) makeIterator.
public protocol PlainIterable: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: iteration_architecture_toy.Iterator.`Protocol`
        where Iterator.Element == Element
    borrowing func makeIterator() -> Iterator
}

// MARK: B-default-1 — SAME method name `makeIteratorB()`, copy-self shape, gated on Backing: IterableByCopy
// (the ~Escapable-iterator family). @_lifetime(borrow self) because the result is lifetime-dependent.
public extension FamB.`Protocol`
    where Self: ~Copyable & ~Escapable,
          Backing: IterableByCopy, Backing.Element == Element {
    @_lifetime(borrow self)
    borrowing func makeIteratorB() -> Backing.Iterator {
        backing.makeIterator()
    }
}

// MARK: B-default-2 — SAME method name `makeIteratorB()`, plain shape, gated on Backing: PlainIterable
// (the Escapable-iterator family). NO @_lifetime (a plain Escapable iterator cannot carry one).
// THE DISCRIMINATOR: can ONE protocol carry TWO defaults for the SAME method name `makeIteratorB`,
// with DIFFERENT lifetime annotations, selected purely by the Backing constraint? If the compiler
// accepts both and dispatches per-conformer, Angle B is CONFIRMED (one protocol, two families).
public extension FamB.`Protocol`
    where Self: ~Copyable & ~Escapable,
          Backing: PlainIterable, Backing.Element == Element {
    borrowing func makeIteratorB() -> Backing.Iterator {
        backing.makeIterator()
    }
}

// MARK: Conformer 1 — copy-self family member. Backing = Memory.CopyView (IterableByCopy, ~Escapable
// iterator). Inherits B-default-1 (the @_lifetime(borrow self) copy-self makeIteratorB).
public struct FamBContiguous: ~Copyable {
    @usableFromInline var storage: [Int]
    @inlinable public init(_ storage: [Int]) { self.storage = storage }
}

extension FamBContiguous: FamB.`Protocol` {
    public typealias Element = Int
    public typealias Backing = Memory.CopyView<Int>
    public var backing: Memory.CopyView<Int> {
        @_lifetime(borrow self) get { Memory.CopyView(storage.span) }
    }
    // makeIteratorB() inherited from B-default-1 (copy-self).
}

// MARK: Conformer 2 — plain family member. Backing.Iterator is a GENUINELY ESCAPABLE plain walker
// (the Angle-B point: an Escapable Backing.Iterator selects B-default-2, NOT the copy-self B-default-1).
// The walker OWNS a snapshot [Int] and indexes into it — fully Escapable (no span, no ARC, no @_lifetime),
// returns OWNED Int. This is the canonical "plain owning walker" the second default is for. Because the
// iterator is Escapable (not the immortal-~Escapable A2 shape), it does NOT trip the forwardToInit crash.
public struct OwningBulkIterator {
    @usableFromInline var values: [Int]
    @usableFromInline var position: Int
    @inlinable public init(_ values: [Int]) { self.values = values; self.position = 0 }
}

extension OwningBulkIterator: Iterator.`Protocol` {
    public typealias Element = Int
    @inlinable public mutating func next() -> Int? {
        guard position < values.count else { return nil }
        defer { position &+= 1 }
        return values[position]
    }
}

// A ~Escapable backing whose makeIterator returns the ESCAPABLE OwningBulkIterator. The backing borrows
// a real span (not immortal); its iterator snapshots the values (Escapable). So Backing.Iterator is
// Escapable → B-default-2 is selected.
public struct OwningBulkBacking: ~Copyable, ~Escapable {
    @usableFromInline let span: Span<Int>
    @_lifetime(copy span)
    @inlinable public init(_ span: consuming Span<Int>) { self.span = span }
}

extension OwningBulkBacking: PlainIterable {
    public typealias Element = Int
    public typealias Iterator = OwningBulkIterator
    public borrowing func makeIterator() -> OwningBulkIterator {
        var snapshot: [Int] = []
        for i in 0..<span.count { snapshot.append(span[i]) }
        return OwningBulkIterator(snapshot)
    }
}

public struct FamBPlain: ~Copyable {
    @usableFromInline var storage: [Int]
    @inlinable public init(_ storage: [Int]) { self.storage = storage }
}

extension FamBPlain: FamB.`Protocol` {
    public typealias Element = Int
    public typealias Backing = OwningBulkBacking
    public var backing: OwningBulkBacking {
        @_lifetime(borrow self) get { OwningBulkBacking(storage.span) }
    }
    // makeIteratorB() inherited from B-default-2 (plain, Escapable iterator).
}

// MARK: VERDICT (Angle B) — CONFIRMED (compiles checker-clean + WARNING-CLEAN, dispatches + runs
// correctly, debug AND release). ONE family protocol (FamB.`Protocol`) carries TWO conditional defaults
// for the SAME method name `makeIteratorB()`:
//   • B-default-1: @_lifetime(borrow self), gated `where Backing: IterableByCopy` (~Escapable iterator)
//   • B-default-2: plain (NO @_lifetime),  gated `where Backing: PlainIterable`  (Escapable iterator)
// The compiler ACCEPTS both defaults under one protocol and DISPATCHES per-conformer by the Backing
// constraint: FamBContiguous (Backing = Memory.CopyView, ~Escapable iterator) inherits B-default-1 and
// runs [10,20,30]; FamBPlain (Backing = OwningBulkBacking, Escapable OwningBulkIterator) inherits
// B-default-2 and runs [7,8,9]. So a SINGLE family protocol serves BOTH the span-projecting (copy-self)
// family AND the plain-iterator family — the two defaults differ in lifetime annotation, which is fine
// because each is gated on a different (mutually exclusive) constraint and the return type's escapability
// follows Backing.Iterator. This is a genuine unification at the PROTOCOL level (one protocol, two
// defaults), distinct from Angle A's "one default for everything."
//
// IMPORTANT INTERACTION WITH THE A2 BUG (decision-relevant, surfaced per Ground Rule 6): an EARLIER
// Angle-B plain conformer used PlainTreeBacking — a @_lifetime(immortal) ~Escapable wrapper over a boxed
// TreeNode walker. That conformer DISPATCHED correctly and ran in debug, but CRASHED `swift build -c
// release` with the SAME forwardToInit / "nonCopyable from guaranteed value" bug as A2 (verified: the
// crash named makeIteratorB specialized for FamBTree). Switching the plain conformer to a GENUINELY
// ESCAPABLE owning walker (OwningBulkIterator, no immortal-~Escapable) made release clean. So Angle B's
// DISPATCH MECHANISM is sound debug+release; the only release hazard is the orthogonal A2 compiler bug,
// which fires whenever an immortal-~Escapable walker is specialized through ANY generic family default
// (FamD's makeIteratorD1 OR FamB's makeIteratorB) — independent of Angle B itself.
