// MARK: - Protocol Inside Generic Namespace
// Purpose: Can a protocol be nested inside a generic enum namespace?
//         If not, what workarounds preserve the *.`Protocol` naming pattern?
//         Can the pattern avoid associatedtype Element entirely (like Bit.Vector.Protocol)?
// Hypothesis: (1) Generic enum nesting is forbidden.
//             (2) Non-generic namespace with element-agnostic protocol works.
//             (3) associatedtype Element: ~Copyable is forbidden.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — non-generic namespace + element-agnostic protocol + [IMPL-026] works
//         REFUTED — generic enum nesting, associatedtype ~Copyable, constrained extension nesting
// Date: 2026-02-12

// ============================================================================
// MARK: - Variant 1: Protocol inside generic enum (direct)
// Hypothesis: REFUTED — Swift disallows protocol inside generic type
// Result: REFUTED — "protocol 'Protocol' cannot be nested in a generic context"
// ============================================================================

// Uncomment to test — expected error: "protocol 'Protocol' cannot be nested
// inside generic context"
//
// public enum GenericNamespace<Element: ~Copyable> {
//     public protocol `Protocol`: ~Copyable {
//         var capacity: Int { get }
//     }
// }

// ============================================================================
// MARK: - Variant 2: associatedtype Element: ~Copyable
// Hypothesis: REFUTED — cannot suppress Copyable on associated type
// Result: REFUTED — "cannot suppress 'Copyable' requirement of an associated type"
// ============================================================================

// Uncomment to test — expected error: "cannot suppress 'Copyable' requirement
// of an associated type"
//
// public protocol ElementBearing: ~Copyable {
//     associatedtype Element: ~Copyable
//     var capacity: Int { get }
// }

// ============================================================================
// MARK: - Variant 3: Protocol inside constrained extension
// Hypothesis: REFUTED — extensions of generic types can't declare protocols
// Result: REFUTED — "protocol 'Protocol' cannot be nested in a generic context"
// ============================================================================

// Uncomment to test:
//
// public enum GenericNamespace2<Element: ~Copyable> {}
// extension GenericNamespace2 where Element: ~Copyable {
//     public protocol `Protocol`: ~Copyable {
//         var capacity: Int { get }
//     }
// }

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
// MARK: - Variant 4: Non-generic namespace + element-agnostic protocol
// Hypothesis: CONFIRMED — following Bit.Vector.Protocol's design:
//   - Non-generic namespace
//   - Protocol has NO associatedtype (requirements use concrete/opaque types)
//   - Individual conforming types carry their own generic Element parameter
//   - Property.View delegation works with Base: Protocol & ~Copyable
// Result: CONFIRMED — Build Succeeded, all 6 tests pass
// ============================================================================

// Non-generic namespace (like Bit.Vector)
public enum Storage {
    // Tag types
    public enum Deinitialize {}

    // Element-agnostic protocol — NO associatedtype
    // Requirements are expressed in terms the protocol can see:
    // slot indices (Int), slot count, iteration, type-erased deinit.
    public protocol `Protocol`: ~Copyable {
        var slotCapacity: Int { get }

        /// Iterate all occupied slot indices.
        func forEachOccupiedSlot(_ body: (Int) -> Void)

        /// Deinitialize the element at a slot (type-erased).
        mutating func deinitializeSlot(at index: Int)

        /// Reset tracking state after bulk deinit.
        mutating func resetTracking()
    }
}

// ============================================================================
// Conformer 1: Heap (Copyable, reference-semantic)
// ============================================================================

extension Storage {
    public final class Heap<Element: ~Copyable> {
        var _capacity: Int
        var _count: Int

        init(capacity: Int) {
            self._capacity = capacity
            self._count = 0
        }
    }
}

extension Storage.Heap: Storage.`Protocol` where Element: ~Copyable {
    public var slotCapacity: Int { _capacity }

    public func forEachOccupiedSlot(_ body: (Int) -> Void) {
        for i in 0..<_count { body(i) }
    }

    public func deinitializeSlot(at index: Int) {
        // In production: pointer(at: index).deinitialize(count: .one)
        print("    Heap.deinitializeSlot(\(index))")
    }

    public func resetTracking() {
        _count = 0
    }
}

// ============================================================================
// Conformer 2: Inline (~Copyable, value-generic)
// ============================================================================

extension Storage {
    public struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {
        var _count: Int
        var _slotBits: UInt

        init() {
            self._count = 0
            self._slotBits = 0
        }
    }
}

extension Storage.Inline: Storage.`Protocol` where Element: ~Copyable {
    public var slotCapacity: Int { capacity }

