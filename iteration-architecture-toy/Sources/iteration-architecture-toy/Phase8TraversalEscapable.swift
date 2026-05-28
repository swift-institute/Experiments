// MARK: - Phase 8 (Angle A) — RE-ATTACK non-contiguous D1 with a ~Escapable, self-lifetime-tied walker
// Phase6 REFUTED traversal-only D1 — BUT it used the EASY Escapable walker: TreeInOrderIterator /
// HashChainIterator are plain `struct`s owning `[TreeNode]` stacks / `[[Int]]` arrays, i.e.
// ESCAPABLE, so `@_lifetime(copy self)` was "invalid on an Escapable result." That refuted only ONE
// formulation. The supervisor's lead hypothesis (Angle A): re-do the walker as a ~Escapable type
// whose lifetime is bound to the container (so it is lifetime-dependent, like Iterator.Ring in
// Phase5), and see whether it then satisfies the D1 IterableByCopy (@_lifetime(copy self)) contract
// exactly as the span view does.
//
// The crux discriminator vs Phase5: a span-projecting backing has a Span to borrow; a tree/hash walk
// needs a STACK / per-bucket cursor whose SIZE is data-dependent (not a fixed set of spans). Phase8
// tests the most span-like traversal shape first: nodes stored in ONE contiguous array, children
// addressed by INDEX, the walker borrowing that node array as a Span<Node> (genuinely lifetime-
// dependent on self) and carrying an INTERNAL index-stack for the traversal frontier.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0
// Result (A): A1 CONFIRMED (debug+release); A2 PARTIAL (debug OK, RELEASE COMPILER CRASH through the
//   generic family default — routable-around via A2-direct + A2b, both release-clean). A3 (hash) +
//   A4 (~Copyable boundary) in Phase9. Per-sub-angle VERDICTs inline below.
//
// Sub-angles, attacked in order (first clean signal per [EXP-011a]):
//   A1  ~Escapable walker borrowing a Span<Node> of an INDEX-ADDRESSED tree + internal index-stack.
//       (Most span-like: there genuinely IS a region to borrow → @_lifetime(copy self) may be valid.)
//   A2  ~Escapable walker over a BOXED-node tree (no array): can a ~Escapable walker tie @_lifetime,
//       and does routing it through the generic family default survive release optimization?

// =====================================================================================
// MARK: A1 — index-addressed tree, ~Escapable walker borrowing a Span<Node>
// =====================================================================================

// A flat, value-type tree: nodes in one array; children referenced by index (-1 == none). This is
// the canonical "non-contiguous logically, contiguous physically" shape (heap-style storage). There
// IS a single span (the node array) to borrow — so a ~Escapable walker over it is lifetime-dependent
// on self, exactly like Iterator.Ring borrows its segment spans.
public struct TreeFlatNode {
    @usableFromInline var value: Int
    @usableFromInline var left: Int    // index into the node array, or -1
    @usableFromInline var right: Int   // index into the node array, or -1
    @inlinable public init(value: Int, left: Int, right: Int) {
        self.value = value
        self.left = left
        self.right = right
    }
}

// A ~Escapable in-order walker. Holds:
//   - a Span<TreeFlatNode> borrowing the container's node array (the lifetime-dependent field), and
//   - an INTERNAL index stack (frontier) + a current index.
// The Span makes the walker ~Escapable (lifetime = the borrow it copies in via @_lifetime(copy span)),
// so makeIterator on a view of it can be @_lifetime(copy self) — the D1 contract. The frontier stack
// is plain owned [Int] state (indices, not borrows); a ~Escapable struct may hold Escapable fields.
public extension Iterator {
    @frozen
    struct FlatTreeInOrder<Element>: ~Escapable {
        @usableFromInline var nodes: Span<TreeFlatNode>
        @usableFromInline var stack: [Int]
        @usableFromInline var current: Int
        @usableFromInline let project: (TreeFlatNode) -> Element
        @_lifetime(copy nodes)
        @inlinable
        public init(
            nodes: consuming Span<TreeFlatNode>,
            root: Int,
            project: @escaping (TreeFlatNode) -> Element
        ) {
            self.nodes = nodes
            self.stack = []
            self.current = root
            self.project = project
        }
    }
}

extension Iterator.FlatTreeInOrder: Iterator.`Protocol` {
    @inlinable
    public mutating func next() -> Element? {
        // Iterative in-order over the index-addressed node array.
        while current != -1 {
            stack.append(current)
            current = nodes[current].left
        }
        guard let i = stack.popLast() else { return nil }
        let node = nodes[i]
        current = node.right
        return project(node)
    }
}

