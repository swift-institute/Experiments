// MARK: - Tagged Operator Forwarding for Pointer Arithmetic
// Purpose: Verify if Tagged<T, Memory.Address> inherits operators from affine-primitives
// Hypothesis: Tagged forwards operators, so Pointer<T> + Index<T>.Offset should work
//
// Toolchain: Swift 6.2
// Platform: macOS 26
//
// Result: REFUTED - operators don't apply due to nested Tag structure
//         CONFIRMED - delegation pattern works: unwrap → scale → delegate → rewrap
// Date: 2026-02-02
//
// Original Error: binary operator '+' cannot be applied to operands of type
//        'Tagged<Int, Memory.Mutable.Address>' (aka 'Tagged<Int, Tagged<Memory.Mutable, Ordinal>>')
//        and 'Index<Int>.Offset' (aka 'Tagged<Int, Affine.Discrete.Vector>')
//
// Solution: Design A - explicit bridge layer
//   V1: Memory.Address + Memory.Address.Offset: CONFIRMED
//   V2: Index<T>.Offset * Ratio → Memory.Address.Offset: CONFIRMED
//   V3: Full delegation pattern: CONFIRMED

import Pointer_Primitives
import Index_Primitives
import Affine_Primitives
import Memory_Primitives
import Cardinal_Primitives

// MARK: - Analysis
//
// Why generic Tagged+Affine operators don't apply:
//
// Tagged+Affine provides: Tagged<Tag, Ordinal> ± Tagged<Tag, Affine.Discrete.Vector>
//
// But Pointer<T> is: Tagged<T, Memory.Address>
//                  = Tagged<T, Tagged<Memory, Ordinal>>  (NESTED!)
//
// The RawValue is Memory.Address (itself a Tagged), not Ordinal directly.
// So the affine operators don't match.
//
// The correct arithmetic domain for Pointer is:
//   - point: Memory.Address (bytes)
//   - vector: Memory.Address.Offset (bytes)
//
// And we need conversion: Index<T>.Offset (elements) → Memory.Address.Offset (bytes)
//
// SOLUTION (Design A):
// 1. Add: Memory.Address.Offset.init(scaling: Index<T>.Offset, by: Affine.Discrete.Ratio<T, Memory>)
// 2. Implement Pointer.advanced(by:) as:
//    - unwrap: pointer.rawValue → Memory.Address
//    - scale: Index<T>.Offset * stride → Memory.Address.Offset
//    - compute: address + byteOffset (already works!)
//    - rewrap: Pointer<T>(address)
//
// This reuses Memory.Address arithmetic, no new operator overloads needed.

// MARK: - Variant 1: Memory.Address arithmetic works
// Hypothesis: Memory.Address + Memory.Address.Offset already works

func testMemoryAddressArithmetic() {
    print("V1: Memory.Address arithmetic")

    let count = Index<Int>.Count(Cardinal(8))
    let ptr = Pointer<Int>.Mutable.allocate(capacity: count)
    defer { ptr.deallocate() }

    // Get the underlying Memory.Mutable.Address
    let address: Memory.Mutable.Address = ptr.rawValue

    // Create a byte offset (8 bytes = 1 Int on 64-bit)
    let byteOffset = Memory.Address.Offset(8)

    // This should work - Memory.Address + Memory.Address.Offset
    let newAddress = address + byteOffset
    _ = newAddress

    print("  Memory.Address + Memory.Address.Offset: CONFIRMED")
}

// MARK: - Variant 2: Element→Byte scaling with Ratio
// Hypothesis: We can scale Index<T>.Offset to Memory.Address.Offset

func testElementToByteScaling() {
    print("V2: Element→Byte scaling")

    // Element offset
    let elementOffset = Index<Int>.Offset(3)

    // Stride ratio: how many bytes per Int
    let stride: Affine.Discrete.Ratio<Int, Memory> = .init(MemoryLayout<Int>.stride)

    // Scale: elementOffset * stride → Memory.Address.Offset
    // This uses Tagged<From, Vector> * Ratio<From, To> → Tagged<To, Vector>
    let byteOffset: Memory.Address.Offset = elementOffset * stride

    print("  elementOffset: \(elementOffset)")
    print("  stride: \(stride)")
    print("  byteOffset: \(byteOffset)")
    print("  Element * Stride → Bytes: CONFIRMED")
}

// MARK: - Variant 3: Full pointer arithmetic via delegation
// Hypothesis: We can implement Pointer.advanced(by:) by delegating to Memory.Address

func testPointerArithmeticViaDelegation() {
    print("V3: Pointer arithmetic via delegation")

    let count = Index<Int>.Count(Cardinal(8))
    let ptr = Pointer<Int>.Mutable.allocate(capacity: count)
    defer {
        _ = ptr.deinitialize(count: count)
        ptr.deallocate()
    }
    ptr.initialize(repeating: 0, count: count)

    // Fill with values using base pointer subscript
    unsafe ptr.base[0] = 100
    unsafe ptr.base[1] = 200
    unsafe ptr.base[2] = 300
    unsafe ptr.base[3] = 400

    // Manual "advanced(by: 3)" implementation:
    let elementOffset = Index<Int>.Offset(3)
    let stride: Affine.Discrete.Ratio<Int, Memory> = .init(MemoryLayout<Int>.stride)
    let byteOffset: Memory.Address.Offset = elementOffset * stride

    // Unwrap → compute → rewrap
    let baseAddress: Memory.Mutable.Address = ptr.rawValue
    let newAddress: Memory.Mutable.Address = baseAddress + byteOffset

    // Rewrap using Tagged's internal constructor
    let advancedPtr = Pointer<Int>.Mutable(__unchecked: (), newAddress)

    print("  Original ptr.base[3]: \(unsafe ptr.base[3])")
    print("  Advanced ptr.pointee: \(advancedPtr.pointee)")
    print("  Match: \(unsafe ptr.base[3] == advancedPtr.pointee)")
    print("  Delegation pattern: CONFIRMED")
}

// MARK: - Main

testMemoryAddressArithmetic()
testElementToByteScaling()
testPointerArithmeticViaDelegation()

print("\n--- Conclusion ---")
print("Generic Tagged+Affine operators do NOT apply to Pointer due to nested tag structure.")
print("Solution: Delegate to Memory.Address arithmetic with explicit element→byte scaling.")
print("Implementation: Pointer.advanced(by:) unwraps, scales, delegates, rewraps.")
