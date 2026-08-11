// MARK: - Collection.Protocol ~Escapable Index — lifetime-annotation design space
// Purpose: Decide whether changing Collection.`Protocol`'s `Index` from a fixed
//   `typealias` to a `~Escapable`-admitting `associatedtype` (the #4 "support
//   ~Copyable/~Escapable where possible" directive) preserves the storable-index
//   contract — `formIndex(after: inout Index)`. A prior /tmp spike concluded "no"
//   using @_lifetime(borrow self); this experiment tests @_lifetime(copy i),
//   which the prior spike never tried.
//
// Hypothesis: A collection index's successor derives its validity from the INPUT
//   index, not from a fresh borrow of `self`. Annotating `index(after:)` with
//   @_lifetime(copy i) (not borrow self) should let the generic `formIndex`
//   default typecheck, making the ~Escapable-admitting bound free for the common
//   Escapable-index case.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108)
// Platform: macOS 26 (arm64)
//
// Variants (each its own target; build individually):
//   ProtocolV2     — @_lifetime(copy i)      — EXPECT CONFIRMED (compiles)
//   V1BorrowSelf   — @_lifetime(borrow self) — EXPECT REFUTED  (formIndex escape)
//   V4CopyableIndex— Index: ... & ~Copyable  — EXPECT REFUTED  (subscript noncopyable param)
//   (this target)  — cross-module conformer + traversal — EXPECT CONFIRMED + runtime
//
// Status: CONFIRMED (V2 copy-i: compiles cross-module + release + runtime) —
//   REFUTED (V1 borrow-self: 'i' escapes; V4 ~Copyable: subscript noncopyable-param wall)
// Result: @_lifetime(copy i) is the correct annotation — the successor index's
//   lifetime derives from the INPUT index, not from a fresh borrow of self. A
//   `~Escapable`-admitting `associatedtype Index` is therefore VIABLE for the
//   storable-index contract (formIndex) on Swift 6.3.2; the common Escapable-index
//   conformer compiles + runs (traversed sum = 60). `~Copyable` index stays blocked
//   by "subscripts cannot have noncopyable parameters yet". The prior /tmp spike's
//   "not viable" conclusion was an artifact of testing only @_lifetime(borrow self).
// Date: 2026-05-25
import ProtocolV2
import Comparison_Primitives

// A trivial Escapable slot index conforming to the real `Comparison.\`Protocol\``
// (the <6.4 fork: needs `<` from Comparison and `==` from Equation, both borrowing).
// This is the common case — and the shape the #4 oddball types (Buffer.Linked,
// Buffer.Slab.Inline) would use: a slot position, not the Tagged Index<Element>.
struct SlotIndex: Comparison.`Protocol` {
    let raw: Int
    static func == (lhs: borrowing SlotIndex, rhs: borrowing SlotIndex) -> Bool { lhs.raw == rhs.raw }
    static func < (lhs: borrowing SlotIndex, rhs: borrowing SlotIndex) -> Bool { lhs.raw < rhs.raw }
}

// Cross-module conformer ([EXP-017]): defined here, conforms to the protocol +
// inherits the generic `formIndex` / `isEmpty` defaults from the ProtocolV2 module.
struct IntBag: ExpCollection.`Protocol` {
    typealias Element = Int
    typealias Index = SlotIndex

    let storage: [Int]

    var startIndex: SlotIndex { SlotIndex(raw: 0) }
    var endIndex: SlotIndex { SlotIndex(raw: storage.count) }
    subscript(_ position: SlotIndex) -> Int { storage[position.raw] }

    // Escapable conformer omits @_lifetime (the requirement carries copy-i; the
    // annotation is inapplicable on an Escapable result).
    func index(after i: SlotIndex) -> SlotIndex { SlotIndex(raw: i.raw + 1) }
}

let bag = IntBag(storage: [10, 20, 30])
var i = bag.startIndex
var sum = 0
while i < bag.endIndex {
    sum += bag[i]
    bag.formIndex(after: &i)   // ← storable-index contract via the generic default
}
print("traversed sum = \(sum), isEmpty = \(bag.isEmpty)")
// Output (expected): traversed sum = 60, isEmpty = false
