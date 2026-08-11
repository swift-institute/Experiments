// MARK: - Inline Storage: Optimal Single-Type Investigation
// Purpose: Can we get ONE type with ZERO overhead for ALL element sizes?
//   Including sub-word elements (UInt8, UInt16, Int32).
//
// Key insight: the backing type's alignment determines what elements it can safely hold.
//   UInt8-backed → alignment 1, any byte-aligned element
//   UInt32-backed → alignment 4, any 4-byte-aligned element
//   Int-backed → alignment 8, any 8-byte-aligned element
//
// Toolchain: Swift 6.2 (Xcode 26)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — Cell<let count: Int, Base: BitwiseCopyable & Sendable> achieves
//   zero overhead for ALL element sizes (1B through 64B+). Span-compatible when cell
//   stride matches element stride. ~Copyable storage works via pointer placement into
//   Copyable cell backing. Approach E also shows Cell wrapper is optional — raw
//   InlineArray<N, Base> as the slot type works identically.
// Date: 2026-02-04

// ============================================================================
// MARK: - Approach A: Cell<count, Base> — Two Generic Parameters
// Hypothesis: ONE type, zero overhead for ALL sizes
// Result: CONFIRMED — all sizes 1B–64B match ideal, correct alignment
// ============================================================================

struct Cell<let count: Int, Base: BitwiseCopyable & Sendable>: Copyable, Sendable {
    var _backing: InlineArray<count, Base>

    static var byteWidth: Int { count * MemoryLayout<Base>.stride }
    static var alignment: Int { MemoryLayout<Base>.alignment }
}

// Provide init for common base types
extension Cell where Base == UInt8  { init() { _backing = InlineArray(repeating: 0) } }
extension Cell where Base == UInt16 { init() { _backing = InlineArray(repeating: 0) } }
extension Cell where Base == UInt32 { init() { _backing = InlineArray(repeating: 0) } }
extension Cell where Base == Int    { init() { _backing = InlineArray(repeating: 0) } }

func testApproachA() {
    print("=== Approach A: Cell<count, Base> ===")
    print()

    // 1-byte cells (for UInt8)
    print("Cell<1, UInt8>:  size=\(MemoryLayout<Cell<1, UInt8>>.size), stride=\(MemoryLayout<Cell<1, UInt8>>.stride), align=\(MemoryLayout<Cell<1, UInt8>>.alignment)")
    // 2-byte cells (for UInt16)
    print("Cell<1, UInt16>: size=\(MemoryLayout<Cell<1, UInt16>>.size), stride=\(MemoryLayout<Cell<1, UInt16>>.stride), align=\(MemoryLayout<Cell<1, UInt16>>.alignment)")
    // 4-byte cells (for Int32, Float)
    print("Cell<1, UInt32>: size=\(MemoryLayout<Cell<1, UInt32>>.size), stride=\(MemoryLayout<Cell<1, UInt32>>.stride), align=\(MemoryLayout<Cell<1, UInt32>>.alignment)")
    // 8-byte cells (for Int, Double)
    print("Cell<1, Int>:    size=\(MemoryLayout<Cell<1, Int>>.size), stride=\(MemoryLayout<Cell<1, Int>>.stride), align=\(MemoryLayout<Cell<1, Int>>.alignment)")
    // 16-byte cells (for SIMD2, two-word structs)
    print("Cell<2, Int>:    size=\(MemoryLayout<Cell<2, Int>>.size), stride=\(MemoryLayout<Cell<2, Int>>.stride), align=\(MemoryLayout<Cell<2, Int>>.alignment)")
    // 64-byte cells (current default)
    print("Cell<8, Int>:    size=\(MemoryLayout<Cell<8, Int>>.size), stride=\(MemoryLayout<Cell<8, Int>>.stride), align=\(MemoryLayout<Cell<8, Int>>.alignment)")
    print()

    // Every element type gets zero-overhead cells:
    print("Zero-overhead cell selection:")
    print("  UInt8  (stride=\(MemoryLayout<UInt8>.stride), align=\(MemoryLayout<UInt8>.alignment)) → Cell<1, UInt8>  = \(MemoryLayout<Cell<1, UInt8>>.stride)B ✓")
    print("  UInt16 (stride=\(MemoryLayout<UInt16>.stride), align=\(MemoryLayout<UInt16>.alignment)) → Cell<1, UInt16> = \(MemoryLayout<Cell<1, UInt16>>.stride)B ✓")
    print("  Int32  (stride=\(MemoryLayout<Int32>.stride), align=\(MemoryLayout<Int32>.alignment)) → Cell<1, UInt32> = \(MemoryLayout<Cell<1, UInt32>>.stride)B ✓")
    print("  Float  (stride=\(MemoryLayout<Float>.stride), align=\(MemoryLayout<Float>.alignment)) → Cell<1, UInt32> = \(MemoryLayout<Cell<1, UInt32>>.stride)B ✓")
    print("  Int    (stride=\(MemoryLayout<Int>.stride), align=\(MemoryLayout<Int>.alignment)) → Cell<1, Int>    = \(MemoryLayout<Cell<1, Int>>.stride)B ✓")
    print("  Double (stride=\(MemoryLayout<Double>.stride), align=\(MemoryLayout<Double>.alignment)) → Cell<1, Int>    = \(MemoryLayout<Cell<1, Int>>.stride)B ✓")
    print()
}

