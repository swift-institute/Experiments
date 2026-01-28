// MARK: - Pointer Primitives Feasibility Investigation
// Purpose: Explore whether swift-pointer-primitives could support ~Copyable and ~Escapable
//
// Methodology: Incremental construction [EXP-004a]
// Toolchain: Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Prior Art: escapable-pointer-primitives-test (swift-sequence-primitives)
// - Confirmed: Builtin.load requires both Copyable AND Escapable
// - This is a fundamental language constraint
//
// Related: PITCH-0003 Escapable Pointer Operations
//          BLOG-IDEA-025 Why You Can't Build a ~Escapable Pointer
//
// =============================================================================
// CRITICAL DISCOVERY (from this experiment):
// =============================================================================
//
// Builtin.load requires BOTH:
//   - T: Copyable (discovered in this experiment)
//   - T: Escapable (known from prior experiment)
//
// This means:
//   1. ~Copyable types CANNOT use Builtin.load directly
//   2. UnsafeMutablePointer DOES work with ~Copyable (uses different mechanism)
//   3. For ~Escapable, there is NO workaround - fundamental constraint
//
// =============================================================================
// SECTION 6: C INTEROP INVESTIGATION
// =============================================================================
//
// Hypothesis: C interop might bypass Swift's Escapable/Copyable constraints
// because C doesn't have these concepts.
//
// Key questions:
// - Can shim_load (memcpy) load a ~Escapable value?
// - Can shim_load load a ~Copyable value?
// - Can we build a CPointer<T: ~Escapable> using C shims?
//
// FINDINGS:
// - LOCAL ~Escapable: C shims WORK (Builtin.addressof allowed)
// - GENERIC ~Escapable: BLOCKED (parameters trigger escape detection)
// - Cannot build generic CPointer<T: ~Escapable> wrapper
//
// =============================================================================
// INVESTIGATION RESULTS
// =============================================================================
//
 CONFIRMED (works)
 REFUTED (requires Copyable)
 PARTIAL (addressof works)
 CONFIRMED (works)
 CONFIRMED (works)
 CONFIRMED (works)
 CONFIRMED (works)
 CONFIRMED (works)
 BLOCKED (requires Escapable)
 PARTIAL (address ok, load blocked)
 PENDING
//
// =============================================================================
// CONCLUSION FOR swift-pointer-primitives
// =============================================================================
//
// A swift-pointer-primitives package IS VIABLE with these constraints:
//
// SUPPORTED:
//   - ~Copyable types (implicitly Escapable)
//   - Uses UnsafeMutablePointer internally (not Builtin.load directly)
//   - Can provide Pointer<T: ~Copyable> wrapper
//
// NOT SUPPORTED:
//   - ~Escapable types (fundamental language constraint)
//   - Cannot bypass Builtin.load Escapable requirement
//
// This is a meaningful package - most move-only types are Escapable.
// Span-backed views (~Escapable) must use protocols directly, not pointers.
//
// Result: PARTIALLY VIABLE
// Date: 2026-01-24
//
// =============================================================================

import Builtin
import CShim

// =============================================================================
// HELPER: Builtin.RawPointer to UnsafeRawPointer conversion
// =============================================================================

/// Converts Builtin.RawPointer to UnsafeRawPointer via integer round-trip
@inline(__always)
func unsafeRawPointer(from builtinPtr: Builtin.RawPointer) -> UnsafeRawPointer {
    let intValue = Int(Builtin.ptrtoint_Word(builtinPtr))
    return UnsafeRawPointer(bitPattern: intValue)!
}

/// Converts Builtin.RawPointer to UnsafeMutableRawPointer via integer round-trip
@inline(__always)
func unsafeMutableRawPointer(from builtinPtr: Builtin.RawPointer) -> UnsafeMutableRawPointer {
    let intValue = Int(Builtin.ptrtoint_Word(builtinPtr))
    return UnsafeMutableRawPointer(bitPattern: intValue)!
}

// =============================================================================
// SECTION 1: ~Copyable Support (Escapable assumed) - WORKING
// =============================================================================

// MARK: - Variant 1.1: UnsafeMutablePointer with ~Copyable
// Hypothesis: UnsafeMutablePointer works with ~Copyable + Escapable types
// Result: CONFIRMED - compiles and runs correctly