// A ~Escapable VIEW over the flat tree's node span, with a @_lifetime(copy self) makeIterator (D1).
// Structurally identical to Memory.RingView (Phase5) — it just builds a tree walker instead of a
// ring walker. If A1 works, traversal-only enters the D1 envelope via the SAME copy-self mechanism.
public extension Memory {
    @frozen
    struct FlatTreeView: ~Copyable, ~Escapable {
        @usableFromInline let nodes: Span<TreeFlatNode>
        @usableFromInline let root: Int
        @_lifetime(copy nodes)
        @inlinable public init(nodes: consuming Span<TreeFlatNode>, root: Int) {
            self.nodes = nodes
            self.root = root
        }
    }
}

extension Memory.FlatTreeView: IterableByCopy {
    public typealias Element = Int
    public typealias Iterator = iteration_architecture_toy.Iterator.FlatTreeInOrder<Int>
    @_lifetime(copy self)
    public borrowing func makeIterator() -> iteration_architecture_toy.Iterator.FlatTreeInOrder<Int> {
        iteration_architecture_toy.Iterator.FlatTreeInOrder(nodes: nodes, root: root) { $0.value }
    }
}

// A concrete flat-tree container that rides the FamD (D1) family default — exactly like ToyRing.
public struct ToyFlatTree: ~Copyable {
    @usableFromInline var nodes: [TreeFlatNode]
    @usableFromInline let root: Int
    @inlinable public init(nodes: [TreeFlatNode], root: Int) {
        self.nodes = nodes
        self.root = root
    }
}

extension ToyFlatTree: FamD.`Protocol` {
    public typealias Element = Int
    public typealias View = Memory.FlatTreeView
    public var view: Memory.FlatTreeView {
        @_lifetime(borrow self) get {
            Memory.FlatTreeView(nodes: nodes.span, root: root)
        }
    }
    // makeIteratorD1() inherited from FamD.`Protocol` default — delegates view.makeIterator().
}

// MARK: VERDICT (Angle A1) — CONFIRMED (compiles checker-clean + WARNING-CLEAN, runs in-order
// [1,2,3,4,5,6,7], debug AND release). An index-addressed (physically contiguous) tree DOES enter
// the D1 envelope: a ~Escapable walker that borrows the node array as a Span<TreeFlatNode> (lifetime-
// dependent on self via @_lifetime(copy nodes)) and carries an INTERNAL index-stack satisfies the D1
// IterableByCopy @_lifetime(copy self) contract exactly as Memory.RingView does for the ring. The
// traversal LOGIC (in-order over an index-addressed tree) is irrelevant to the lifetime mechanics;
// what matters is that the walker borrows a real memory region (the node span). This OVERTURNS the
// Phase6 refutation FOR HEAP-STYLE / FLAT-STORAGE trees: they are span-projecting after all (one span
// = the node array), so they ride the SAME FamD.`Protocol` makeIteratorD1 default as arrays/rings.
// CAVEAT (decision-relevant): A1's tree is PHYSICALLY CONTIGUOUS (nodes in [TreeFlatNode], children
// by index). It is "non-contiguous" only LOGICALLY (traversal order ≠ storage order). A genuinely
// BOXED-pointer tree (TreeNode class refs, Phase6's shape) has NO span at all — that is A2.

// =====================================================================================
// MARK: A2 — boxed-node tree (NO array, NO span): can a ~Escapable walker tie @_lifetime(copy self)?
// =====================================================================================
// A1 worked because a flat tree HAS a span (the node array). A genuinely boxed tree (TreeNode class
// nodes linked by optional refs — Phase6's ToyTree / TreeInOrderIterator) has NO contiguous region.
// The supervisor's Angle-A formulation: make the walker ~Escapable and tie its lifetime to the
// container via @_lifetime(borrow/copy self) even though it holds only ARC refs + a frontier stack.
// Hypothesis: declaring the walker `: ~Escapable` (despite holding only Escapable fields) lets it
// take @_lifetime(copy self) and witness D1. If a ~Escapable struct with NO lifetime-dependent field
// can carry @_lifetime, A2 confirms boxed trees too; if @_lifetime is rejected because the struct has
// nothing to depend on (it is "really" Escapable), A2 isolates exactly where D1 stops.

// A boxed-node walker declared ~Escapable, holding ONLY ARC refs + an Escapable [TreeNode] frontier.
// (Reuses Phase6's TreeNode class.) There is no span / borrowed region — the question is whether the
// ~Escapable annotation alone admits @_lifetime(copy self) on a view's makeIterator.
public extension Iterator {
    @frozen
    struct BoxedTreeInOrder: ~Escapable {
        @usableFromInline var stack: [TreeNode]
        @usableFromInline var current: TreeNode?
        @_lifetime(immortal)
        @inlinable
        public init(root: TreeNode?) {
            self.stack = []
            self.current = root
        }
    }
}