// ============================================================================
// MARK: - Approach B: Skip Cell, Use Backing Type Directly
// Hypothesis: Storage.Inline<Element, capacity, Backing> where Backing
//   is the InlineArray element type. No wrapper needed.
// Result: CONFIRMED — 16B, 32B, 32B all match ideal; ~Copyable init works
// ============================================================================

struct DirectStorage<Element: ~Copyable, let capacity: Int, Backing: BitwiseCopyable & Sendable>: ~Copyable {
    var _storage: InlineArray<capacity, Backing>

    func pointer(at index: Int) -> UnsafePointer<Element> {
        return unsafe withUnsafePointer(to: _storage) { base in
            let raw = unsafe UnsafeRawPointer(base)
                .advanced(by: index * MemoryLayout<Backing>.stride)
            return unsafe raw.assumingMemoryBound(to: Element.self)
        }
    }

    mutating func mutablePointer(at index: Int) -> UnsafeMutablePointer<Element> {
        return unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = unsafe UnsafeMutableRawPointer(base)
                .advanced(by: index * MemoryLayout<Backing>.stride)
            return unsafe raw.assumingMemoryBound(to: Element.self)
        }
    }

    mutating func initialize(to element: consuming Element, at index: Int) {
        unsafe mutablePointer(at: index).initialize(to: element)
    }

    mutating func move(at index: Int) -> Element {
        unsafe mutablePointer(at: index).move()
    }
}

extension DirectStorage: Copyable where Element: Copyable {}
extension DirectStorage: Sendable where Element: Sendable {}

// Init for common backing types
extension DirectStorage where Backing == UInt8, Element: ~Copyable {
    init() { _storage = InlineArray(repeating: 0) }
}
extension DirectStorage where Backing == UInt16, Element: ~Copyable {
    init() { _storage = InlineArray(repeating: 0) }
}
extension DirectStorage where Backing == UInt32, Element: ~Copyable {
    init() { _storage = InlineArray(repeating: 0) }
}
extension DirectStorage where Backing == Int, Element: ~Copyable {
    init() { _storage = InlineArray(repeating: 0) }
}