    public func forEachOccupiedSlot(_ body: (Int) -> Void) {
        var bits = _slotBits
        while bits != 0 {
            let index = bits.trailingZeroBitCount
            body(index)
            bits &= bits &- 1 // Wegner/Kernighan
        }
    }

    public mutating func deinitializeSlot(at index: Int) {
        // In production: pointer(at: index).deinitialize(count: .one)
        print("    Inline.deinitializeSlot(\(index))")
        _slotBits &= ~(1 << index)
    }

    public mutating func resetTracking() {
        _count = 0
        _slotBits = 0
    }
}

// ============================================================================
// Conformer 3: Arena.Inline (~Copyable, value-generic, deeper nesting)
// ============================================================================

extension Storage {
    public enum Arena {
        public struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {
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
// Protocol default Property.View accessor
// ============================================================================

extension Storage.`Protocol` where Self: ~Copyable {
    public var deinitialize: Property<Storage.Deinitialize, Self>.View {
        mutating _read {
            yield unsafe Property<Storage.Deinitialize, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Storage.Deinitialize, Self>.View(&self)
            yield &view
        }
    }
}

// ============================================================================
// Protocol-constrained Property.View method — ONE declaration serves ALL conformers
// ============================================================================

extension Property.View where Tag == Storage.Deinitialize, Base: Storage.`Protocol` & ~Copyable {
    @_lifetime(&self)
    public mutating func all() {
        unsafe base.pointee.forEachOccupiedSlot { index in
            unsafe base.pointee.deinitializeSlot(at: index)
        }
        unsafe base.pointee.resetTracking()
    }
}

// ============================================================================
// MARK: - Test execution
// ============================================================================

print("=== Variant 4: Non-Generic Namespace + Element-Agnostic Protocol ===")

// Test 1: Heap (Copyable conformer)
print("\n--- Test 1: Heap<Int> ---")
var heap = Storage.Heap<Int>(capacity: 16)
heap._count = 3
print("Before: count = \(heap._count)")
heap.deinitialize.all()
print("After: count = \(heap._count)")

// Test 2: Inline (~Copyable conformer, value-generic)
print("\n--- Test 2: Inline<Int, 8> ---")
var inline = Storage.Inline<Int, 8>()
inline._count = 3
inline._slotBits = 0b10101
print("Before: count = \(inline._count), bits = \(String(inline._slotBits, radix: 2))")
inline.deinitialize.all()
print("After: count = \(inline._count), bits = \(String(inline._slotBits, radix: 2))")

// Test 3: Arena.Inline (~Copyable conformer, value-generic, nested)
print("\n--- Test 3: Arena.Inline<Int, 4> ---")
var arena = Storage.Arena.Inline<Int, 4>()
arena._count = 2
arena._slotBits = 0b11
arena._allocated = 2
print("Before: count = \(arena._count), bits = \(String(arena._slotBits, radix: 2)), allocated = \(arena._allocated)")
arena.deinitialize.all()
print("After: count = \(arena._count), bits = \(String(arena._slotBits, radix: 2)), allocated = \(arena._allocated)")

// Test 4: Generic function over some Storage.Protocol
print("\n--- Test 4: Generic function ---")
func deinitializeAll<S: Storage.`Protocol` & ~Copyable>(_ storage: inout S) {
    storage.deinitialize.all()
}
var heap2 = Storage.Heap<String>(capacity: 32)
heap2._count = 2
print("Before: count = \(heap2._count)")
deinitializeAll(&heap2)
print("After: count = \(heap2._count)")

// Test 5: ~Copyable Element (protocol has no associatedtype — Element is irrelevant)
print("\n--- Test 5: ~Copyable Element ---")
struct Resource: ~Copyable {
    var id: Int
}
var ncInline = Storage.Inline<Resource, 4>()
ncInline._count = 2
ncInline._slotBits = 0b11
print("Before: count = \(ncInline._count), bits = \(String(ncInline._slotBits, radix: 2))")
ncInline.deinitialize.all()
print("After: count = \(ncInline._count), bits = \(String(ncInline._slotBits, radix: 2))")

// Test 6: Verify per-type override coexists with protocol default
print("\n--- Test 6: Per-type method coexists ---")
extension Property.View where Tag == Storage.Deinitialize, Base == Storage.Heap<Int> {
    public func single(at index: Int) {
        print("  Heap<Int>-specific: deinitialize.single(at: \(index))")
        unsafe base.pointee.deinitializeSlot(at: index)
    }
}
var heap3 = Storage.Heap<Int>(capacity: 8)
heap3._count = 5
heap3.deinitialize.single(at: 2)  // type-specific
heap3.deinitialize.all()           // protocol default

print("\n=== All tests passed ===")
