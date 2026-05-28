// MARK: - Phase 5 (Gap a) — PIECEWISE backing: can D1 survive a TWO-SEGMENT view?
// D1 was proven only for a CONTIGUOUS backing (one Span). The ~18 data-structure packages
// include Buffer.Ring-style containers: a fixed array used as a ring, whose logical order is
// `head..<capacity` then `0..<tail` after wraparound — TWO logical segments, NO single span.
//
// Hypothesis: the D1 @_lifetime(copy self) makeIterator-delegation-via-Backing still composes
// when the ~Escapable view's iterator must walk TWO spans (held in the view + the iterator)
// instead of one. If `copy self` flattens a view holding two borrow-self spans the same way it
// flattens one, D1 generalises to piecewise. If holding a second span breaks the flatten, that
// rules piecewise OUT of the family default and forces per-variant / route-3.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0
// Result: CONFIRMED (compiles checker-clean + runs, debug AND release, WARNING-CLEAN, no `unsafe`).
//   Run: gap (a) piecewise ring (D1 over two segments): [50, 60, 10, 20, 30]
//   (head=4,tail=3 over capacity-6 storage → logical order storage[4..<6] ++ storage[0..<3].)
// Status: D1 generalises from one span to N segments. The ONLY delta from the contiguous D1 is
//   that a view/iterator holding K lifetime-dependent fields must declare @_lifetime(copy …) for
//   EACH (`@_lifetime(copy a, copy b)`), not just the first. A single-arg @_lifetime(copy a) on a
//   two-span init produced the diagnostic below (mechanical annotation gap, not a refutation):
//     error: lifetime-dependent variable 'self' escapes its scope
//       public init(a: consuming Span<Element>, b: consuming Span<Element>) {
//         note: it depends on the lifetime of argument 'b'
//   Adding `copy b` to the dependency list cleared it. PIECEWISE does NOT force route-3; the
//   copy-self view backing carries makeIterator delegation once for ring/deque-shaped containers
//   exactly as it does for contiguous ones.

// MARK: A two-segment iterator — walks span `a` (head..<capacity) then span `b` (0..<tail).
public extension Iterator {
    @frozen
    struct Ring<Element>: ~Escapable {
        @usableFromInline var a: Span<Element>   // first logical segment
        @usableFromInline var b: Span<Element>   // second logical segment (post-wraparound)
        @usableFromInline var position: Int      // global position across a ++ b
        // Two stored spans → the iterator depends on BOTH segment lifetimes.
        @_lifetime(copy a, copy b)
        @inlinable
        public init(a: consuming Span<Element>, b: consuming Span<Element>) {
            self.a = a
            self.b = b
            self.position = 0
        }
    }
}

extension Iterator.Ring: Iterator.`Protocol` {
    @inlinable
    public mutating func next() -> Element? {
        let countA = a.count
        if position < countA {
            defer { position &+= 1 }
            return a[position]
        }
        let j = position &- countA
        guard j < b.count else { return nil }
        defer { position &+= 1 }
        return b[j]
    }
}

// MARK: A ~Escapable RING VIEW holding two spans, with a @_lifetime(copy self) makeIterator (D1).
public extension Memory {
    @frozen
    struct RingView<Element>: ~Copyable, ~Escapable {
        @usableFromInline let a: Span<Element>
        @usableFromInline let b: Span<Element>
        // The view holds TWO segment spans; its lifetime depends on BOTH. copy-self on the view
        // propagates the (merged) enclosing dependency to the iterator.
        @_lifetime(copy a, copy b)
        @inlinable public init(a: consuming Span<Element>, b: consuming Span<Element>) {
            self.a = a
            self.b = b
        }
    }
}

extension Memory.RingView: IterableByCopy {
    public typealias Iterator = iteration_architecture_toy.Iterator.Ring<Element>
    @_lifetime(copy self)
    public borrowing func makeIterator() -> iteration_architecture_toy.Iterator.Ring<Element> {
        iteration_architecture_toy.Iterator.Ring(a: a, b: b)
    }
}

// MARK: A concrete ring container — fixed backing array used circularly.
// Logical order: storage[head..<capacity] then storage[0..<tail]. The view projects BOTH
// segments as spans; the family default (makeIteratorD1) delegates through the view.
public struct ToyRing: ~Copyable {
    @usableFromInline var storage: [Int]   // capacity slots; ring uses head..<cap ++ 0..<tail
    @usableFromInline let head: Int
    @usableFromInline let tail: Int
    @inlinable public init(storage: [Int], head: Int, tail: Int) {
        self.storage = storage
        self.head = head
        self.tail = tail
    }
}

extension ToyRing: FamD.`Protocol` {
    public typealias Element = Int
    public typealias View = Memory.RingView<Int>
    public var view: Memory.RingView<Int> {
        @_lifetime(borrow self) get {
            // Project the two logical segments as sub-spans of the same backing storage.
            let whole = storage.span
            let segA = whole.extracting(head..<storage.count)
            let segB = whole.extracting(0..<tail)
            return Memory.RingView(a: segA, b: segB)
        }
    }
    // makeIteratorD1() inherited from FamD.`Protocol` default — delegates view.makeIterator().
}

// MARK: VERDICT (Gap a — piecewise): CONFIRMED. D1 (@_lifetime(copy self) makeIterator delegation
// via a ~Escapable Backing view) survives a TWO-SEGMENT backing with NO single span. The view and
// its iterator each hold two spans; declaring @_lifetime(copy a, copy b) flattens BOTH borrow-self
// dependencies into the iterator. Compiles checker-clean (no `unsafe`) and runs in logical order,
// debug + release. Implication: ring/deque-shaped (piecewise-contiguous) variants can use the SAME
// family-default makeIterator as contiguous ones; piecewise does NOT force route-3 or per-variant.