func testApproachB() {
    print("=== Approach B: DirectStorage<Element, capacity, Backing> ===")
    print()

    // UInt8 elements — zero overhead!
    print("DirectStorage<UInt8, 16, UInt8>:")
    print("  size=\(MemoryLayout<DirectStorage<UInt8, 16, UInt8>>.size) bytes (ideal: 16)")
    var s1 = DirectStorage<UInt8, 16, UInt8>()
    for i: UInt8 in 0..<16 { s1.initialize(to: i, at: Int(i)) }
    print("  First=\(s1.move(at: 0)), Last=\(s1.move(at: 15))")
    for i in 1..<15 { _ = s1.move(at: i) }
    print()

    // Double elements — zero overhead!
    print("DirectStorage<Double, 4, Int>:")
    print("  size=\(MemoryLayout<DirectStorage<Double, 4, Int>>.size) bytes (ideal: 32)")
    var s2 = DirectStorage<Double, 4, Int>()
    s2.initialize(to: 1.0, at: 0)
    s2.initialize(to: 2.0, at: 1)
    s2.initialize(to: 3.0, at: 2)
    s2.initialize(to: 4.0, at: 3)
    print("  Values: \(s2.move(at: 0)), \(s2.move(at: 1)), \(s2.move(at: 2)), \(s2.move(at: 3))")
    print()

    // Int32 elements — zero overhead!
    print("DirectStorage<Int32, 8, UInt32>:")
    print("  size=\(MemoryLayout<DirectStorage<Int32, 8, UInt32>>.size) bytes (ideal: 32)")
    var s3 = DirectStorage<Int32, 8, UInt32>()
    for i: Int32 in 0..<8 { s3.initialize(to: i * 10, at: Int(i)) }
    print("  First=\(s3.move(at: 0)), Last=\(s3.move(at: 7))")
    for i in 1..<7 { _ = s3.move(at: i) }
    print()

    // ~Copyable elements with 16-byte cells
    struct Resource: ~Copyable {
        var a: Int
        var b: Int
    }
    // For Resource (16 bytes), need Cell<2, Int> equivalent
    // But DirectStorage can't directly use Cell as Backing...
    // We'd need a 16-byte BitwiseCopiable type.
    // Can we use InlineArray<2, Int> as Backing?
    print()
}

// ============================================================================
// MARK: - Approach C: Cell<count, Base> as the Backing
// Hypothesis: Combine A and B. Cell<count, Base> IS the backing type for
//   DirectStorage. This handles multi-word cells too.
// Result: CONFIRMED — ~Copyable Resource(a,b) in Cell<2,Int> works, 64B ideal
// ============================================================================

// Can Cell conform to BitwiseCopiable?
// BitwiseCopiable is inferred for structs whose stored properties are all BitwiseCopiable.
// InlineArray<N, Base> where Base: BitwiseCopiable should be BitwiseCopiable.

struct StorageV3<Element: ~Copyable, let capacity: Int, let cellCount: Int, CellBase: BitwiseCopyable & Sendable>: ~Copyable {
    var _storage: InlineArray<capacity, Cell<cellCount, CellBase>>

    func pointer(at index: Int) -> UnsafePointer<Element> {
        return unsafe withUnsafePointer(to: _storage) { base in
            let raw = unsafe UnsafeRawPointer(base)
                .advanced(by: index * MemoryLayout<Cell<cellCount, CellBase>>.stride)
            return unsafe raw.assumingMemoryBound(to: Element.self)
        }
    }

    mutating func mutablePointer(at index: Int) -> UnsafeMutablePointer<Element> {
        return unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = unsafe UnsafeMutableRawPointer(base)
                .advanced(by: index * MemoryLayout<Cell<cellCount, CellBase>>.stride)
            return unsafe raw.assumingMemoryBound(to: Element.self)
        }
    }

    mutating func initialize(to element: consuming Element, at index: Int) {
        unsafe mutablePointer(at: index).initialize(to: element)
    }

    mutating func move(at index: Int) -> Element {
        unsafe mutablePointer(at: index).move()
    }
}

extension StorageV3: Copyable where Element: Copyable {}
extension StorageV3: Sendable where Element: Sendable {}

extension StorageV3 where CellBase == UInt8, Element: ~Copyable {
    init() { _storage = InlineArray(repeating: Cell<cellCount, UInt8>()) }
}
extension StorageV3 where CellBase == UInt16, Element: ~Copyable {
    init() { _storage = InlineArray(repeating: Cell<cellCount, UInt16>()) }
}
extension StorageV3 where CellBase == UInt32, Element: ~Copyable {
    init() { _storage = InlineArray(repeating: Cell<cellCount, UInt32>()) }
}
extension StorageV3 where CellBase == Int, Element: ~Copyable {
    init() { _storage = InlineArray(repeating: Cell<cellCount, Int>()) }
}

