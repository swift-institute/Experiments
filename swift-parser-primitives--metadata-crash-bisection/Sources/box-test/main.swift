// MARK: - Cross-Module Generic Metadata Crash Bisection
// Purpose: Narrow which type argument to a cross-module generic triggers SIGSEGV
// Hypothesis: The crash is in cross-module generic metadata instantiation,
//             specifically when Input.Slice<Buffer<UInt8>.Linear> is a type argument
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: PENDING
// Date: 2026-02-13

import BoxModule
import Input_Primitives
import Collection_Primitives
import Buffer_Linear_Primitives

// =============================================================================
// MARK: - V1: Box<Int, Int> (control — trivial types)
// =============================================================================
// Result: PENDING

print("V1: Box<Int, Int> (control)...")
let v1 = Box<Int, Int>(1, 2)
print("  a=\(v1.a) b=\(v1.b) PASSED")

// =============================================================================
// MARK: - V2: Box<[UInt8], Int> (simple array)
// =============================================================================
// Result: PENDING

print("V2: Box<[UInt8], Int>...")
let v2 = Box<[UInt8], Int>([0xFF], 42)
print("  b=\(v2.b) PASSED")

// =============================================================================
// MARK: - V3: Box<Buffer<UInt8>.Linear, Int> (just Buffer.Linear, no Input.Slice)
// =============================================================================
// Result: PENDING

print("V3: Box<Buffer<UInt8>.Linear, Int>...")
let v3 = Box<Buffer<UInt8>.Linear, Int>({
    var b = Buffer<UInt8>.Linear()
    b.append(0xFF)
    return b
}(), 42)
print("  b=\(v3.b) PASSED")

// =============================================================================
// MARK: - V4: Box<Input.Slice<Buffer<UInt8>.Linear>, Int> (the suspect)
// =============================================================================
// Result: PENDING

print("V4: Box<Input.Slice<Buffer<UInt8>.Linear>, Int>...")
let v4 = Box<Input.Slice<Buffer<UInt8>.Linear>, Int>({
    var b = Buffer<UInt8>.Linear()
    b.append(0xFF)
    return Input.Slice(b)
}(), 42)
print("  b=\(v4.b) PASSED")

// =============================================================================
print("\nALL PASSED")
