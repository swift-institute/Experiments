// MARK: - Property.View with Class-Based (Reference Type) Base
// Purpose: Can Property.View replace ad-hoc accessor structs when Base is a class?
//
// Context: Storage.Heap is a class (ManagedBuffer subclass). Its current accessor
// pattern uses ad-hoc structs that hold a class reference:
//
//   public struct Deinitialize: ~Copyable, ~Escapable {
//       let heap: Storage.Heap   // reference copy (ARC retain)
//       func all() { heap.deinitialize() }
//   }
//
// Property.View takes UnsafeMutablePointer<Base>. For a class, &self gives a pointer
// to the variable holding the reference, not to the object itself.
//
// Hypothesis: Property.View CAN work with class Base.
// Counter-hypothesis: Property.View CANNOT work because classes forbid mutating.
// Alternative hypothesis: Property (owned) works because owning a class ref = ARC retain.
//
// Toolchain: Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED (Property.View) / CONFIRMED (Property owned)
// Date: 2026-02-06
//
// Evidence:
//   Property.View: 'mutating' is not valid on _read accessors in classes
//   Property.View: cannot pass immutable value as inout argument: 'self' is immutable
//   Property (owned): Build Succeeded, all 3 accessors work with let bindings
//
// CONCLUSION: For class Base, use Property<Tag, Base> (owned), NOT Property.View.

import Property_Primitives

// ============================================================================
// MARK: - Simulated Storage.Heap (simplified ManagedBuffer-like class)
// ============================================================================

final class HeapStorage {
    var elements: [Int]
    var count: Int { elements.count }

    init(_ elements: [Int]) {
        self.elements = elements
    }

    deinit {
        print("  [deinit] HeapStorage with \(elements.count) elements")
    }

    func initialize(to value: Int) {
        elements.append(value)
    }

    func deinitializeAll() {
        elements.removeAll()
    }

    func moveLast() -> Int {
        elements.removeLast()
    }
}

// Tag types
extension HeapStorage {
    enum Initialize {}
    enum Deinitialize {}
    enum Move {}
}

// ============================================================================
// MARK: - Variant 1: Property.View with class Base
// Hypothesis: Property.View compiles with class Base
// Result: REFUTED
//
// Error: 'mutating' is not valid on _read accessors in classes
// Error: cannot pass immutable value as inout argument: 'self' is immutable
//
// Classes cannot have `mutating` accessors and `self` is always immutable
// in class context, so &self is unavailable. Property.View requires both.
//
// Commented out to allow compilation:
// ============================================================================

// extension HeapStorage {
//     var initialize: Property<Initialize, HeapStorage>.View {
//         mutating _read {  // ERROR: 'mutating' not valid on _read in classes
//             yield unsafe Property<Initialize, HeapStorage>.View(&self)
//                                                                 // ERROR: 'self' is immutable
//         }
//     }
// }

// ============================================================================
// MARK: - Variant 2: Property (owned) with class Base
// Hypothesis: Property<Tag, Base> works when Base is a class because
//             "owning" a class reference is just an ARC retain.
// Result: CONFIRMED — Build Succeeded
// ============================================================================

extension HeapStorage {
    var `deinitialize`: Property<Deinitialize, HeapStorage> {
        Property(self)
    }

    var initialize: Property<Initialize, HeapStorage> {
        Property(self)
    }

    var move: Property<Move, HeapStorage> {
        Property(self)
    }
}

extension Property where Tag == HeapStorage.Deinitialize, Base == HeapStorage {
    func all() {
        base.deinitializeAll()
    }
}

extension Property where Tag == HeapStorage.Initialize, Base == HeapStorage {
    @discardableResult
    func next(to value: Int) -> Int {
        let index = base.count
        base.initialize(to: value)
        return index
    }
}

extension Property where Tag == HeapStorage.Move, Base == HeapStorage {
    func last() -> Int {
        base.moveLast()
    }
}

// ============================================================================
// MARK: - Variant 2a: let binding
// Hypothesis: Property (owned) works with let bindings for class Base.
// Result: CONFIRMED
// ============================================================================

func testLetBinding() {
    print("=== Variant 2a: Property (owned) with let binding ===")
    print()

    let heap = HeapStorage([1, 2, 3])
    print("  Before: \(heap.elements)")
    heap.deinitialize.all()
    print("  After deinitialize.all(): \(heap.elements)")

    let pass = heap.elements.isEmpty
    print("  let binding: \(pass ? "CONFIRMED" : "REFUTED")")
    // Output: CONFIRMED
    print()
}

// ============================================================================
// MARK: - Variant 2b: Full accessor suite
// Hypothesis: All three accessors (initialize, deinitialize, move) work.
// Result: CONFIRMED
// ============================================================================

func testFullSuite() {
    print("=== Variant 2b: Full accessor suite ===")
    print()

    let heap = HeapStorage([])

    heap.initialize.next(to: 10)
    heap.initialize.next(to: 20)
    heap.initialize.next(to: 30)
    print("  After init: \(heap.elements)")

    let last = heap.move.last()
    print("  Moved last: \(last)")
    print("  After move: \(heap.elements)")

    heap.deinitialize.all()
    print("  After deinit: \(heap.elements)")

    let pass = heap.elements.isEmpty && last == 30
    print("  Full suite: \(pass ? "CONFIRMED" : "REFUTED")")
    // Output: CONFIRMED
    print()
}