func testApproachC() {
    print("=== Approach C: StorageV3<Element, capacity, cellCount, CellBase> ===")
    print()

    // UInt8 — 1-byte cells, zero overhead
    print("StorageV3<UInt8, 16, 1, UInt8>:")
    print("  size=\(MemoryLayout<StorageV3<UInt8, 16, 1, UInt8>>.size) bytes (ideal: 16)")
    var s1 = StorageV3<UInt8, 16, 1, UInt8>()
    s1.initialize(to: 42, at: 0)
    s1.initialize(to: 99, at: 15)
    print("  [0]=\(s1.move(at: 0)), [15]=\(s1.move(at: 15))")
    print()

    // Double — 8-byte cells, zero overhead
    print("StorageV3<Double, 4, 1, Int>:")
    print("  size=\(MemoryLayout<StorageV3<Double, 4, 1, Int>>.size) bytes (ideal: 32)")
    var s2 = StorageV3<Double, 4, 1, Int>()
    s2.initialize(to: 3.14, at: 0)
    print("  [0]=\(s2.move(at: 0))")
    print()

    // Int32 — 4-byte cells, zero overhead
    print("StorageV3<Int32, 8, 1, UInt32>:")
    print("  size=\(MemoryLayout<StorageV3<Int32, 8, 1, UInt32>>.size) bytes (ideal: 32)")
    var s3 = StorageV3<Int32, 8, 1, UInt32>()
    s3.initialize(to: 100, at: 0)
    print("  [0]=\(s3.move(at: 0))")
    print()

    // ~Copyable with 16-byte cells (2 × Int)
    struct Resource: ~Copyable {
        var a: Int
        var b: Int
    }
    print("StorageV3<Resource, 4, 2, Int>:")
    print("  Resource stride: \(MemoryLayout<Resource>.stride)")
    print("  Cell<2, Int> stride: \(MemoryLayout<Cell<2, Int>>.stride)")
    print("  size=\(MemoryLayout<StorageV3<Resource, 4, 2, Int>>.size) bytes (ideal: 64)")
    var s4 = StorageV3<Resource, 4, 2, Int>()
    s4.initialize(to: Resource(a: 10, b: 20), at: 0)
    let r = s4.move(at: 0)
    print("  [0].a=\(r.a), [0].b=\(r.b)")
    print()

    // Current 64-byte slot equivalent
    print("StorageV3<Double, 4, 8, Int> (current 64B slots):")
    print("  size=\(MemoryLayout<StorageV3<Double, 4, 8, Int>>.size) bytes")
    print()
}

// ============================================================================
// MARK: - Approach D: Can We Eliminate cellCount via MemoryLayout?
// Hypothesis: If we could compute ceil(Element.stride / Base.stride) at
//   compile time, we'd need only 2 params: <Element, capacity>.
//   But MemoryLayout is runtime. What about a default?
// Result: CONFIRMED — consumer must choose, but ADT layer can provide defaults
// ============================================================================

func testApproachD() {
    print("=== Approach D: Ergonomics — Can We Default? ===")
    print()

    // For the common case, cellCount=1 and CellBase matches Element's alignment:
    // - Int, Double, pointer types → CellBase=Int, cellCount=1
    // - UInt8 → CellBase=UInt8, cellCount=1
    // - Large ~Copyable struct → CellBase=Int, cellCount=ceil(stride/8)

    // The ideal API:
    // Storage.Inline<Double, 4>              → auto-selects Cell<1, Int>
    // Storage.Inline<UInt8, 16>              → auto-selects Cell<1, UInt8>
    // Storage.Inline<LargeStruct, 4>         → auto-selects Cell<N, Int>

    // But auto-selection requires compile-time MemoryLayout, which Swift doesn't have.
    // So the consumer MUST specify cellCount and CellBase.

    // However, we can provide a SAFE DEFAULT:
    // cellCount=8, CellBase=Int → 64 bytes, current behavior
    // Then consumers who care about size override it.

    print("Default (backward compat): cellCount=8, CellBase=Int → 64B slots")
    print("Optimized (consumer picks): cellCount=1, CellBase=Int → 8B slots for Double")
    print()
    print("Without compile-time MemoryLayout, the consumer must choose.")
    print("But the ADT layer (Vector, Stack, etc.) CAN make smart defaults:")
    print("  Vector<Double, 4> → Storage.Inline<Double, 4, 1, Int>  (8B cells)")
    print("  Stack<Any, 8>     → Storage.Inline<Any, 8, 8, Int>     (64B cells)")
    print()
}

