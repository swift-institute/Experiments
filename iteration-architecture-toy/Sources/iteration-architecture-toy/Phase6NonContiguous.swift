// MARK: - Phase 6 (Gap b) — NON-CONTIGUOUS backing: NO span at all (tree / hash)
// D1 and shape-b both PROJECT a Span. Trees (boxed nodes) and hashes (array-of-buckets with
// per-bucket chains) have NO single span and NO contiguous element storage to project — the
// iterator must WALK nodes/buckets by reference. This is the crux for trees/hashes/graphs.
//
// Hypothesis: can D1 (a @_lifetime(copy self) makeIterator family default delegating through a
// ~Escapable Backing view) be expressed when there is NO span to project — the view's iterator
// walks nodes? Or does non-contiguous force route-3 (forEach internal iteration, shape C) and/or
// a per-variant external iterator instead of a family default?
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0
// Result: D1 family default REFUTED for non-contiguous; PLAIN external makeIterator + route-3
//   forEach (shape C) SURVIVE. Verified compile + run, debug AND release, warning-clean.
//   Runs:  tree in-order [1,2,3,4,5,6,7] (plain makeIterator) / tree forEach sum=28
//          hash chains   [10,11,22,30,31,32] (plain makeIterator)
//   Refutation diagnostic (D1, Tree.View conforming IterableByCopy):
//     error: invalid lifetime dependence on an Escapable result   (@_lifetime(copy self) makeIterator)
// What this rules out: the COPY-SELF view backing (D1) is structurally inapplicable to storage
// with NO span. D1's @_lifetime(copy self) requires a ~Escapable (lifetime-dependent) iterator;
// a node/bucket-walking iterator holds ARC refs / value arrays, so it is ESCAPABLE and @_lifetime
// is rejected on it. Trees/hashes/graphs therefore CANNOT share the contiguous family's D1
// makeIterator default. They use EITHER a plain (non-lifetime) Sequence-style makeIterator (a
// different protocol, no ~Copyable/borrow/copy regime) OR route-3 forEach (shape C). Both work as
// family defaults trivially because neither involves a lifetime-dependent return value.

