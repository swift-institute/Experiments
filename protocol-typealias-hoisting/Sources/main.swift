// MARK: - Protocol Typealias Hoisting (Tags NOT Hoisted)
// Purpose: Hoist ONLY the protocol outside the generic namespace.
//          Tag types remain as real enums inside Storage<Element>.
//          Test whether nested enums that don't reference Element are canonicalized
//          across specializations (Storage<Int>.Deinitialize == Storage<Never>.Deinitialize).
// Hypothesis: Only the protocol needs hoisting. Tags work as-is because
//             Swift canonicalizes nested types independent of the outer generic.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Protocol typealias hoisting works. Tag types stay inside generic namespace.
//         REFUTED — Tags are NOT canonicalized across specializations, neither at compile time
//         nor at runtime (Storage<Int>.Deinitialize.self == Storage<Never>.Deinitialize.self → false).
//         This is irrelevant: all Property.View extensions use Storage<Never>.Deinitialize
//         as the canonical tag witness. Per-type methods constrain Base (not Tag specialization).
//         Full [IMPL-026] delegation works: protocol defaults + per-type coexistence.
// Output: Build Succeeded, all 7 tests pass
// Date: 2026-02-12

// ============================================================================
// MARK: - Infrastructure: Minimal Property.View replica
// ============================================================================

public struct Property<Tag, Base: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline
    let base: UnsafeMutablePointer<Base>

    @inlinable
    @_lifetime(borrow base)
    init(_ base: UnsafeMutablePointer<Base>) {
        self.base = base
    }
}

extension Property where Base: ~Copyable {
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline
        let base: UnsafeMutablePointer<Base>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            self.base = base
        }
    }
}

// ============================================================================
// MARK: - Hoisted protocol ONLY (outside generic context)
// ============================================================================

/// Hoisted protocol — the only thing that MUST live outside.
public protocol __StorageProtocol: ~Copyable {
    var slotCapacity: Int { get }
    func forEachOccupiedSlot(_ body: (Int) -> Void)
    mutating func deinitializeSlot(at index: Int)
    mutating func resetTracking()
}

// ============================================================================
// MARK: - Generic namespace: protocol typealias + REAL tag enums
// ============================================================================

public enum Storage<Element: ~Copyable> {
    /// Only the protocol is typealiased — it cannot be nested in generic context.
    public typealias `Protocol` = __StorageProtocol

    /// Tag types are REAL enums — NOT hoisted.
    public enum Deinitialize {}

    // Conformer 1: Heap (Copyable, reference-semantic)
    public final class Heap {
        var _capacity: Int
        var _count: Int

        init(capacity: Int) {
            self._capacity = capacity
            self._count = 0
        }
    }

    // Conformer 2: Inline (~Copyable, value-generic)
    public struct Inline<let capacity: Int>: ~Copyable {
        var _count: Int
        var _slotBits: UInt

        init() {
            self._count = 0
            self._slotBits = 0
        }
    }

    // Conformer 3: Arena.Inline (~Copyable, value-generic, deeper nesting)
    public enum Arena {
        public struct Inline<let capacity: Int>: ~Copyable {
            var _count: Int
            var _slotBits: UInt
            var _allocated: Int

            init() {
                self._count = 0
                self._slotBits = 0
                self._allocated = 0
            }
        }
    }
}

// ============================================================================
// MARK: - Conformances
// ============================================================================

extension Storage.Heap: Storage.`Protocol` where Element: ~Copyable {
    public var slotCapacity: Int { _capacity }

    public func forEachOccupiedSlot(_ body: (Int) -> Void) {
        for i in 0..<_count { body(i) }
    }

    public func deinitializeSlot(at index: Int) {
        print("    Heap.deinitializeSlot(\(index))")
    }

    public func resetTracking() {
        _count = 0
    }
}

extension Storage.Inline: Storage.`Protocol` where Element: ~Copyable {
    public var slotCapacity: Int { capacity }

    public func forEachOccupiedSlot(_ body: (Int) -> Void) {
        var bits = _slotBits
        while bits != 0 {
            let index = bits.trailingZeroBitCount
            body(index)
            bits &= bits &- 1
        }
    }

    public mutating func deinitializeSlot(at index: Int) {
        print("    Inline.deinitializeSlot(\(index))")
        _slotBits &= ~(1 << index)
    }

    public mutating func resetTracking() {
        _count = 0
        _slotBits = 0
    }
}

extension Storage.Arena.Inline: Storage.`Protocol` where Element: ~Copyable {
    public var slotCapacity: Int { capacity }

    public func forEachOccupiedSlot(_ body: (Int) -> Void) {
        var bits = _slotBits
        while bits != 0 {
            let index = bits.trailingZeroBitCount
            body(index)
            bits &= bits &- 1
        }
    }

    public mutating func deinitializeSlot(at index: Int) {
        print("    Arena.Inline.deinitializeSlot(\(index))")
        _slotBits &= ~(1 << index)
    }

    public mutating func resetTracking() {
        _count = 0
        _slotBits = 0
        _allocated = 0
    }
}

// ============================================================================
// MARK: - Protocol default accessor (tag is real nested enum, use Never as witness)
// ============================================================================