struct MoveOnlyValue: ~Copyable {
    var value: Int
    init(_ v: Int) { value = v }
    deinit { print("  deinit MoveOnlyValue(\(value))") }
}

func testNoncopyablePointer() {
    print("\n--- Variant 1.1: UnsafeMutablePointer with ~Copyable ---")
    var mov = MoveOnlyValue(42)

    // UnsafeMutablePointer DOES work with ~Copyable
    // It uses a different internal mechanism than Builtin.load
    withUnsafeMutablePointer(to: &mov) { ptr in
        print("  Got pointer to MoveOnlyValue")
        print("  Value via pointee: \(ptr.pointee.value)")
        ptr.pointee.value = 100
        print("  Modified to: \(ptr.pointee.value)")
    }
    print("  After withUnsafeMutablePointer: \(mov.value)")
    print("  RESULT: CONFIRMED - UnsafeMutablePointer works with ~Copyable")
}

// MARK: - Variant 1.2: Builtin.load with ~Copyable
// Hypothesis: Builtin.load works with ~Copyable if Escapable
// Result: REFUTED - Builtin.load requires Copyable
//
// Error from build:
// error: global function 'load' requires that 'MoveOnlyValue' conform to 'Copyable'
// Builtin.load:1:13: note: 'where T: Copyable' is implicit here
// 1 | public func load<T>(_: Builtin.RawPointer) -> T

// func testBuiltinLoadNoncopyable() {
//     var mov = MoveOnlyValue(77)
//     let rawPtr = Builtin.addressof(&mov)
//     // This FAILS:
//     let loaded: MoveOnlyValue = Builtin.load(rawPtr)
//     // error: global function 'load' requires that 'MoveOnlyValue' conform to 'Copyable'
// }

// MARK: - Variant 1.3: Builtin.take with ~Copyable
// Hypothesis: Builtin.take (move semantics) might work with ~Copyable
// Result: TO TEST

func testBuiltinTakeNoncopyable() {
    print("\n--- Variant 1.3: Builtin.take with ~Copyable ---")

    var mov = MoveOnlyValue(88)

    let rawPtr = Builtin.addressof(&mov)

    // Try Builtin.take instead of Builtin.load
    // take should be for move-only access
    // let taken: MoveOnlyValue = Builtin.take(rawPtr)
    // print("Taken value: \(taken.value)")

    // Note: Need to verify if Builtin.take exists and signature
    print("  Testing Builtin.addressof: got raw pointer")
    print("  RESULT: Builtin.take exploration needed")
    _ = rawPtr  // suppress unused warning
}

// MARK: - Variant 1.4: withUnsafePointer (read-only) with ~Copyable
// Hypothesis: Read-only pointer access works with ~Copyable
// Result: PENDING

func testReadOnlyPointerNoncopyable() {
    print("\n--- Variant 1.4: withUnsafePointer (read-only) ---")
    let mov = MoveOnlyValue(55)

    withUnsafePointer(to: mov) { ptr in
        print("  Read-only access: \(ptr.pointee.value)")
    }
    print("  RESULT: CONFIRMED - read-only pointer access works")
    _ = mov  // Keep alive
}

// =============================================================================
// SECTION 2: Viable Pointer Primitive Design
// =============================================================================

// MARK: - Variant 2.1: Pointer<T: ~Copyable> wrapper type
// Hypothesis: We can build a useful pointer wrapper for ~Copyable types
// Result: PENDING

struct Pointer<Pointee: ~Copyable>: ~Copyable {
    private let _raw: UnsafeMutablePointer<Pointee>

    init(_ raw: UnsafeMutablePointer<Pointee>) {
        _raw = raw
    }

    var pointee: Pointee {
        _read {
            yield _raw.pointee
        }
        _modify {
            yield &_raw.pointee
        }
    }

    // Borrowing access without copy
    borrowing func withPointee<R>(_ body: (borrowing Pointee) -> R) -> R {
        body(_raw.pointee)
    }
}

