// MARK: - Slab forEach Non-Mutating Access
// Purpose: Find the principally correct pattern for non-mutating forEach.occupied
//          on Buffer.Slab, where the caller (Dictionary) needs to iterate slot
//          indices AND access elements at those indices from the same/different slabs.
//
// Problem: Property.View.Read borrows the slab via _read accessor. The closure
//          passed to .occupied needs to re-borrow the slab for element access.
//          This creates a borrow conflict with ~Escapable types.
//
// Toolchain: Swift 6.2
// Platform: macOS 26.0 (arm64)
//
// Results:
//   V1 (ReadView on Slab):    REFUTED — lifetime escape (re-borrow conflict)
//   V2 (Direct method):       CONFIRMED — compiles, correct output
//   V3 (MutView borrowing):   REFUTED — same lifetime escape
//   V4 (Element via pointer): REFUTED — can't consume borrowed + lifetime escape
//   V5 (let-binding):         REFUTED — can't consume borrowed ~Escapable
//   V6 (withUnsafePointer):   CONFIRMED — compiles, correct output
//   V7 (Dict-level ReadView): CONFIRMED — compiles, correct output ← RECOMMENDED
//   V8 (Snapshot bitmap):     CONFIRMED — compiles, correct output
//
// Analysis: The fundamental issue is that ~Escapable views on a FIELD cannot
// coexist with closures that re-access the same field through the parent.
// V7 solves this by lifting the view to the CONTAINER level — the view borrows
// the whole Dict, and all access goes through base.pointee (no re-borrow).
// This is principally correct: Dictionary IS the iteration subject, not Slab.
//
// Decision: V7 — Dict-level Property.View.Read with Sequence.ForEach tag.
//   Buffer.Slab keeps forEach.occupied via Property.View.Read for direct use.
//   Dictionary provides its own forEach via Property<Sequence.ForEach, Self>.View.Read
//   that accesses both slabs through the pointer.
//
// Date: 2026-02-24

// ============================================================================
// MARK: - Minimal Infrastructure
// ============================================================================

// Simulate Property.View.Read (non-mutating, UnsafePointer)
@safe
struct ReadView<Tag, Base: ~Copyable>: ~Copyable, ~Escapable {
    let _base: UnsafePointer<Base>

    @_lifetime(borrow base)
    init(_ base: UnsafePointer<Base>) {
        unsafe _base = base
    }

    @_lifetime(borrow base)
    init(borrowing base: borrowing Base) {
        unsafe _base = withUnsafePointer(to: base) { unsafe $0 }
    }

    var base: UnsafePointer<Base> { unsafe _base }
}

// Tag type
enum ForEach {}

// Minimal slab: bitmap + elements
struct Slab: ~Copyable {
    var bitmap: UInt8  // each bit = occupied
    var elements: (Int, Int, Int, Int, Int, Int, Int, Int)  // 8 slots

    init() {
        bitmap = 0
        elements = (0, 0, 0, 0, 0, 0, 0, 0)
    }

    mutating func insert(_ value: Int, at slot: Int) {
        bitmap |= (1 << slot)
        withUnsafeMutablePointer(to: &elements) {
            unsafe UnsafeMutableRawPointer($0)
                .assumingMemoryBound(to: Int.self)
                .advanced(by: slot)
                .pointee = value
        }
    }

    func element(at slot: Int) -> Int {
        withUnsafePointer(to: elements) {
            unsafe UnsafeRawPointer($0)
                .assumingMemoryBound(to: Int.self)
                .advanced(by: slot)
                .pointee
        }
    }

    var occupancy: Int { bitmap.nonzeroBitCount }
    var capacity: Int { 8 }

    func isOccupied(at slot: Int) -> Bool {
        bitmap & (1 << slot) != 0
    }

    // Wegner/Kernighan: O(count) not O(capacity)
    func forEachOccupiedBit(_ body: (Int) -> Void) {
        var bits = bitmap
        while bits != 0 {
            let slot = bits.trailingZeroBitCount
            body(slot)
            bits &= bits &- 1
        }
    }
}

// Dictionary-like container with two slabs
struct Dict: ~Copyable {
    var _keys: Slab
    var _values: Slab

    init() {
        _keys = Slab()
        _values = Slab()
    }

    mutating func set(_ key: Int, _ value: Int, at slot: Int) {
        _keys.insert(key, at: slot)
        _values.insert(value, at: slot)
    }
}

// ============================================================================
// MARK: - Variant 1: Property.View.Read on Slab (direct)
// Hypothesis: ReadView borrows _keys; closure re-borrows _keys → lifetime error
// Result: REFUTED — "lifetime-dependent value escapes its scope"
//         The _read coroutine borrows _keys, and the closure captures self
//         to access _keys[slot] and _values[slot], creating a re-borrow conflict.
// ============================================================================