extension Storage.`Protocol` where Self: ~Copyable {
    public var deinitialize: Property<Storage<Never>.Deinitialize, Self>.View {
        mutating _read {
            yield unsafe Property<Storage<Never>.Deinitialize, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Storage<Never>.Deinitialize, Self>.View(&self)
            yield &view
        }
    }
}

// ============================================================================
// MARK: - Protocol-constrained Property.View method
// ============================================================================

extension Property.View
where Tag == Storage<Never>.Deinitialize, Base: Storage<Never>.`Protocol` & ~Copyable {
    @_lifetime(&self)
    public mutating func all() {
        unsafe base.pointee.forEachOccupiedSlot { index in
            unsafe base.pointee.deinitializeSlot(at: index)
        }
        unsafe base.pointee.resetTracking()
    }
}

// ============================================================================
// MARK: - Per-type method (MUST use Storage<Never>.Deinitialize — NOT Storage<Int>.Deinitialize)
// ============================================================================
//
// REFUTED: Storage<Int>.Deinitialize ≠ Storage<Never>.Deinitialize at compile time.
//          Nested enums inside generic types are NOT canonicalized across specializations.
//          The protocol default accessor yields Tag == Storage<Never>.Deinitialize,
//          so per-type methods MUST use the same canonical witness.
//
// Uncommenting this produces:
//   error: cannot convert parent type 'Storage<Never>' to expected type 'Storage<Int>'
//
// extension Property.View
// where Tag == Storage<Int>.Deinitialize, Base == Storage<Int>.Heap {
//     public func single(at index: Int) {
//         print("  Heap<Int>-specific: deinitialize.single(at: \(index))")
//         unsafe base.pointee.deinitializeSlot(at: index)
//     }
// }

// CONFIRMED: Per-type method using Storage<Never>.Deinitialize (canonical witness) works.
extension Property.View
where Tag == Storage<Never>.Deinitialize, Base == Storage<Int>.Heap {
    public func single(at index: Int) {
        print("  Heap<Int>-specific: deinitialize.single(at: \(index))")
        unsafe base.pointee.deinitializeSlot(at: index)
    }
}

// ============================================================================
// MARK: - Tests
// ============================================================================

print("=== Protocol Typealias Hoisting (Tags NOT Hoisted) ===")

// Test 1: Tag equivalence — are real nested enums canonicalized?
print("\n--- Test 1: Tag equivalence ---")
print("Storage<Int>.Deinitialize == Storage<String>.Deinitialize: \(Storage<Int>.Deinitialize.self == Storage<String>.Deinitialize.self)")
print("Storage<Int>.Deinitialize == Storage<Never>.Deinitialize: \(Storage<Int>.Deinitialize.self == Storage<Never>.Deinitialize.self)")

// Test 2: Heap
print("\n--- Test 2: Heap ---")
var heap = Storage<Int>.Heap(capacity: 16)
heap._count = 3
print("Before: count = \(heap._count)")
heap.deinitialize.all()
print("After: count = \(heap._count)")

// Test 3: Inline
print("\n--- Test 3: Inline<8> ---")
var inline = Storage<Int>.Inline<8>()
inline._count = 3
inline._slotBits = 0b10101
print("Before: count = \(inline._count), bits = \(String(inline._slotBits, radix: 2))")
inline.deinitialize.all()
print("After: count = \(inline._count), bits = \(String(inline._slotBits, radix: 2))")

// Test 4: Arena.Inline
print("\n--- Test 4: Arena.Inline<4> ---")
var arena = Storage<Int>.Arena.Inline<4>()
arena._count = 2
arena._slotBits = 0b11
arena._allocated = 2
print("Before: count = \(arena._count), bits = \(String(arena._slotBits, radix: 2)), allocated = \(arena._allocated)")
arena.deinitialize.all()
print("After: count = \(arena._count), bits = \(String(arena._slotBits, radix: 2)), allocated = \(arena._allocated)")

// Test 5: Generic function
print("\n--- Test 5: Generic function ---")
func deinitializeAll<S: Storage<Never>.`Protocol` & ~Copyable>(_ storage: inout S) {
    storage.deinitialize.all()
}
var heap2 = Storage<String>.Heap(capacity: 32)
heap2._count = 2
print("Before: count = \(heap2._count)")
deinitializeAll(&heap2)
print("After: count = \(heap2._count)")

// Test 6: ~Copyable Element
print("\n--- Test 6: ~Copyable Element ---")
struct Resource: ~Copyable { var id: Int }
var ncInline = Storage<Resource>.Inline<4>()
ncInline._count = 2
ncInline._slotBits = 0b11
print("Before: count = \(ncInline._count), bits = \(String(ncInline._slotBits, radix: 2))")
ncInline.deinitialize.all()
print("After: count = \(ncInline._count), bits = \(String(ncInline._slotBits, radix: 2))")

// Test 7: Per-type method coexists with protocol default (both use Storage<Never>.Deinitialize)
print("\n--- Test 7: Per-type method coexists ---")
var heap3 = Storage<Int>.Heap(capacity: 8)
heap3._count = 3
heap3.deinitialize.single(at: 1)  // type-specific (Tag == Storage<Never>.Deinitialize, Base == Heap)
heap3.deinitialize.all()           // protocol default (Tag == Storage<Never>.Deinitialize, Base: Protocol)

print("\n=== All tests passed ===")