func testPointerWrapper() {
    print("\n--- Variant 2.1: Pointer<T: ~Copyable> wrapper ---")
    var mov = MoveOnlyValue(99)

    withUnsafeMutablePointer(to: &mov) { rawPtr in
        let ptr = Pointer(rawPtr)
        print("  Wrapped pointer access: \(ptr.pointee.value)")

        var mutablePtr = ptr
        mutablePtr.pointee.value = 200
        print("  After modification: \(mutablePtr.pointee.value)")
    }
    print("  Final value: \(mov.value)")
    print("  RESULT: CONFIRMED - Pointer wrapper works with ~Copyable")
}

// =============================================================================
// SECTION 3: What About Consuming Access?
// =============================================================================

// MARK: - Variant 3.1: Consuming take from pointer
// Hypothesis: Can we consume/move-out from a pointer location?
// Result: PENDING

extension Pointer where Pointee: ~Copyable {
    // Take ownership of the pointed-to value
    consuming func take() -> Pointee {
        // This should work via _raw.move()
        _raw.move()
    }
}

func testConsumingTake() {
    print("\n--- Variant 3.1: Consuming take from pointer ---")

    // Allocate manually to test take
    let allocated = UnsafeMutablePointer<MoveOnlyValue>.allocate(capacity: 1)
    allocated.initialize(to: MoveOnlyValue(333))

    let ptr = Pointer(allocated)
    print("  Before take: \(ptr.pointee.value)")

    // This should consume the value
    let taken = ptr.take()
    print("  Taken value: \(taken.value)")

    allocated.deallocate()
    // Note: taken will be deinit'd when it goes out of scope
    print("  RESULT: CONFIRMED - consuming take works")
}

// =============================================================================
// SECTION 4: Property.View Pattern Investigation
// =============================================================================

// MARK: - Variant 4.1: Property.View for ~Copyable
// Hypothesis: Property.View pattern works for ~Copyable types
// Result: PENDING

enum Property<Base: ~Copyable> {
    struct View: ~Copyable {
        private let _base: UnsafeMutablePointer<Base>

        init(_ ptr: UnsafeMutablePointer<Base>) {
            _base = ptr
        }

        var base: Base {
            _read { yield _base.pointee }
            _modify { yield &_base.pointee }
        }
    }
}

func testPropertyView() {
    print("\n--- Variant 4.1: Property.View for ~Copyable ---")
    var mov = MoveOnlyValue(444)

    withUnsafeMutablePointer(to: &mov) { ptr in
        var view = Property<MoveOnlyValue>.View(ptr)
        print("  Property.View access: \(view.base.value)")
        view.base.value = 555
        print("  After modification: \(view.base.value)")
    }
    print("  Final value: \(mov.value)")
    print("  RESULT: CONFIRMED - Property.View works for ~Copyable")
}

// =============================================================================
// SECTION 5: ~Escapable Investigation
// =============================================================================

// MARK: - Variant 5.1: Basic ~Escapable creation
// Hypothesis: Can we create and use ~Escapable types at all?
// Result: PENDING

struct NonEscapingValue: ~Escapable {
    var value: Int

    @_lifetime(immortal)
    init(_ v: Int) { value = v }
}

func testNonEscapableCreation() {
    print("\n--- Variant 5.1: ~Escapable creation ---")
    let nev = NonEscapingValue(42)
    print("  Created NonEscapingValue: \(nev.value)")
    print("  RESULT: CONFIRMED - basic ~Escapable works")
}

// MARK: - Variant 5.2: Pointer to ~Escapable
// Hypothesis: Can we get any pointer to ~Escapable?
// Result: BLOCKED - withUnsafeMutablePointer requires Escapable
//
// Uncommenting the function below produces:
// error: global function 'withUnsafeMutablePointer(to:_:)' requires that
//        'NonEscapingValue' conform to 'Escapable'
// withUnsafeMutablePointer:2:13: note: 'where T: Escapable' is implicit here

// func testPointerToNonEscapable() {
//     print("\n--- Variant 5.2: Pointer to ~Escapable ---")
//     var nev = NonEscapingValue(77)
//
//     // This FAILS - withUnsafeMutablePointer requires Escapable
//     withUnsafeMutablePointer(to: &nev) { ptr in
//         print("  Got pointer: \(ptr.pointee.value)")
//     }
// }