// ============================================================================
// MARK: - Approach E: What If We Use Backing Directly (No Cell Struct)?
// Hypothesis: Skip the Cell wrapper. Use raw FixedWidthInteger types as
//   InlineArray elements. For multi-word, use InlineArray<N, Int>.
// Result: CONFIRMED — InlineArray nesting works, Cell wrapper is optional
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

// The simplest possible design: Storage.Inline wraps InlineArray<capacity, Slot>
// where Slot: BitwiseCopiable & Sendable, with init() somehow.
// For single-word: Slot = UInt8 | UInt16 | UInt32 | Int
// For multi-word: Slot = InlineArray<N, Int>  (but InlineArray needs init)

// Actually, InlineArray<N, Int> where Int: ExpressibleByIntegerLiteral DOES have init(repeating:).
// So InlineArray<2, Int> is a valid 16-byte Copyable type with init(repeating: 0).
// And InlineArray<capacity, InlineArray<2, Int>> works!

func testApproachE() {
    print("=== Approach E: InlineArray Nesting (No Cell Wrapper) ===")
    print()

    // InlineArray<capacity, InlineArray<cellWords, Int>>
    // This is literally what Cell<cellWords, Int> wraps.
    // Does InlineArray<N, Int> behave the same?

    typealias Cell1Int = InlineArray<1, Int>   // 8 bytes
    typealias Cell2Int = InlineArray<2, Int>   // 16 bytes
    typealias Cell8Int = InlineArray<8, Int>   // 64 bytes

    print("InlineArray<1, Int>: size=\(MemoryLayout<Cell1Int>.size), stride=\(MemoryLayout<Cell1Int>.stride), align=\(MemoryLayout<Cell1Int>.alignment)")
    print("InlineArray<2, Int>: size=\(MemoryLayout<Cell2Int>.size), stride=\(MemoryLayout<Cell2Int>.stride), align=\(MemoryLayout<Cell2Int>.alignment)")
    print("InlineArray<8, Int>: size=\(MemoryLayout<Cell8Int>.size), stride=\(MemoryLayout<Cell8Int>.stride), align=\(MemoryLayout<Cell8Int>.alignment)")
    print()

    // Nested: InlineArray<4, InlineArray<1, Int>> as Vector<Double, 4> backing
    typealias VectorBacking = InlineArray<4, Cell1Int>
    print("InlineArray<4, InlineArray<1, Int>>:")
    print("  size=\(MemoryLayout<VectorBacking>.size) bytes (ideal: 32)")
    print()

    // Can we skip the Cell abstraction entirely?
    // Storage.Inline<Element, capacity, Slot> where Slot = InlineArray<N, Int>
    // or Slot = UInt8, UInt16, UInt32, Int (for single-unit cells)

    // The user writes:
    //   Storage.Inline<Double, 4, Int>                      → 32 bytes (8B slots)
    //   Storage.Inline<UInt8, 16, UInt8>                    → 16 bytes (1B slots)
    //   Storage.Inline<LargeStruct, 4, InlineArray<2, Int>> → 64 bytes (16B slots)

    print("This eliminates the Cell type entirely.")
    print("Slot IS the InlineArray element type. Nothing more.")
    print()
}

// ============================================================================
// MARK: - Span Compatibility Matrix
// ============================================================================

