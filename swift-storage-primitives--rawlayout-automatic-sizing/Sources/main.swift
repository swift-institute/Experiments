// MARK: - @_rawLayout Automatic Sizing Investigation
// Purpose: Can @_rawLayout(likeArrayOf:count:) eliminate the Slot parameter?
//   This would give Storage.Inline<Element, capacity> with AUTOMATIC layout
//   computation — no user-specified slot type needed.
//
// Hypothesis: @_rawLayout(likeArrayOf: Element, count: capacity) computes
//   size = MemoryLayout<Element>.stride × capacity
//   alignment = MemoryLayout<Element>.alignment
//   automatically at compile time, for ANY Element including ~Copyable.
//
// Toolchain: Swift 6.2 (Xcode 26)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — all sizes match ideal, automatic layout works
// Date: 2026-02-05

// ============================================================================
// MARK: - Approach A: @_rawLayout(likeArrayOf: Element, count: capacity)
// Hypothesis: Automatic layout from generic parameters
// Result: CONFIRMED
// ============================================================================

// Note: @_rawLayout types are ALWAYS ~Copyable — cannot have conditional Copyable
@_rawLayout(likeArrayOf: Element, count: capacity)
struct AutoStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {}

func testApproachA() {
    print("=== Approach A: @_rawLayout(likeArrayOf: Element, count: capacity) ===")
    print()

    // Double × 4 — should be exactly 32 bytes
    print("AutoStorage<Double, 4>:")
    print("  size=\(MemoryLayout<AutoStorage<Double, 4>>.size) bytes (ideal: 32)")
    print("  stride=\(MemoryLayout<AutoStorage<Double, 4>>.stride)")
    print("  alignment=\(MemoryLayout<AutoStorage<Double, 4>>.alignment)")
    print()

    // UInt8 × 16 — should be exactly 16 bytes
    print("AutoStorage<UInt8, 16>:")
    print("  size=\(MemoryLayout<AutoStorage<UInt8, 16>>.size) bytes (ideal: 16)")
    print("  stride=\(MemoryLayout<AutoStorage<UInt8, 16>>.stride)")
    print("  alignment=\(MemoryLayout<AutoStorage<UInt8, 16>>.alignment)")
    print()

    // Int32 × 8 — should be exactly 32 bytes
    print("AutoStorage<Int32, 8>:")
    print("  size=\(MemoryLayout<AutoStorage<Int32, 8>>.size) bytes (ideal: 32)")
    print("  stride=\(MemoryLayout<AutoStorage<Int32, 8>>.stride)")
    print("  alignment=\(MemoryLayout<AutoStorage<Int32, 8>>.alignment)")
    print()

    // Int × 4 — should be exactly 32 bytes
    print("AutoStorage<Int, 4>:")
    print("  size=\(MemoryLayout<AutoStorage<Int, 4>>.size) bytes (ideal: 32)")
    print("  stride=\(MemoryLayout<AutoStorage<Int, 4>>.stride)")
    print("  alignment=\(MemoryLayout<AutoStorage<Int, 4>>.alignment)")
    print()

    // UInt16 × 8 — should be exactly 16 bytes
    print("AutoStorage<UInt16, 8>:")
    print("  size=\(MemoryLayout<AutoStorage<UInt16, 8>>.size) bytes (ideal: 16)")
    print("  stride=\(MemoryLayout<AutoStorage<UInt16, 8>>.stride)")
    print("  alignment=\(MemoryLayout<AutoStorage<UInt16, 8>>.alignment)")
    print()

    // Float × 4 — should be exactly 16 bytes
    print("AutoStorage<Float, 4>:")
    print("  size=\(MemoryLayout<AutoStorage<Float, 4>>.size) bytes (ideal: 16)")
    print("  stride=\(MemoryLayout<AutoStorage<Float, 4>>.stride)")
    print("  alignment=\(MemoryLayout<AutoStorage<Float, 4>>.alignment)")
    print()
}

// ============================================================================
// MARK: - Approach B: ~Copyable Elements
// Hypothesis: Works with move-only types
// Result: CONFIRMED
// ============================================================================

struct Resource: ~Copyable {
    var a: Int
    var b: Int
}

func testApproachB() {
    print("=== Approach B: ~Copyable Elements ===")
    print()

    print("Resource (16-byte ~Copyable):")
    print("  size=\(MemoryLayout<Resource>.size)")
    print("  stride=\(MemoryLayout<Resource>.stride)")
    print("  alignment=\(MemoryLayout<Resource>.alignment)")
    print()

    print("AutoStorage<Resource, 4>:")
    print("  size=\(MemoryLayout<AutoStorage<Resource, 4>>.size) bytes (ideal: 64)")
    print("  stride=\(MemoryLayout<AutoStorage<Resource, 4>>.stride)")
    print("  alignment=\(MemoryLayout<AutoStorage<Resource, 4>>.alignment)")
    print()
}

