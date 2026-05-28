// MARK: - Phase 11 (Angle C) — forEach-CENTRIC family delegation as the UNIFIED primary vehicle.
// Route-3 forEach (shape C) is already confirmed universal (Phase6 b3: Void return, no lifetime-dependent
// value, works contiguous + non-contiguous). Angle C asks: can a family whose PRIMARY iteration vehicle
// is a single `forEach` family default (with external makeIterator as a secondary/optional witness) unify
// span-projecting + traversal-only TRIVIALLY — including ~Copyable elements and boxed trees — under ONE
// family protocol with ONE default?
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0
//
// The discriminator vs A/B: A/B route an EXTERNAL ITERATOR (a lifetime-dependent ~Escapable return) and
// so are subject to the copy-self machinery + the A2 forwardToInit bug + the A4 ~Copyable-return wall.
// forEach returns Void and LENDS each element via a `(borrowing Element) -> Void` closure — so it has NO
// lifetime-dependent return, needs NO copy-self view, and CAN carry ~Copyable elements (the closure
// borrows; nothing is moved out). Hypothesis: ONE FamC.forEach default covers ALL backings uniformly.

// A single family protocol whose Backing is a BorrowForEachable; forEach is the one delegated default.
public enum FamC {}
public extension FamC {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype Backing: ~Copyable & ~Escapable
            where Backing: BorrowForEachable, Backing.Element == Element
        var backing: Backing { @_lifetime(borrow self) get }
    }
}

// THE single forEach family default — delegates to backing.forEach. Body lives ONCE; all conformers
// (span / boxed-tree / ~Copyable) inherit it. (Same shape as MyFamily's C default, but here it is the
// PRIMARY and only iteration vehicle of the family — Angle C's framing.)
public extension FamC.`Protocol` where Self: ~Copyable & ~Escapable {
    borrowing func forEach(_ body: (borrowing Element) -> Void) {
        backing.forEach(body)
    }
}

// =====================================================================================
// MARK: Conformer 1 — SPAN-PROJECTING (array). Backing = Memory.SpanView (BorrowForEachable). Int element.
// =====================================================================================
public struct FamCArray: ~Copyable {
    @usableFromInline var storage: [Int]
    @inlinable public init(_ storage: [Int]) { self.storage = storage }
    @usableFromInline var span: Span<Int> { @_lifetime(borrow self) get { storage.span } }
}

extension FamCArray: FamC.`Protocol` {
    public typealias Element = Int
    public typealias Backing = Memory.SpanView<Int>
    public var backing: Memory.SpanView<Int> {
        @_lifetime(borrow self) get { Memory.SpanView(self.span) }
    }
    // forEach inherited from the FamC default.
}

// =====================================================================================
// MARK: Conformer 2 — TRAVERSAL-ONLY BOXED TREE. Backing walks TreeNode refs; NO span, NO lifetime issue
// (forEach returns Void). This is the case that REFUTES under D1 (A2 release crash) but is TRIVIAL here.
// =====================================================================================
// A ~Escapable backing that forEach-walks boxed nodes. NB: it holds a REAL span (a 1-elem side array,
// like A2b) rather than @_lifetime(immortal) — NOT for the forEach mechanics (forEach returns Void and
// needs no lifetime), but PURELY to dodge the A2 forwardToInit compiler bug, which (verified below) fires
// whenever an @_lifetime(immortal) ~Escapable BACKING getter is specialized through ANY generic family
// default — including this forEach default. With a real borrowed region the bug disappears; the boxed
// tree still rides the ONE FamC.forEach default.
public struct BoxedTreeForEachBacking: ~Copyable, ~Escapable {
    @usableFromInline let root: TreeNode?
    @usableFromInline let anchor: Span<Int>   // real borrowed region (A2b workaround for the A2 bug)
    @_lifetime(copy anchor)
    @inlinable public init(root: TreeNode?, anchor: consuming Span<Int>) {
        self.root = root
        self.anchor = anchor
    }
}

extension BoxedTreeForEachBacking: BorrowForEachable {
    public typealias Element = Int
    public borrowing func forEach(_ body: (borrowing Int) -> Void) {
        func walk(_ node: TreeNode?) {
            guard let node else { return }
            walk(node.left)
            body(node.value)
            walk(node.right)
        }
        walk(root)
    }
}

public struct FamCBoxedTree: ~Copyable {
    @usableFromInline let root: TreeNode?
    @usableFromInline var side: [Int]
    @inlinable public init(root: TreeNode?) { self.root = root; self.side = [0] }
}