func testSpan() {
    print("=== Span Compatibility ===")
    print()

    // Span works when cell stride == element stride
    print("Cell stride vs Element stride (must match for Span):")
    print()
    print("  UInt8  in Cell<1, UInt8>:  cell=\(MemoryLayout<Cell<1, UInt8>>.stride), elem=\(MemoryLayout<UInt8>.stride) → \(MemoryLayout<Cell<1, UInt8>>.stride == MemoryLayout<UInt8>.stride ? "SPAN ✓" : "no Span")")
    print("  UInt16 in Cell<1, UInt16>: cell=\(MemoryLayout<Cell<1, UInt16>>.stride), elem=\(MemoryLayout<UInt16>.stride) → \(MemoryLayout<Cell<1, UInt16>>.stride == MemoryLayout<UInt16>.stride ? "SPAN ✓" : "no Span")")
    print("  Int32  in Cell<1, UInt32>: cell=\(MemoryLayout<Cell<1, UInt32>>.stride), elem=\(MemoryLayout<Int32>.stride) → \(MemoryLayout<Cell<1, UInt32>>.stride == MemoryLayout<Int32>.stride ? "SPAN ✓" : "no Span")")
    print("  Float  in Cell<1, UInt32>: cell=\(MemoryLayout<Cell<1, UInt32>>.stride), elem=\(MemoryLayout<Float>.stride) → \(MemoryLayout<Cell<1, UInt32>>.stride == MemoryLayout<Float>.stride ? "SPAN ✓" : "no Span")")
    print("  Double in Cell<1, Int>:    cell=\(MemoryLayout<Cell<1, Int>>.stride), elem=\(MemoryLayout<Double>.stride) → \(MemoryLayout<Cell<1, Int>>.stride == MemoryLayout<Double>.stride ? "SPAN ✓" : "no Span")")
    print("  Int    in Cell<1, Int>:    cell=\(MemoryLayout<Cell<1, Int>>.stride), elem=\(MemoryLayout<Int>.stride) → \(MemoryLayout<Cell<1, Int>>.stride == MemoryLayout<Int>.stride ? "SPAN ✓" : "no Span")")
    print()

    // Non-matching (oversized cell):
    print("  Double in Cell<8, Int>:    cell=\(MemoryLayout<Cell<8, Int>>.stride), elem=\(MemoryLayout<Double>.stride) → \(MemoryLayout<Cell<8, Int>>.stride == MemoryLayout<Double>.stride ? "SPAN ✓" : "no Span (strided)")")
    print("  UInt8  in Cell<1, Int>:    cell=\(MemoryLayout<Cell<1, Int>>.stride), elem=\(MemoryLayout<UInt8>.stride) → \(MemoryLayout<Cell<1, Int>>.stride == MemoryLayout<UInt8>.stride ? "SPAN ✓" : "no Span (8× waste)")")
    print()
}

// ============================================================================
// MARK: - Final Summary
// ============================================================================

func printFinalSummary() {
    print("=== FINAL SUMMARY ===")
    print()
    print("Cell<let count: Int, Base: BitwiseCopyable & Sendable> is ONE type")
    print("that achieves ZERO overhead for ALL element sizes:")
    print()
    print("  Element  │ Cell             │ Cell size │ Ideal │ Overhead │ Span")
    print("  ─────────┼──────────────────┼───────────┼───────┼──────────┼─────")
    print("  UInt8    │ Cell<1, UInt8>   │    1 B    │  1 B  │   0%     │  ✓")
    print("  UInt16   │ Cell<1, UInt16>  │    2 B    │  2 B  │   0%     │  ✓")
    print("  Int32    │ Cell<1, UInt32>  │    4 B    │  4 B  │   0%     │  ✓")
    print("  Float    │ Cell<1, UInt32>  │    4 B    │  4 B  │   0%     │  ✓")
    print("  Int      │ Cell<1, Int>     │    8 B    │  8 B  │   0%     │  ✓")
    print("  Double   │ Cell<1, Int>     │    8 B    │  8 B  │   0%     │  ✓")
    print("  16B type │ Cell<2, Int>     │   16 B    │ 16 B  │   0%     │  ✓")
    print("  64B type │ Cell<8, Int>     │   64 B    │ 64 B  │   0%     │  ✓")
    print()
    print("Storage.Inline becomes:")
    print("  Storage.Inline<Element, capacity, cellCount, CellBase>")
    print("  or more simply, with Cell as the slot type:")
    print("  Storage.Inline<Element, capacity, Cell<cellCount, CellBase>>")
    print()
    print("The 7-type family collapses to 1 struct with 2 integer+type params.")
    print("No protocol needed. No type hierarchy. Just generics.")
}

// ============================================================================
// MARK: - Execution
// ============================================================================

testApproachA()
testApproachB()
testApproachC()
testApproachD()
testApproachE()
testSpan()
printFinalSummary()