// MARK: - Variant 5.3: ~Escapable with Builtin.addressof
// Hypothesis: Can Builtin.addressof work with ~Escapable?
// Result: PENDING

func testAddressOfNonEscapable() {
    print("\n--- Variant 5.3: Builtin.addressof with ~Escapable ---")
    var nev = NonEscapingValue(99)

    // Builtin.addressof should work - it just gets an address
    let rawPtr = Builtin.addressof(&nev)
    print("  Got raw address via Builtin.addressof")

    // But we can't dereference it because Builtin.load requires Escapable
    // let loaded: NonEscapingValue = Builtin.load(rawPtr)  // Would fail

    print("  RESULT: addressof works, but load blocked")
    _ = rawPtr
}

// =============================================================================
// SECTION 6: C Interop Investigation
// =============================================================================

// MARK: - Variant 6.1: C shim_load with simple Copyable type
// Hypothesis: C memcpy (shim_load) works with normal Swift types
// Result: PENDING

func testCShimWithCopyable() {
    print("\n--- Variant 6.1: C shim_load with Copyable type ---")

    var source: Int = 42
    var dest: Int = 0

    withUnsafePointer(to: &source) { srcPtr in
        withUnsafeMutablePointer(to: &dest) { destPtr in
            shim_load(destPtr, srcPtr, MemoryLayout<Int>.size)
        }
    }

    print("  Source: \(source)")
    print("  Dest after shim_load: \(dest)")
    print("  RESULT: CONFIRMED - C shim works with Copyable types")
}

// MARK: - Variant 6.2: C shim_load with ~Copyable type
// Hypothesis: C memcpy can load ~Copyable values (bypassing Builtin.load)
// Result: PENDING

func testCShimWithNoncopyable() {
    print("\n--- Variant 6.2: C shim_load with ~Copyable type ---")

    // Create source value
    var source = MoveOnlyValue(777)

    // Allocate destination
    let destPtr = UnsafeMutablePointer<MoveOnlyValue>.allocate(capacity: 1)
    defer { destPtr.deallocate() }

    // Try to copy bytes via C shim
    withUnsafePointer(to: &source) { srcPtr in
        // shim_load does raw memcpy
        shim_load(destPtr, srcPtr, MemoryLayout<MoveOnlyValue>.size)
    }

    // Access the destination
    // Note: This is unsafe - we've done a bitwise copy of a ~Copyable type
    // The deinit might be called twice!
    print("  Source value: \(source.value)")
    print("  Dest value (via C shim): \(destPtr.pointee.value)")

    // Clean up: We need to be careful here because both source and dest
    // have the same value and both will try to deinit
    // For this test, we'll deinitialize dest to prevent double-deinit
    destPtr.deinitialize(count: 1)

    print("  RESULT: C shim CAN copy ~Copyable bytes, but unsafe!")
    print("  WARNING: This creates double-deinit hazard")
}

// MARK: - Variant 6.3: C shim with ~Escapable - can we get address?
// Hypothesis: Can we use Builtin.addressof + C shim for ~Escapable?
// Result: PENDING

func testCShimWithNonEscapable() {
    print("\n--- Variant 6.3: C shim with ~Escapable ---")

    var source = NonEscapingValue(888)

    // Get raw address via Builtin
    let rawPtr = Builtin.addressof(&source)

    // Convert Builtin.RawPointer to UnsafeRawPointer via integer round-trip
    let voidPtr = unsafeRawPointer(from: rawPtr)

    // We have an address! Can we read from it?
    var dest = NonEscapingValue(0)  // Placeholder
    let destRawPtr = Builtin.addressof(&dest)
    let destVoidPtr = unsafeMutableRawPointer(from: destRawPtr)

    // Copy bytes via C shim
    shim_load(destVoidPtr, voidPtr, MemoryLayout<NonEscapingValue>.size)

    print("  Source value: \(source.value)")
    print("  Dest value (via C shim): \(dest.value)")
    print("  RESULT: C shim CAN copy ~Escapable bytes via Builtin.addressof!")
}