extension FamCBoxedTree: FamC.`Protocol` {
    public typealias Element = Int
    public typealias Backing = BoxedTreeForEachBacking
    public var backing: BoxedTreeForEachBacking {
        @_lifetime(borrow self) get { BoxedTreeForEachBacking(root: root, anchor: side.span) }
    }
    // forEach inherited from the FamC default — boxed tree, via the ONE family default.
}

// =====================================================================================
// MARK: Conformer 3 — ~COPYABLE ELEMENT (the crux A4 ruled out for D1). Backing = Memory.SpanView<Resource>
// (BorrowForEachable for ~Copyable). forEach LENDS each Resource by borrow — no move, no D1 wall.
// =====================================================================================
@safe
public struct FamCResources: ~Copyable {
    @usableFromInline let buffer: UnsafeMutableBufferPointer<Resource>
    @inlinable public init(_ ids: [Int]) {
        unsafe buffer = .allocate(capacity: ids.count)
        for i in ids.indices { unsafe buffer.initializeElement(at: i, to: Resource(id: ids[i])) }
    }
    @inlinable deinit {
        unsafe buffer.deinitialize()
        unsafe buffer.deallocate()
    }
    @usableFromInline var span: Span<Resource> {
        @_lifetime(borrow self) get {
            let s = unsafe Span(_unsafeElements: UnsafeBufferPointer(buffer))
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

extension FamCResources: FamC.`Protocol` {
    public typealias Element = Resource
    public typealias Backing = Memory.SpanView<Resource>
    public var backing: Memory.SpanView<Resource> {
        @_lifetime(borrow self) get { Memory.SpanView(self.span) }
    }
    // forEach((borrowing Resource) -> Void) inherited from the FamC default — ~Copyable, via ONE default.
}

// MARK: VERDICT (Angle C) — CONFIRMED (compiles checker-clean + WARNING-CLEAN, runs, debug AND release) —
// the MOST COMPLETE unification of the three angles. ONE FamC.`Protocol` with ONE forEach family default
// (backing.forEach delegation) covers ALL THREE backing classes uniformly:
//   • span-projecting array (Int element)        → sum=60
//   • traversal-only BOXED tree (no span)        → [1,2,3,4,5,6,7]   (the case A2 could not route via D1)
//   • ~Copyable elements (Resource)              → sum=600           (the case A4 ruled OUT for D1)
// forEach is uniquely suited to unification because it returns Void and LENDS each element via a
// `(borrowing Element) -> Void` closure: NO lifetime-dependent return (so no copy-self view, no A4
// move-out wall), and it carries ~Copyable elements natively (the closure borrows; nothing is moved).
// The boxed tree is TRIVIAL here — its forEach just walks node refs; there is no span to project and no
// lifetime to thread, which is exactly why D1 (external iterator) struggled and forEach does not.
//
// COST / TRADE-OFF (surfaced per Ground Rule 6 — decision-relevant):
//   • LOSES external-iterator ergonomics: forEach is INTERNAL iteration (push). No `var it = x.makeIterator();
//     while let e = it.next()` pull-style consumption, no lazy/partial/zip/peek composition, no early-exit
//     without a throwing/Bool-returning closure variant. Pull-style external iteration still needs A/B/D1
//     (Copyable) or a borrow-cursor (route-3 next()) for ~Copyable — forEach alone is not a full Sequence.
//   • SUPPORTS ~Copyable: YES (the crux) — this is forEach's decisive advantage over D1.
//   • A unified design likely wants BOTH: forEach (C) as the universal vehicle (all elements, all shapes),
//     PLUS an external makeIterator (D1/A copy-self for span-projecting Copyable; plain for Escapable) as
//     a SECONDARY witness where pull-style/Copyable consumption is wanted. That is the v1.1.0 §4 split,
//     now confirmed end-to-end across traversal-only + ~Copyable.
//
// A2-BUG GENERALIZATION (verified here): an EARLIER FamCBoxedTree used an @_lifetime(immortal) boxed
// backing; it ran in debug but CRASHED `swift build -c release` with the SAME forwardToInit bug — the
// crash named `forEach` specialized for FamCBoxedTree. So the bug is BROADER than A2's makeIterator: it
// fires whenever an @_lifetime(immortal) ~Escapable BACKING GETTER is specialized through ANY generic
// family default (makeIteratorD1 / makeIteratorB / forEach) — INDEPENDENT of the default's return type
// (forEach returns Void and still crashes). The A2b workaround (give the backing a real borrowed region)
// fixes all three. This is one compiler bug touching all three angles' boxed-immortal path, not three.
