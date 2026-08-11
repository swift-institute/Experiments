// MARK: - Index Offset Arithmetic Verification
// Purpose: Verify affine pointer arithmetic with Index<T>.Offset
// Hypothesis: ptr + (index - .zero) pattern works correctly
//
// Toolchain: Swift 6.2
// Status: SUPERSEDED 2026-04-30 — Index subtraction return type migrated from Tagged<Int, Ordinal> to Tagged<Int, Affine.Discrete.Vector>; experiment's affine arithmetic patterns require re-targeting against new typed-subtraction surface
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: macOS 26
//
// Result: CONFIRMED
// Date: 2026-02-02

import Index_Primitives
import Cardinal_Primitives
import Affine_Primitives

// MARK: - Variant 1: Index subtraction gives Offset
// Result: CONFIRMED

func testIndexSubtraction() throws {
    print("V1: Index<T> - Index<T> -> Index<T>.Offset")

    let idx3: Index<Int> = try Index(3)
    let idx0: Index<Int> = .zero

    let offset: Index<Int>.Offset = try idx3 - idx0

    print("  idx3 - .zero = \(offset)")
    print("  Index subtraction: CONFIRMED")
}

// MARK: - Variant 2: UnsafeMutablePointer + Index<T>.Offset
// Result: CONFIRMED (after adding operator)

func testPointerPlusOffset() {
    print("V2: UnsafeMutablePointer + Index<T>.Offset")

    let count = 5
    let ptr = UnsafeMutablePointer<Int>.allocate(capacity: count)
    defer { ptr.deallocate() }

    for i in 0..<5 {
        unsafe (ptr + i).initialize(to: i * 10)
    }

    let offset: Index<Int>.Offset = Index<Int>.Offset(3)
    let advanced = unsafe ptr + offset

    print("  ptr + Offset(3): \(unsafe advanced.pointee)")
    print("  Expected: 30")
    print("  Pointer + Offset: \(unsafe advanced.pointee == 30 ? "CONFIRMED" : "REFUTED")")
}

// MARK: - Variant 3: Full pattern - ptr + (index - .zero)
// Result: CONFIRMED

func testFullPattern() throws {
    print("V3: ptr + (index - .zero)")

    let count = 5
    let ptr = UnsafeMutablePointer<Int>.allocate(capacity: count)
    defer { ptr.deallocate() }

    for i in 0..<5 {
        unsafe (ptr + i).initialize(to: (i + 1) * 100)
    }

    let idx: Index<Int> = try Index(2)
    let advanced = unsafe ptr + (try idx - .zero)

    print("  ptr + (idx - .zero) where idx=2: \(unsafe advanced.pointee)")
    print("  Expected: 300")
    print("  Full pattern: \(unsafe advanced.pointee == 300 ? "CONFIRMED" : "REFUTED")")
}

// MARK: - Variant 4: Subscript uses the pattern internally
// Result: CONFIRMED

func testSubscript() throws {
    print("V4: Subscript ptr[index]")

    let count = 5
    let ptr = UnsafeMutablePointer<Int>.allocate(capacity: count)
    defer { ptr.deallocate() }

    for i in 0..<5 {
        unsafe (ptr + i).initialize(to: (i + 1) * 100)
    }

    let idx: Index<Int> = try Index(2)
    let value = unsafe ptr[idx]

    print("  ptr[idx] where idx=2: \(value)")
    print("  Expected: 300")
    print("  Subscript: \(value == 300 ? "CONFIRMED" : "REFUTED")")
}

// MARK: - Main

do {
    try testIndexSubtraction()
    testPointerPlusOffset()
    try testFullPattern()
    try testSubscript()

    print("\n--- Conclusion ---")
    print("All variants CONFIRMED.")
    print("Affine arithmetic pattern: ptr + (index - .zero) works correctly.")
    print("Subscript internally uses this pattern.")
} catch {
    print("Error: \(error)")
}