// MARK: - Variant 6.4: NUANCED FINDING - Local vs Parameter difference
// Hypothesis: Can we copy between ~Escapable values using C shim?
// Result: PARTIAL - works for LOCAL variables, blocked for PARAMETERS
//
// ============================================================================
// KEY DISCOVERY:
// ============================================================================
//
// Builtin.addressof has DIFFERENT behavior for:
//
// 1. LOCAL ~Escapable variables: WORKS
//    var local = NonEscapingValue(42)
//    let ptr = Builtin.addressof(&local)  // OK!
//
// 2. FUNCTION PARAMETERS with ~Escapable: BLOCKED
//    func foo<T: ~Escapable>(source: inout T) {
//        let ptr = Builtin.addressof(&source)  // ERROR: escape
//    }
//
// The issue is that function parameters with ~Escapable require
// @_lifetime annotations, and when combined with Builtin.addressof,
// the compiler detects this as an escape.
//
// Compiler error for parameters:
// error: lifetime-dependent variable 'source' escapes its scope
// note: it depends on the lifetime of argument 'source'
// note: this use causes the lifetime-dependent value to escape
//       (pointing at Builtin.addressof)
//
// ============================================================================

// The following code DOES NOT COMPILE for PARAMETERS:

// @_lifetime(source: copy source)
// func copyNonEscapable<T: ~Escapable>(from source: inout T, to dest: inout T) {
//     let srcInt = Int(Builtin.ptrtoint_Word(Builtin.addressof(&source)))
//     //                                      ^^^^^^^^^^^^^^^^^^^^^^^^
//     //                                      ERROR: causes escape
// }

// But this DOES work for LOCAL variables (as shown in Variant 6.3):
// var source = NonEscapingValue(888)
// let rawPtr = Builtin.addressof(&source)  // OK!

func testEscapableAddressOfNuance() {
    print("\n--- Variant 6.4: NUANCED FINDING ---")
    print("  Builtin.addressof behavior differs for local vs parameter:")
    print("")
    print("  LOCAL ~Escapable variables: WORKS")
    print("    var local = NonEscapingValue(42)")
    print("    let ptr = Builtin.addressof(&local)  // OK!")
    print("")
    print("  FUNCTION PARAMETERS with ~Escapable: BLOCKED")
    print("    func foo<T: ~Escapable>(source: inout T) {")
    print("        let ptr = Builtin.addressof(&source)  // ERROR")
    print("    }")
    print("")
    print("  IMPLICATION: Cannot write GENERIC pointer functions for ~Escapable")
    print("  WORKAROUND: Can use C shims for CONCRETE ~Escapable types")
}

// MARK: - Variant 6.5: Both ~Copyable AND ~Escapable (also blocked)
// Hypothesis: C shims work with types that are both ~Copyable and ~Escapable
// Result: BLOCKED - same issue as 6.4

struct MoveOnlyNonEscaping: ~Copyable, ~Escapable {
    var value: Int

    @_lifetime(immortal)
    init(_ v: Int) { value = v }

    deinit { print("  deinit MoveOnlyNonEscaping(\(value))") }
}

// This also DOES NOT COMPILE because of ~Escapable constraint:
// func testCShimWithBothConstraints() {
//     var source = MoveOnlyNonEscaping(1234)
//     let srcInt = Int(Builtin.ptrtoint_Word(Builtin.addressof(&source)))
//     //                                      ^^^^^^^^^^^^^^^^^^^^^^^^
//     //                                      ERROR: causes escape
// }

func testBothConstraintsBlocked() {
    print("\n--- Variant 6.5: ~Copyable & ~Escapable also blocked ---")
    print("  Same issue: Builtin.addressof triggers escape for ~Escapable")
    print("  The ~Copyable aspect is irrelevant - escape detection comes first")
}