// ============================================================================
// MARK: - Approach C: Odd-Sized Elements
// Hypothesis: Handles non-power-of-2 correctly
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

struct ThreeBytes: ~Copyable {
    var a: UInt8
    var b: UInt8
    var c: UInt8
}

struct FiveInts: ~Copyable {
    var a: Int
    var b: Int
    var c: Int
    var d: Int
    var e: Int
}

func testApproachC() {
    print("=== Approach C: Odd-Sized Elements ===")
    print()

    print("ThreeBytes:")
    print("  size=\(MemoryLayout<ThreeBytes>.size)")
    print("  stride=\(MemoryLayout<ThreeBytes>.stride)")
    print("  alignment=\(MemoryLayout<ThreeBytes>.alignment)")
    print()

    print("AutoStorage<ThreeBytes, 10>:")
    let expected3 = MemoryLayout<ThreeBytes>.stride * 10
    print("  size=\(MemoryLayout<AutoStorage<ThreeBytes, 10>>.size) bytes (ideal: \(expected3))")
    print("  stride=\(MemoryLayout<AutoStorage<ThreeBytes, 10>>.stride)")
    print("  alignment=\(MemoryLayout<AutoStorage<ThreeBytes, 10>>.alignment)")
    print()

    print("FiveInts (40-byte struct):")
    print("  size=\(MemoryLayout<FiveInts>.size)")
    print("  stride=\(MemoryLayout<FiveInts>.stride)")
    print("  alignment=\(MemoryLayout<FiveInts>.alignment)")
    print()

    print("AutoStorage<FiveInts, 3>:")
    let expected5 = MemoryLayout<FiveInts>.stride * 3
    print("  size=\(MemoryLayout<AutoStorage<FiveInts, 3>>.size) bytes (ideal: \(expected5))")
    print("  stride=\(MemoryLayout<AutoStorage<FiveInts, 3>>.stride)")
    print("  alignment=\(MemoryLayout<AutoStorage<FiveInts, 3>>.alignment)")
    print()
}

// ============================================================================
// MARK: - Comparison: AutoStorage vs 64-byte Slots vs Parameterized Cell
// ============================================================================

func testComparison() {
    print("=== Comparison Table ===")
    print()
    print("Element        | Count | @_rawLayout | Cell<N,Base> | 64B Slots | Savings")
    print("---------------|-------|-------------|--------------|-----------|--------")

    func row(_ name: String, _ count: Int, _ auto: Int, _ cell: Int, _ fixed: Int) {
        let savings = Int((1.0 - Double(auto)/Double(fixed)) * 100)
        print("\(name)  \(count)      \(auto) B          \(cell) B         \(fixed) B      \(savings)%")
    }

    row("Double        ", 4, MemoryLayout<AutoStorage<Double, 4>>.size, 32, 256)
    row("UInt8         ", 16, MemoryLayout<AutoStorage<UInt8, 16>>.size, 16, 1024)
    row("Int32         ", 8, MemoryLayout<AutoStorage<Int32, 8>>.size, 32, 512)
    row("Resource(16B) ", 4, MemoryLayout<AutoStorage<Resource, 4>>.size, 64, 256)
    row("FiveInts(40B) ", 3, MemoryLayout<AutoStorage<FiveInts, 3>>.size, 120, 192)

    print()
}

// ============================================================================
// MARK: - Summary
// ============================================================================

func printSummary() {
    print("=== SUMMARY ===")
    print()
    print("@_rawLayout(likeArrayOf: Element, count: capacity) provides:")
    print("  1. AUTOMATIC size: stride(Element) x capacity")
    print("  2. AUTOMATIC alignment: matches Element")
    print("  3. Works with ~Copyable elements")
    print("  4. NO Slot parameter needed")
    print("  5. Handles odd-sized elements correctly")
    print()
    print("Storage.Inline signature simplifies from:")
    print("  Storage.Inline<Element, capacity, Slot>  // user picks Slot")
    print("to:")
    print("  Storage.Inline<Element, capacity>        // automatic!")
    print()
    print("Constraints:")
    print("  - @_rawLayout types are ALWAYS ~Copyable (cannot conditionally conform)")
    print("  - @_rawLayout is underscored (not ABI-stable)")
    print("  - Element access requires Builtin.addressOfRawLayout (stdlib-internal)")
    print()
    print("For Storage.Inline, the ~Copyable constraint is acceptable since")
    print("the storage wrapper controls initialization state anyway.")
}

// ============================================================================
// MARK: - Execution
// ============================================================================

testApproachA()
testApproachB()
testApproachC()
testComparison()
printSummary()