// extension Slab {
//     var forEach_v1: ReadView<ForEach, Self> {
//         _read {
//             yield ReadView<ForEach, Self>(borrowing: self)
//         }
//     }
// }
//
// extension ReadView where Tag == ForEach, Base == Slab {
//     func occupied(_ body: (Int) -> Void) {
//         unsafe base.pointee.forEachOccupiedBit(body)
//     }
// }
//
// extension Dict {
//     func forEach_v1(_ body: (Int, Int) -> Void) {
//         _keys.forEach_v1.occupied { slot in
//             body(_keys.element(at: slot), _values.element(at: slot))
//         }
//     }
// }

// ============================================================================
// MARK: - Variant 2: Direct method (baseline, no Property.View)
// Hypothesis: Simple non-mutating method avoids all lifetime issues
// Result: CONFIRMED — compiles, correct output
// ============================================================================

extension Slab {
    func forEachOccupied(_ body: (Int) -> Void) {
        forEachOccupiedBit(body)
    }
}

extension Dict {
    func forEach_v2(_ body: (Int, Int) -> Void) {
        _keys.forEachOccupied { slot in
            body(_keys.element(at: slot), _values.element(at: slot))
        }
    }
}

// ============================================================================
// MARK: - Variant 3: Property.View (mutating) via @unsafe init(borrowing:)
// Hypothesis: MutView init(borrowing:) allows non-mutating access
// Result: REFUTED — Same "lifetime-dependent value escapes its scope" error.
//         The ~Escapable view lifetime is tied to _keys regardless of pointer type.
// ============================================================================

// (Commented out — same error as V1)

// ============================================================================
// MARK: - Variant 4: ReadView with element accessor inside occupied
// Hypothesis: If occupied() provides element access through the pointer,
//             caller doesn't need to re-borrow the slab
// Result: REFUTED — Two errors:
//         1. "'unknown' is borrowed and cannot be consumed" (can't copy out of view)
//         2. Same lifetime escape at Dict call site
// ============================================================================

// (Commented out — cannot extract Slab from borrowed ReadView)

// ============================================================================
// MARK: - Variant 5: let-binding ReadView before calling .occupied
// Hypothesis: Binding the ReadView to a let before calling .occupied helps
// Result: REFUTED — "'self._keys.forEach_v1' is borrowed and cannot be consumed"
//         Cannot consume (move into let) a borrowed ~Escapable value.
// ============================================================================

// (Commented out)

// ============================================================================
// MARK: - Variant 6: withUnsafePointer manual approach
// Hypothesis: Manual pointer extraction avoids _read coroutine lifetime issues
// Result: CONFIRMED — compiles, correct output
// ============================================================================

extension Dict {
    func forEach_v6(_ body: (Int, Int) -> Void) {
        withUnsafePointer(to: _keys) { keysPtr in
            unsafe keysPtr.pointee.forEachOccupiedBit { slot in
                body(unsafe keysPtr.pointee.element(at: slot), _values.element(at: slot))
            }
        }
    }
}

// ============================================================================
// MARK: - Variant 7: Property.View.Read on Dict itself (not on individual slab)
// Hypothesis: A Dict-level forEach view borrows the whole Dict, so element
//             access through the pointer doesn't conflict — all access goes
//             through base.pointee, no re-borrow of self needed.
// Result: CONFIRMED — compiles, correct output ← RECOMMENDED
// ============================================================================

enum DictForEach {}

extension Dict {
    var forEach_v7: ReadView<DictForEach, Self> {
        _read {
            yield ReadView<DictForEach, Self>(borrowing: self)
        }
    }
}

extension ReadView where Tag == DictForEach, Base == Dict {
    func callAsFunction(_ body: (Int, Int) -> Void) {
        unsafe base.pointee._keys.forEachOccupiedBit { slot in
            body(
                unsafe base.pointee._keys.element(at: slot),
                unsafe base.pointee._values.element(at: slot)
            )
        }
    }
}

// ============================================================================
// MARK: - Variant 8: Snapshot bitmap value before iteration
// Hypothesis: Copy the bitmap out, iterate the copy, access elements normally
// Result: CONFIRMED — compiles, correct output
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

extension Slab {
    var occupiedBitmap: UInt8 { bitmap }
}

extension Dict {
    func forEach_v8(_ body: (Int, Int) -> Void) {
        var bits = _keys.occupiedBitmap
        while bits != 0 {
            let slot = bits.trailingZeroBitCount
            body(_keys.element(at: slot), _values.element(at: slot))
            bits &= bits &- 1
        }
    }
}

// ============================================================================
// MARK: - Execution
// ============================================================================

var dict = Dict()
dict.set(10, 100, at: 1)
dict.set(30, 300, at: 5)
dict.set(50, 500, at: 7)

print("=== Variant 2: Direct method (baseline) ===")
dict.forEach_v2 { k, v in print("  \(k) → \(v)") }

print("\n=== Variant 6: Manual withUnsafePointer ===")
dict.forEach_v6 { k, v in print("  \(k) → \(v)") }

print("\n=== Variant 7: Dict-level ReadView (forEach { }) ===")
dict.forEach_v7 { k, v in print("  \(k) → \(v)") }

print("\n=== Variant 8: Snapshot bitmap ===")
dict.forEach_v8 { k, v in print("  \(k) → \(v)") }