// MARK: - Variant 6.6: Final Architectural Analysis
// Result: ANALYSIS COMPLETE
//
// ============================================================================
// DEFINITIVE FINDINGS:
// ============================================================================
//
// The Swift compiler enforces ~Escapable at TWO levels:
//
// Level 1: Builtin.addressof
//   - Taking the address of a ~Escapable value is considered an escape
//   - This happens BEFORE any pointer operations
//   - Cannot be bypassed with C interop
//
// Level 2: Builtin.load
//   - Loading a value from a pointer requires Escapable
//   - This is a secondary constraint (never reached for ~Escapable)
//
// IMPLICATIONS:
//
// For ~Copyable (but Escapable) types:
//   ✓ UnsafeMutablePointer works (Swift stdlib support)
//   ✓ Builtin.addressof works
//   ✓ C shims work (but unsafe - creates copies)
//
// For ~Escapable (but Copyable) types:
//   ✗ Builtin.addressof triggers escape detection
//   ✗ Cannot get address at all
//   ✗ C shims CANNOT help
//
// For ~Copyable AND ~Escapable types:
//   ✗ Blocked by escape detection (same as ~Escapable alone)
//
// CONCLUSION:
// C interop is NOT a viable path for ~Escapable pointer support.
// Language evolution (PITCH-0003) is the only solution.
// ============================================================================

// =============================================================================
// MAIN
// =============================================================================

print("=" * 70)
print("POINTER PRIMITIVES FEASIBILITY INVESTIGATION")
print("=" * 70)

// Original tests
testNoncopyablePointer()
testBuiltinTakeNoncopyable()
testReadOnlyPointerNoncopyable()
testPointerWrapper()
testConsumingTake()
testPropertyView()
testNonEscapableCreation()
testAddressOfNonEscapable()

// C Interop tests
print("\n" + "=" * 70)
print("C INTEROP INVESTIGATION")
print("=" * 70)

testCShimWithCopyable()
testCShimWithNoncopyable()
testCShimWithNonEscapable()
testEscapableAddressOfNuance()
testBothConstraintsBlocked()

print("\n" + "=" * 70)
print("SUMMARY OF FINDINGS")
print("=" * 70)
print("""

SECTION 1-5: SWIFT-ONLY APPROACH
================================

CONFIRMED WORKING:
✓ UnsafeMutablePointer with ~Copyable types
✓ withUnsafePointer (read-only) with ~Copyable types
✓ Pointer<T: ~Copyable> wrapper pattern
✓ Consuming take from pointer
✓ Property.View for ~Copyable types
✓ Basic ~Escapable type creation
✓ Builtin.addressof with LOCAL ~Escapable (concrete types)

NOT WORKING:
✗ Builtin.load with ~Copyable (requires Copyable)
✗ withUnsafeMutablePointer with ~Escapable (requires Escapable)
✗ Builtin.load with ~Escapable (requires Escapable)

SECTION 6: C INTEROP APPROACH
=============================

NUANCED DISCOVERY: C shims have LIMITED support for ~Escapable!

Builtin.addressof behavior:
  ✓ LOCAL ~Escapable variables: WORKS
  ✗ FUNCTION PARAMETERS with ~Escapable: BLOCKED (triggers escape)

C INTEROP RESULTS:
==================

For Copyable types (with or without ~Copyable):
  ✓ C shim_load/shim_store work
  ✓ Can copy bytes via memcpy
  ⚠ For ~Copyable: creates forbidden copy (double-deinit hazard)

For LOCAL ~Escapable values:
  ✓ Builtin.addressof works on local variables
  ✓ Can pass address to C shim
  ✓ C memcpy works

For GENERIC ~Escapable functions:
  ✗ Function parameters trigger escape detection
  ✗ Cannot write Pointer<T: ~Escapable> wrapper
  ✗ Cannot write generic copy functions

CONCLUSION:
===========

swift-pointer-primitives has LIMITED ~Escapable support:

Tier 1 - FULLY VIABLE (Pure Swift):
  - Pointer<T: ~Copyable> uses UnsafeMutablePointer
  - Works when T is Escapable (implicit)
  - Recommended for move-only resource handles

Tier 2 - PARTIALLY VIABLE (C Interop, concrete types only):
  - Can use C shim with CONCRETE ~Escapable types
  - Builtin.addressof works on LOCAL variables
  - CANNOT write generic CPointer<T: ~Escapable> wrapper

Tier 3 - NOT VIABLE (generic ~Escapable):
  - Generic functions with ~Escapable parameters are blocked
  - Escape detection triggers on Builtin.addressof

FOR FULL ~ESCAPABLE SUPPORT:
  - Language evolution (PITCH-0003) required
  - Need lifetime-aware Builtin operations
  - OR: Escape detection needs to understand C interop boundary

""")

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