// ============================================================================
// MARK: - Variant 2c: Shared reference identity
// Hypothesis: Mutations through Property accessor affect all holders
//             of the same reference (reference semantics preserved).
// Result: CONFIRMED
// ============================================================================

func testSharedReference() {
    print("=== Variant 2c: Shared reference identity ===")
    print()

    let heap1 = HeapStorage([1, 2, 3])
    let heap2 = heap1  // Same reference

    print("  heap1 === heap2: \(heap1 === heap2)")
    print("  Before: heap1=\(heap1.elements), heap2=\(heap2.elements)")

    heap1.initialize.next(to: 4)
    print("  After heap1.initialize.next(to: 4):")
    print("  heap1=\(heap1.elements), heap2=\(heap2.elements)")

    let pass = heap1.elements == [1, 2, 3, 4] && heap2.elements == [1, 2, 3, 4]
    print("  Shared mutation: \(pass ? "CONFIRMED" : "REFUTED")")
    // Output: CONFIRMED
    print()
}

// ============================================================================
// MARK: - Variant 3: Ad-hoc struct comparison
// Purpose: Side-by-side to verify identical behavior.
// ============================================================================

extension HeapStorage {
    struct AdHocDeinitialize: ~Copyable, ~Escapable {
        let heap: HeapStorage

        @_lifetime(borrow heap)
        init(heap: borrowing HeapStorage) {
            self.heap = copy heap
        }

        func all() {
            heap.deinitializeAll()
        }
    }

    var deinitializeAdHoc: AdHocDeinitialize {
        AdHocDeinitialize(heap: self)
    }
}

func testComparison() {
    print("=== Variant 3: Ad-hoc vs Property (owned) comparison ===")
    print()

    print("--- Ad-hoc struct ---")
    do {
        let heap = HeapStorage([1, 2, 3])
        heap.deinitializeAdHoc.all()
        print("  After: \(heap.elements)")
        print("  let binding: \(heap.elements.isEmpty ? "CONFIRMED" : "REFUTED")")
    }
    print()

    print("--- Property (owned) ---")
    do {
        let heap = HeapStorage([1, 2, 3])
        heap.deinitialize.all()
        print("  After: \(heap.elements)")
        print("  let binding: \(heap.elements.isEmpty ? "CONFIRMED" : "REFUTED")")
    }
    print()

    print("  Both work identically with let bindings.")
    print("  Property (owned) eliminates the ad-hoc struct boilerplate.")
    print()
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

func printSummary() {
    print("""
    ============================================================================
    RESULTS SUMMARY
    ============================================================================

    HYPOTHESIS: Property.View can replace ad-hoc accessor structs for class Base
    RESULT: REFUTED

    Property.View requires:
      - mutating _read / _modify accessors (for &self pointer)
      - Classes FORBID mutating accessors
      - Classes have immutable self (no &self available)
    Error: 'mutating' is not valid on _read accessors in classes
    Error: cannot pass immutable value as inout argument: 'self' is immutable

    ALTERNATIVE: Property<Tag, Base> (owned) works for class Base
    RESULT: CONFIRMED

    Property (owned) works because:
      - "Owning" a class reference = ARC retain (lightweight, ~0 cost)
      - No pointer indirection needed
      - Works with let AND var bindings
      - Reference semantics preserved (shared mutation)
      - Extensions via Property<Tag, Base> where Tag == X, Base == Y
      - Identical call-site syntax to ad-hoc structs
      - Eliminates boilerplate struct definitions (~Copyable, ~Escapable,
        @_lifetime annotations, init, stored property)

    COMPARISON:

    | Aspect               | Ad-hoc struct           | Property.View    | Property (owned) |
    |----------------------|-------------------------|------------------|------------------|
    | Class Base           | YES                     | NO (won't compile) | YES            |
    | let binding          | YES                     | NO               | YES              |
    | var binding          | YES                     | N/A              | YES              |
    | Boilerplate          | ~10 lines per accessor  | N/A              | ~1 line          |
    | Reference semantics  | YES                     | N/A              | YES              |
    | ~Copyable ~Escapable | Manual                  | Built-in         | Built-in         |
    | @_lifetime           | Manual                  | Built-in         | Not needed       |

    RECOMMENDATION FOR STORAGE.HEAP:

    Replace ad-hoc structs with Property<Tag, Storage.Heap>:

      BEFORE:
        public struct Deinitialize: ~Copyable, ~Escapable {
            @usableFromInline let heap: Storage.Heap
            @inlinable @_lifetime(borrow heap)
            init(heap: borrowing Storage.Heap) { self.heap = copy heap }
            @inlinable public func all() { heap.deinitialize() }
        }
        @inlinable public var deinitialize: Deinitialize {
            Deinitialize(heap: self)
        }

      AFTER:
        enum Deinitialize {}
        @inlinable public var deinitialize: Property<Deinitialize, Storage.Heap> {
            Property(self)
        }
        // In separate file:
        extension Property where Tag == Storage.Heap.Deinitialize, Base == Storage.Heap {
            @inlinable public func all() { base.deinitialize() }
        }
    """)
}

// ============================================================================
// MARK: - Run
// ============================================================================

print()
print("=== Property.View with Class-Based Base: Experiment ===")
print()

testLetBinding()
testFullSuite()
testSharedReference()
testComparison()
printSummary()