extension Iterator.BoxedTreeInOrder: Iterator.`Protocol` {
    public typealias Element = Int
    @inlinable
    public mutating func next() -> Int? {
        while let node = current {
            stack.append(node)
            current = node.left
        }
        guard let node = stack.popLast() else { return nil }
        current = node.right
        return node.value
    }
}

// A ~Escapable VIEW over a boxed tree (holds only the root ARC ref), @_lifetime(copy self) makeIterator.
public extension Memory {
    @frozen
    struct BoxedTreeView: ~Copyable, ~Escapable {
        @usableFromInline let root: TreeNode?
        @_lifetime(immortal)
        @inlinable public init(root: TreeNode?) {
            self.root = root
        }
    }
}

extension Memory.BoxedTreeView: IterableByCopy {
    public typealias Element = Int
    public typealias Iterator = iteration_architecture_toy.Iterator.BoxedTreeInOrder
    @_lifetime(copy self)
    public borrowing func makeIterator() -> iteration_architecture_toy.Iterator.BoxedTreeInOrder {
        iteration_architecture_toy.Iterator.BoxedTreeInOrder(root: root)
    }
}

// A boxed-tree container riding FamD (D1).
public struct ToyBoxedTree: ~Copyable {
    @usableFromInline let root: TreeNode?
    @inlinable public init(root: TreeNode?) { self.root = root }
}

extension ToyBoxedTree: FamD.`Protocol` {
    public typealias Element = Int
    public typealias View = Memory.BoxedTreeView
    public var view: Memory.BoxedTreeView {
        @_lifetime(borrow self) get { Memory.BoxedTreeView(root: root) }
    }
}

// MARK: VERDICT (Angle A2) — PARTIAL: COMPILES + RUNS DEBUG, but RELEASE COMPILER CRASH through the
// family default (the deliverable path). A genuinely BOXED tree (TreeNode class refs, NO span — exactly
// Phase6's ToyTree shape) DOES compile under D1: the walker is `: ~Escapable`, holds ONLY ARC refs + an
// Escapable [TreeNode] frontier stack, init @_lifetime(immortal); the ~Escapable VIEW @_lifetime(immortal);
// the view's makeIterator @_lifetime(copy self). All accepted, checker-clean + warning-clean. DEBUG runs
// in-order [1,2,3,4,5,6,7]. BUT `swift build -c release` CRASHES THE COMPILER while specializing the
// generic FamD family default for ToyBoxedTree:
//   Abort: function forwardToInit at SILValue.h:375
//   Cannot initialize a nonCopyable type with a guaranteed value
//   While running pass #… "EarlyPerfInliner" on SILFunction "@iteration_architecture_toy_main".
//   While inlining SIL function "@…FamDO8Protocol…makeIteratorD1…ToyBoxedTreeV_Tg5"
//   command (swift build -c release)
//
// CRITICAL DISCRIMINATION (this is a REAL ~Escapable, not a vacuous escape hatch): a ~Escapable type
// holding only Escapable fields with an @_lifetime(immortal) INIT is NOT freely-escapable at the USE
// site. Verified by two probes (since removed):
//   (tied)  `@_lifetime(borrow tree) func f(_ tree: borrowing ToyBoxedTree) -> Iterator.BoxedTreeInOrder
//             { tree.makeIteratorD1() }`  → COMPILES (the family default ties the result to borrow self).
//   (free)  `func g() -> Iterator.BoxedTreeInOrder { let t = ToyBoxedTree(root: …); return t.makeIteratorD1() }`
//             → ERROR: "a function with a ~Escapable result needs a parameter to depend on"
// The (free) refutation proves the walker is a TRUE ~Escapable result. So `immortal` on the init is
// "introduces no borrow on construction," NOT "escapes freely."
//
// CRASH TRIGGER FULLY ISOLATED (per [EXP-021], one factor at a time — see A2-direct + A2b below):
//   • A2-direct: SAME boxed walker via `view.makeIterator()` DIRECTLY (NOT the generic family default)
//     → RELEASE CLEAN + runs. So the crash is NOT in the boxed walker, NOR the copy-self makeIterator.
//   • A2b: boxed walker that ALSO holds a REAL Span<Int> field (genuine lifetime, not immortal), routed
//     THROUGH the family default → RELEASE CLEAN + runs. So the crash is NOT the boxed/ARC walk per se.
//   ⇒ The trigger is EXACTLY: a ~Escapable walker with @_lifetime(immortal) (a `~Escapable` value with
//     NO borrowed region — only ARC refs) routed THROUGH the generic `makeIteratorD1` family default,
//     specialized under release -O. Give the walker any real borrowed region (A1's Span<Node>, A2b's
//     Span<Int>) and the crash disappears. This is a SIL-optimizer/inliner bug, NOT a language wall.
//
// WHAT THIS MEANS FOR THE GOAL: a SINGLE unified family default (FamD.makeIteratorD1) DOES cover boxed
// traversal-only structures AT THE LANGUAGE LEVEL (it compiles + runs debug; the direct path is release-
// clean). The ONLY thing blocking boxed-via-family-default in release is a compiler crash on the
// immortal-walker specialization. The clean workaround that stays inside the unified family is to give
// the walker a real borrowed region (A2b) — e.g. let the boxed-tree view borrow the container's node
// pool / a header span — so the lifetime is genuine and the inliner is happy. Flat/heap trees (A1) are
// already in this happy case. (Honest note: this is a workaround for a compiler bug, surfaced per Ground
// Rule 6, not a clean language outcome for the pure-ARC boxed walker.)

