// ===----------------------------------------------------------------------===//
//
// Probe 1b — dense topology over a sparse pool: `Storage.Contiguous<G2.Pool<…>>`.
//
// QUESTION (d): does putting a DENSE single-plane topology (`Storage.Contiguous`)
// over a SPARSE pool compile, and is it semantically sound?
//
// We CANNOT depend on the real `swift-storage-primitives` here: its
// `Storage Protocol Primitives` target (a transitive dep of
// `Storage Contiguous Primitives`) FAILS TO COMPILE under the required toolchain
// org.swift.64202605271a (Swift 6.5-dev). The exact upstream error is preserved in
// the `#if false` block below. To still answer (d) empirically we replicate the
// real `Storage.Contiguous` generic CONSTRAINT verbatim (it is short and its
// signature is the whole point) and feed it `G2.Pool<Node>`.
//
// ===----------------------------------------------------------------------===//

public import Index_Primitives
public import Store_Protocol_Primitives
import Cardinal_Primitive
import Ordinal_Primitive

extension G2 {
    /// A concrete `~Copyable` element, the slot payload for the probe.
    public struct Node: ~Copyable {
        public var id: Int
        public init(id: Int) { self.id = id }
    }
}

// MARK: - Local replica of Storage.Contiguous's generic constraint
//
// Copied VERBATIM (modulo namespace) from the real source:
//   swift-storage-primitives/.../Storage Contiguous Primitives/Storage.Contiguous.swift
//     public struct Contiguous<Substrate: Store.`Protocol` & ~Copyable>: ~Copyable
//     where Substrate.Element == Element { ... forwards the four ops unchanged ... }
//
// The real type is documented as "the trivial single-plane storage … forwards the
// four element-store operations unchanged", with any sparsity meant to be layered
// ABOVE by a Buffer occupancy discipline. This replica reproduces that exact
// posture: a thin dense forwarder. If `G2.Pool<Node>` satisfies the constraint
// here, it satisfies the real `Storage.Contiguous` constraint identically (same
// bound: `Store.`Protocol` & ~Copyable`, same element-equality requirement).

extension G2 {
    /// Faithful stand-in for `Storage<Element>.Contiguous<Substrate>`.
    public struct ContiguousReplica<
        Element: ~Copyable,
        Substrate: Store.`Protocol` & ~Copyable
    >: ~Copyable where Substrate.Element == Element {
        var _substrate: Substrate

        public init(_ substrate: consuming Substrate) {
            self._substrate = substrate
        }

        // The real type forwards all four element-store ops unchanged and is itself
        // a `Store.`Protocol`` conformer (dense). We forward identically.
        public var capacity: Index<Element>.Count { _substrate.capacity }

        public subscript(slot: Index<Element>) -> Element {
            _read { yield _substrate[slot] }
            _modify { yield &_substrate[slot] }
        }

        public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
            _substrate.initialize(at: slot, to: element)
        }

        public mutating func move(at slot: Index<Element>) -> Element {
            _substrate.move(at: slot)
        }
    }
}

extension G2.ContiguousReplica: Store.`Protocol` where Element: ~Copyable {}

// MARK: - The dense-over-sparse composition

extension G2 {
    /// Wraps a sparse `G2.Pool` in the dense `ContiguousReplica` and drives it.
    ///
    /// THE COMPILE ITSELF IS THE RESULT: `G2.Pool<Node>` satisfies the dense
    /// `Storage.Contiguous` constraint (`Store.`Protocol` & ~Copyable`,
    /// `Substrate.Element == Node`) with nothing to reject the sparsity.
    public static func denseOverSparse() {
        let pool = G2.Pool<Node>(capacity: Index<Node>.Count(Cardinal(UInt(4))))
        var dense = G2.ContiguousReplica<Node, G2.Pool<Node>>(pool)

        // The wrapper forwards `initialize(at:)` to the pool but has NO concept of
        // the pool's free-list: it never calls `allocate()`. We write slot 0 directly.
        let slot0 = Index<Node>.Count(Cardinal(UInt(0))).map(Ordinal.init)
        dense.initialize(at: slot0, to: G2.Node(id: 7))
        _ = dense[slot0].id

        // Slots 1..3 remain UNINITIALIZED. As a `Store.`Protocol`` conformer, `dense`
        // now advertises `capacity == 4` and the DENSE contract "every slot in
        // [0, capacity) is initialized" (see Store.Protocol+Sequence.swift's
        // precondition). Any dense consumer — `forEach`, `reduce`, a span read — would
        // touch slots 1..3 → UB. The type system cannot see the violation.

        _ = dense.move(at: slot0)  // clean up the one real slot
    }
}