// MARK: A small binary tree of BOXED (class) nodes — the canonical non-contiguous shape.
public final class TreeNode {
    public var value: Int
    public var left: TreeNode?
    public var right: TreeNode?
    public init(_ value: Int, left: TreeNode? = nil, right: TreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

// MARK: An in-order TREE ITERATOR walking node references (NO span). Holds an explicit stack of
// node references. Because TreeNode is a class (Escapable, ARC-managed), the iterator borrows no
// memory region — it is itself Escapable and carries NO @_lifetime on next().
public struct TreeInOrderIterator {
    @usableFromInline var stack: [TreeNode]
    @usableFromInline var current: TreeNode?
    @inlinable public init(root: TreeNode?) {
        self.stack = []
        self.current = root
    }
}

extension TreeInOrderIterator: Iterator.`Protocol` {
    public typealias Element = Int
    @inlinable
    public mutating func next() -> Int? {
        // Standard iterative in-order traversal over node references.
        while let node = current {
            stack.append(node)
            current = node.left
        }
        guard let node = stack.popLast() else { return nil }
        current = node.right
        return node.value
    }
}

// MARK: A small array-of-buckets HASH (separate chaining) — the other non-contiguous shape.
// Buckets are [[Int]]; logical iteration walks bucket 0 chain, bucket 1 chain, … NO single span.
public struct ToyHash {
    @usableFromInline var buckets: [[Int]]
    @inlinable public init(buckets: [[Int]]) { self.buckets = buckets }
}

public struct HashChainIterator {
    @usableFromInline let buckets: [[Int]]
    @usableFromInline var bucketIndex: Int
    @usableFromInline var slotIndex: Int
    @inlinable public init(buckets: [[Int]]) {
        self.buckets = buckets
        self.bucketIndex = 0
        self.slotIndex = 0
    }
}

extension HashChainIterator: Iterator.`Protocol` {
    public typealias Element = Int
    @inlinable
    public mutating func next() -> Int? {
        while bucketIndex < buckets.count {
            let chain = buckets[bucketIndex]
            if slotIndex < chain.count {
                defer { slotIndex &+= 1 }
                return chain[slotIndex]
            }
            bucketIndex &+= 1
            slotIndex = 0
        }
        return nil
    }
}

// MARK: Sub-test b1 (REFUTED, verified) — can a non-contiguous container ride the D1 family
// default (FamD.`Protocol`)?  NO. FamD's `View: IterableByCopy` requires a @_lifetime(copy self)
// makeIterator, but @_lifetime is ONLY valid on a ~Escapable result. A non-contiguous iterator
// walks ARC-managed node references / value-array buckets — it borrows no memory region, so it is
// Escapable. An Escapable iterator cannot carry @_lifetime, so it cannot witness IterableByCopy.
// Exact diagnostic (Tree.View conforming IterableByCopy with a TreeInOrderIterator):
//   error: invalid lifetime dependence on an Escapable result
//     @_lifetime(copy self)
//     public borrowing func makeIterator() -> TreeInOrderIterator { ... }
// So the COPY-SELF view backing (D1) is structurally inapplicable to non-contiguous storage:
// D1's machinery exists to flatten a borrow-self SPAN dependency; with no span, there is no
// lifetime to copy, and the @_lifetime annotation the protocol demands is itself invalid.
//
//   public enum Tree {}
//   public extension Tree { @frozen struct View: ~Copyable, ~Escapable { let root: TreeNode? … } }
//   extension Tree.View: IterableByCopy {
//       @_lifetime(copy self)                          // ❌ invalid on Escapable result
//       public borrowing func makeIterator() -> TreeInOrderIterator { … }
//   }

// Concrete non-contiguous containers (own only ARC refs / value arrays — Copyable, Escapable).
public struct ToyTree {
    @usableFromInline let root: TreeNode?
    @inlinable public init(root: TreeNode?) { self.root = root }
}

// MARK: Sub-test b2 (SURVIVING ROUTE — external makeIterator) — a PLAIN (non-lifetime) makeIterator.
// Because the iterator is Escapable, the right protocol is a plain `Sequence`-style makeIterator
// with NO @_lifetime — not the copy-self IterableByCopy. The container is itself Escapable/Copyable
// (it owns only ARC refs / value arrays), so this is an ordinary makeIterator, NOT the ~Copyable /
// borrow-self / copy-self lifetime regime at all. It works — but it is a DIFFERENT protocol from
// D1, and being plain it can live as a family default OR per-variant trivially.
public protocol PlainSequence {
    associatedtype Element
    associatedtype Iterator: iteration_architecture_toy.Iterator.`Protocol`
        where Iterator.Element == Element
    borrowing func makeIterator() -> Iterator
}

extension ToyTree: PlainSequence {
    public typealias Element = Int
    public typealias Iterator = TreeInOrderIterator
    public borrowing func makeIterator() -> TreeInOrderIterator {
        TreeInOrderIterator(root: root)
    }
}

extension ToyHash: PlainSequence {
    public typealias Element = Int
    public typealias Iterator = HashChainIterator
    public borrowing func makeIterator() -> HashChainIterator {
        HashChainIterator(buckets: buckets)
    }
}

// MARK: Sub-test b3 (SURVIVING ROUTE — route-3 forEach, shape C) — internal iteration.
// forEach returns Void → no lifetime-dependent value → no span needed. This is the route that
// unifies contiguous + non-contiguous for INTERNAL iteration. A borrowing forEach walking nodes:
extension ToyTree: BorrowForEachable {
    public borrowing func forEach(_ body: (borrowing Int) -> Void) {
        // recursive in-order walk over node refs; no span, no lifetime dependence.
        func walk(_ node: TreeNode?) {
            guard let node else { return }
            walk(node.left)
            body(node.value)
            walk(node.right)
        }
        walk(root)
    }
}

extension ToyHash: BorrowForEachable {
    public borrowing func forEach(_ body: (borrowing Int) -> Void) {
        for chain in buckets { for value in chain { body(value) } }
    }
}

// MARK: VERDICT (Gap b — non-contiguous): D1 REFUTED; PLAIN makeIterator + route-3 forEach SURVIVE.
// A backing with NO span (tree of boxed nodes, array-of-buckets hash) CANNOT use the D1 copy-self
// family default: @_lifetime(copy self) is "invalid on an Escapable result", and a node/bucket
// iterator is necessarily Escapable. The surviving routes are (1) a PLAIN external makeIterator on
// a non-lifetime Sequence-style protocol — distinct from the contiguous family's copy-self
// IterableByCopy — and (2) route-3 forEach (shape C), internal iteration with no lifetime-dependent
// value. IMPLICATION FOR THE DECISION: the ambitious "single D1 family default across ~18 packages"
// does NOT cover trees/hashes/graphs. Those need a SECOND iteration shape — a plain Escapable
// makeIterator and/or forEach — that is structurally distinct from D1. This is itself gating
// evidence (per Ground Rule 6): non-contiguous structures fall OUTSIDE the D1 family envelope.