// MARK: A2-direct (permanent) — SAME boxed walker via direct view.makeIterator(), bypassing the family
// default. RELEASE CLEAN + runs [1,2,3,4,5,6,7] → localizes the A2 release crash to the generic default.
public func a2DirectView() -> [Int] {
    let root = TreeNode(4,
        left: TreeNode(2, left: TreeNode(1), right: TreeNode(3)),
        right: TreeNode(6, left: TreeNode(5), right: TreeNode(7)))
    let tree = ToyBoxedTree(root: root)
    let view = tree.view
    var it = view.makeIterator()
    var out: [Int] = []
    while let v = it.next() { out.append(v) }
    return out
}

// =====================================================================================
// MARK: A2b (permanent) — boxed walker that ALSO holds a REAL Span (not immortal), via family default.
// Isolates whether the release crash is triggered by `@_lifetime(immortal)` (no borrowed region) or
// by the boxed/ARC nature per se. Here the walker/view hold a genuine Span<Int> borrowed from a side
// array in the container (so the lifetime is REAL, @_lifetime(copy span), like A1) AND a boxed root
// ref it walks. Routed through makeIteratorD1 (the family default) → RELEASE CLEAN + runs [1..7].
// CONCLUSION: the A2 crash is the @_lifetime(immortal) walker through the generic default; a real
// borrowed region inside the walker is the clean in-family workaround for the boxed case.
public struct TreeBoxedWithSideArray: ~Copyable {
    @usableFromInline let root: TreeNode?
    @usableFromInline var side: [Int]   // a real contiguous region to borrow (1 elem; unused logically)
    @inlinable public init(root: TreeNode?) { self.root = root; self.side = [0] }
}

public extension Iterator {
    @frozen
    struct BoxedTreeInOrderReal: ~Escapable {
        @usableFromInline let span: Span<Int>          // REAL borrowed region → genuine lifetime
        @usableFromInline var stack: [TreeNode]
        @usableFromInline var current: TreeNode?
        @_lifetime(copy span)
        @inlinable public init(span: consuming Span<Int>, root: TreeNode?) {
            self.span = span
            self.stack = []
            self.current = root
        }
    }
}

extension Iterator.BoxedTreeInOrderReal: Iterator.`Protocol` {
    public typealias Element = Int
    @inlinable public mutating func next() -> Int? {
        while let node = current { stack.append(node); current = node.left }
        guard let node = stack.popLast() else { return nil }
        current = node.right
        return node.value
    }
}

public extension Memory {
    @frozen
    struct BoxedTreeViewReal: ~Copyable, ~Escapable {
        @usableFromInline let span: Span<Int>
        @usableFromInline let root: TreeNode?
        @_lifetime(copy span)
        @inlinable public init(span: consuming Span<Int>, root: TreeNode?) {
            self.span = span
            self.root = root
        }
    }
}

extension Memory.BoxedTreeViewReal: IterableByCopy {
    public typealias Element = Int
    public typealias Iterator = iteration_architecture_toy.Iterator.BoxedTreeInOrderReal
    @_lifetime(copy self)
    public borrowing func makeIterator() -> iteration_architecture_toy.Iterator.BoxedTreeInOrderReal {
        iteration_architecture_toy.Iterator.BoxedTreeInOrderReal(span: span, root: root)
    }
}

extension TreeBoxedWithSideArray: FamD.`Protocol` {
    public typealias Element = Int
    public typealias View = Memory.BoxedTreeViewReal
    public var view: Memory.BoxedTreeViewReal {
        @_lifetime(borrow self) get { Memory.BoxedTreeViewReal(span: side.span, root: root) }
    }
}