// UPSTREAM BUILD BLOCKER (why we can't use the real Storage.Contiguous):
// ====================================================================
#if false
// Depending on `.product(name: "Storage Contiguous Primitives", package:
// "swift-storage-primitives")` and building under TOOLCHAINS=org.swift.64202605271a
// fails in an UPSTREAM file (not ours), `swift-storage-primitives`'s
// `Storage Protocol Primitives` target:
//
//   Sources/Storage Protocol Primitives/Store.Protocol+Sequence.swift:100:37:
//     error: parameter of noncopyable type 'Self.Element' must specify ownership
//   Sources/Storage Protocol Primitives/Store.Protocol+Sequence.swift:103:39:
//     error: parameter of noncopyable type 'Self.Element' must specify ownership
//   error: Build failed
//
// The offending code is the `Element: Equatable` convenience:
//
//   public func contains(_ element: Element) -> Bool {
//       contains(where: { (candidate: Element) -> Bool in candidate == element })
//       //                  ^^^^^^^^^^^^^^^^^ ~Copyable Element needs `borrowing`
//   }
//
// The package declares swift-tools-version 6.3.1; the closure parameter `candidate:
// Element` is accepted there but REJECTED by 6.5-dev, which requires an explicit
// ownership annotation (`borrowing candidate: Element`) for a ~Copyable-typed
// parameter. This is a toolchain/source skew in the real package, fixable only by
// editing the real source — which the experiment's ground rules forbid. Hence the
// local replica above.
#endif

// FINDING: dense `Storage.Contiguous` over a sparse pool
// ======================================================
//
// COMPILES: YES — `G2.Pool<Node>` satisfies the (replicated) `Storage.Contiguous`
// constraint. The bound is only `Store.`Protocol` & ~Copyable` + element equality;
// it has no axis on which to reject a sparse substrate. (The real type would accept
// it identically; only the unrelated upstream toolchain skew above stops us linking
// the literal type.)
//
// SEMANTICALLY SOUND: NO — wrong-but-compiles, a category error.
//   - `Storage.Contiguous` is the DENSE single-plane storage: it forwards the four
//     ops unchanged AND its derived traversals (`forEach`/`reduce`/`contains`, in
//     the very file that fails to build) carry the precondition "every slot in
//     [0, capacity) must be initialized." Sparsity is meant to be added ABOVE by a
//     Buffer occupancy discipline, never BELOW by the substrate.
//   - A pool is intrinsically sparse. Wrapping it in the dense plane ERASES the
//     free-list/occupancy truth (out-of-band in the pool) while ASSERTING the dense
//     contract upward. The two occupancy models are stacked with no reconciliation;
//     any dense consumer reading/destroying [0, capacity) hits uninitialized slots.
//   - This is exactly why the real ecosystem does NOT model a pool as
//     `Storage.Contiguous<pool>`: `Storage.Pool` is its OWN sparse single-region
//     discipline that conforms to `Store.`Protocol`` directly and vends
//     `Store.Initialization == .empty` (occupancy in its own bitmap). The dense
//     wrapper is reserved for genuinely-dense substrates (`Memory.Heap`,
//     `Memory.Contiguous`).
//
// TAKEAWAY: A pool can BE a `Store.`Protocol`` (Probe 1), but must NOT be dressed
// as a DENSE `Storage.Contiguous`. Dense-over-sparse type-checks but is unsound.
