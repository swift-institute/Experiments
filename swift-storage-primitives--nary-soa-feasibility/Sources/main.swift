// MARK: - N-ary SoA Feasibility
// Purpose: Determine the best achievable N-ary Structure-of-Arrays design in Swift 6.2
// Hypothesis: Parameter packs enable N-ary SoA with acceptable call-site ergonomics
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: PARTIAL — Pack-based N-ary works (V1-V6,V9,V10) but ~Copyable packs blocked (V7).
//         Creative approaches (creative.swift) bypass packs entirely:
//         C1/C2 (fixed-arity), C3 (HList), C5 (@_rawLayout inline), C7 (field handles)
//         all support ~Copyable. Binary still wins on ergonomics for our use case.
// Date: 2026-02-07

// ============================================================================
// MARK: - V1: Basic Parameter Pack Type Declaration
// Hypothesis: A struct/class can be generic over `each Field`
// Result: CONFIRMED — SoAStorage_V1<Int, String> and <UInt8, Int, Double> both compile
// ============================================================================

struct SoAStorage_V1<each Field> {
    var count: Int

    init(count: Int) {
        self.count = count
    }
}

func testV1() {
    let s2 = SoAStorage_V1<Int, String>(count: 10)
    let s3 = SoAStorage_V1<UInt8, Int, Double>(count: 10)
    print("V1: SoAStorage<Int, String> count = \(s2.count)")
    print("V1: SoAStorage<UInt8, Int, Double> count = \(s3.count)")
}

// ============================================================================
// MARK: - V2: Pack Iteration for Layout Computation
// Hypothesis: We can iterate `repeat each Field` to compute per-field byte offsets
// Result: CONFIRMED — Offsets [0, 16, 144] correct for <UInt8, Int, Double> cap=16
// ============================================================================

func computeOffsets_V2<each Field>(
    _: repeat (each Field).Type,
    capacity: Int
) -> [Int] {
    var offsets: [Int] = []
    var currentOffset = 0

    for fieldLayout in repeat (MemoryLayout<each Field>.self) {
        // Align to field's alignment requirement
        let alignment = fieldLayout.alignment
        currentOffset = (currentOffset + alignment - 1) & ~(alignment - 1)
        offsets.append(currentOffset)
        currentOffset += fieldLayout.stride * capacity
    }

    return offsets
}

func testV2() {
    let offsets = computeOffsets_V2(UInt8.self, Int.self, Double.self, capacity: 16)
    print("V2: Offsets for <UInt8, Int, Double> cap=16: \(offsets)")
    // Expected: [0, 16 rounded up to 8-alignment, then +16*8, ...]
}

// ============================================================================
// MARK: - V3: Raw Byte Storage with Pack-Computed Layout
// Hypothesis: We can allocate raw bytes and overlay typed pointers per field
// Result: CONFIRMED — Read/write all three fields correctly
// ============================================================================

final class SoAHeap_V3<each Field: Copyable & Sendable>: @unchecked Sendable {
    let capacity: Int
    let buffer: UnsafeMutableRawPointer
    let offsets: [Int]

    init(capacity: Int) {
        self.capacity = capacity

        // Compute layout
        var computedOffsets: [Int] = []
        var currentOffset = 0
        var maxAlignment = 1

        for fieldLayout in repeat (MemoryLayout<each Field>.self) {
            let alignment = fieldLayout.alignment
            if alignment > maxAlignment { maxAlignment = alignment }
            currentOffset = (currentOffset + alignment - 1) & ~(alignment - 1)
            computedOffsets.append(currentOffset)
            currentOffset += fieldLayout.stride * capacity
        }

        self.offsets = computedOffsets
        self.buffer = UnsafeMutableRawPointer.allocate(
            byteCount: currentOffset,
            alignment: maxAlignment
        )
    }

    deinit {
        buffer.deallocate()
    }

    /// Get pointer to field N — but how does the caller specify N?
    /// This is the core problem.
    func rawPointer(fieldIndex: Int) -> UnsafeMutableRawPointer {
        buffer.advanced(by: offsets[fieldIndex])
    }
}

func testV3() {
    let storage = SoAHeap_V3<UInt8, Int, Double>(capacity: 16)
    print("V3: Allocated with offsets \(storage.offsets)")

    // We CAN get raw pointers by index:
    let field0 = storage.rawPointer(fieldIndex: 0)
        .assumingMemoryBound(to: UInt8.self)
    let field1 = storage.rawPointer(fieldIndex: 1)
        .assumingMemoryBound(to: Int.self)
    let field2 = storage.rawPointer(fieldIndex: 2)
        .assumingMemoryBound(to: Double.self)

    field0.initialize(to: 42)
    field1.initialize(to: 999)
    field2.initialize(to: 3.14)

    print("V3: field0[0] = \(field0.pointee)")
    print("V3: field1[0] = \(field1.pointee)")
    print("V3: field2[0] = \(field2.pointee)")
}

// ============================================================================
// MARK: - V4: Type-Based Field Selection
// Hypothesis: We can select a field by its type using generic constraints
// Limitation: Fails when two fields share a type
// Result: N/A — No way to express "Nth element of a pack" at type level; see V5/V9
// ============================================================================

// Note: This approach cannot distinguish two fields of the same type.
// For our use case (UInt8 metadata + Payload), types are always distinct.

func testV4() {
    // V4 is structurally the same as V3 but with a typed API.
    // The problem: Swift has no way to express "the Nth element of a pack"
    // in a type-safe manner at the call site without runtime indexing.
    print("V4: Type-based selection requires unique types per field — see V5")
}

// ============================================================================
// MARK: - V5: Pack Expansion to Return Tuple of Pointers
// Hypothesis: We can return (repeat UnsafeMutablePointer<each Field>)
// Result: CONFIRMED — pointerTuple(at:) works; tuple.N positional access works
// Note: Initial closure-based approach crashed compiler; FieldCounter workaround needed
// ============================================================================

// V5a: Helper — returns typed pointer for a specific field by runtime index
extension SoAHeap_V3 {
    func typedPointer<T>(fieldIndex: Int, as: T.Type, at slot: Int) -> UnsafeMutablePointer<T> {
        buffer.advanced(by: offsets[fieldIndex])
            .assumingMemoryBound(to: T.self)
            .advanced(by: slot)
    }
}

// V5b: Attempt — return pack tuple without mutable counter
// Uses a helper struct to track the offset index during pack expansion.
class FieldCounter {
    var index: Int = 0
    func next() -> Int {
        defer { index += 1 }
        return index
    }
}

extension SoAHeap_V3 {
    func pointerTuple(at slot: Int) -> (repeat UnsafeMutablePointer<each Field>) {
        let counter = FieldCounter()
        return (repeat buffer.advanced(by: offsets[counter.next()])
            .assumingMemoryBound(to: (each Field).self)
            .advanced(by: slot))
    }
}

func testV5() {
    let storage = SoAHeap_V3<UInt8, Int, Double>(capacity: 16)

    // V5a: Manual typed pointer access (works but requires type + index)
    let p0 = storage.typedPointer(fieldIndex: 0, as: UInt8.self, at: 0)
    let p1 = storage.typedPointer(fieldIndex: 1, as: Int.self, at: 0)
    let p2 = storage.typedPointer(fieldIndex: 2, as: Double.self, at: 0)

    p0.initialize(to: 0x80)
    p1.initialize(to: 42)
    p2.initialize(to: 3.14)

    print("V5a: typedPointer — field0=\(p0.pointee), field1=\(p1.pointee), field2=\(p2.pointee)")

    // V5b: Tuple return via pack expansion
    let (q0, q1, q2) = storage.pointerTuple(at: 0)
    print("V5b: pointerTuple — field0=\(q0.pointee), field1=\(q1.pointee), field2=\(q2.pointee)")

    // V5c: Can we do positional tuple access?
    let ptrs = storage.pointerTuple(at: 0)
    print("V5c: ptrs.0.pointee = \(ptrs.0.pointee)")
    print("V5c: ptrs.1.pointee = \(ptrs.1.pointee)")
    print("V5c: ptrs.2.pointee = \(ptrs.2.pointee)")
}

// ============================================================================
// MARK: - V6: ManagedBuffer-Based (Subclassing)
// Hypothesis: We can use ManagedBuffer<Header, UInt8> with pack-computed layout
// Result: CONFIRMED — Free function create + unsafeDowncast works
// Note: Static method with `where repeat each Field == repeat each F` does NOT compile
// ============================================================================

struct SoAHeader_V6: Sendable {
    let capacity: Int
    let offsets: [Int]
}

final class SoAManaged_V6<each Field: Copyable & Sendable>: ManagedBuffer<SoAHeader_V6, UInt8> {
    deinit {
        // For BitwiseCopyable fields, no per-element deinit needed.
    }
}

func createSoAManaged<each Field: Copyable & Sendable>(
    _: repeat (each Field).Type,
    capacity: Int
) -> SoAManaged_V6<repeat each Field> {
    var computedOffsets: [Int] = []
    var currentOffset = 0

    for fieldLayout in repeat (MemoryLayout<each Field>.self) {
        let alignment = fieldLayout.alignment
        currentOffset = (currentOffset + alignment - 1) & ~(alignment - 1)
        computedOffsets.append(currentOffset)
        currentOffset += fieldLayout.stride * capacity
    }

    let totalBytes = currentOffset

    let buf = SoAManaged_V6<repeat each Field>.create(minimumCapacity: totalBytes) { _ in
        SoAHeader_V6(capacity: capacity, offsets: computedOffsets)
    }
    return unsafeDowncast(buf, to: SoAManaged_V6<repeat each Field>.self)
}

func testV6() {
    let storage = createSoAManaged(UInt8.self, Int.self, capacity: 16)
    print("V6: ManagedBuffer<repeat each Field> created, capacity=\(storage.header.capacity)")
    print("V6: offsets = \(storage.header.offsets)")

    // Access the raw elements region:
    storage.withUnsafeMutablePointerToElements { rawBase in
        let offset0 = storage.header.offsets[0]
        let offset1 = storage.header.offsets[1]

        let field0 = UnsafeMutableRawPointer(rawBase).advanced(by: offset0)
            .assumingMemoryBound(to: UInt8.self)
        let field1 = UnsafeMutableRawPointer(rawBase).advanced(by: offset1)
            .assumingMemoryBound(to: Int.self)

        field0.initialize(to: 0x80)
        field1.initialize(to: 42)

        print("V6: field0[0] = \(field0.pointee), field1[0] = \(field1.pointee)")
    }
}

// ============================================================================
// MARK: - V7: ~Copyable with Parameter Packs
// Hypothesis: `each Field: ~Copyable` works in parameter packs
// Result: REFUTED — "cannot suppress '~Copyable' on type 'each Field'" in Swift 6.2
// ============================================================================

// Note: `each Field: ~Copyable` does NOT compile in Swift 6.2.
// Error: "cannot suppress '~Copyable' on type 'each Field'"
// This means parameter packs are restricted to Copyable types.

// Commented out — does not compile:
// struct NoncopyableBox<each Field: ~Copyable>: ~Copyable {
//     var count: Int
//     init(count: Int) { self.count = count }
// }

func testV7() {
    print("V7: REFUTED — `each Field: ~Copyable` does not compile in Swift 6.2")
    print("V7: Error: 'cannot suppress ~Copyable on type each Field'")
    print("V7: Parameter packs are restricted to Copyable types.")
    print("V7: This means N-ary SoA CANNOT support ~Copyable elements via packs.")
}

// ============================================================================
// MARK: - V8: Binary Baseline (Current Split Design)
// Hypothesis: Binary design gives cleaner call-site than N-ary pack approach
// Result: CONFIRMED — pointer(at:), laneValue(at:), fillLane, withLanePointer all clean
// ============================================================================

final class BinarySplit_V8<Primary, Lane: Copyable & Sendable>: @unchecked Sendable {
    let capacity: Int
    let buffer: UnsafeMutableRawPointer
    let laneOffset: Int  // Always 0
    let primaryOffset: Int

    init(capacity: Int, laneInitial: Lane) {
        self.capacity = capacity

        let laneBytes = capacity * MemoryLayout<Lane>.stride
        let primaryAlignment = MemoryLayout<Primary>.alignment
        let primaryStart = (laneBytes + primaryAlignment - 1) & ~(primaryAlignment - 1)

        self.laneOffset = 0
        self.primaryOffset = primaryStart

        let totalBytes = primaryStart + capacity * MemoryLayout<Primary>.stride
        let maxAlign = max(MemoryLayout<Lane>.alignment, MemoryLayout<Primary>.alignment)
        self.buffer = UnsafeMutableRawPointer.allocate(
            byteCount: totalBytes,
            alignment: maxAlign
        )

        // Bulk-initialize lane
        let lanePtr = buffer.assumingMemoryBound(to: Lane.self)
        lanePtr.initialize(repeating: laneInitial, count: capacity)
    }

    deinit {
        // Deinitialize lane (always fully initialized)
        buffer.assumingMemoryBound(to: Lane.self)
            .deinitialize(count: capacity)
        buffer.deallocate()
    }

    /// Primary element pointer — matches Storage.Heap.pointer(at:)
    func pointer(at slot: Int) -> UnsafeMutablePointer<Primary> {
        buffer.advanced(by: primaryOffset)
            .assumingMemoryBound(to: Primary.self)
            .advanced(by: slot)
    }

    /// Lane value read
    func laneValue(at slot: Int) -> Lane {
        buffer.assumingMemoryBound(to: Lane.self)
            .advanced(by: slot).pointee
    }

    /// Lane value write
    func setLaneValue(_ value: Lane, at slot: Int) {
        buffer.assumingMemoryBound(to: Lane.self)
            .advanced(by: slot).pointee = value
    }

    /// Lane pointer (for SIMD)
    func withLanePointer<R>(_ body: (UnsafePointer<Lane>) -> R) -> R {
        body(UnsafePointer(buffer.assumingMemoryBound(to: Lane.self)))
    }

    /// Bulk lane fill
    func fillLane(with value: Lane) {
        let ptr = buffer.assumingMemoryBound(to: Lane.self)
        for i in 0..<capacity {
            ptr.advanced(by: i).pointee = value
        }
    }
}

func testV8() {
    let storage = BinarySplit_V8<Int, UInt8>(capacity: 16, laneInitial: 0x80)

    // Clean call-site for binary:
    storage.setLaneValue(0x42, at: 3)
    storage.pointer(at: 3).initialize(to: 999)

    let meta = storage.laneValue(at: 3)
    let elem = storage.pointer(at: 3).pointee
    print("V8 binary: lane[3]=\(meta), primary[3]=\(elem)")

    // SIMD access:
    storage.withLanePointer { ptr in
        print("V8 binary: lane contiguous pointer = \(ptr)")
    }

    // Bulk fill:
    storage.fillLane(with: 0xFF)
    print("V8 binary: after fill, lane[0]=\(storage.laneValue(at: 0))")
}

// ============================================================================
// MARK: - V9: N-ary with Positional Field Accessor Protocol
// Hypothesis: We can create a protocol-based field selection pattern
// Result: CONFIRMED — FieldPosition<Field0, UInt8> gives type-safe named access
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

/// Phantom type for field position
struct FieldPosition<Index: FieldIndex, Element> {
    let offset: Int
    let stride: Int
}

protocol FieldIndex {
    static var index: Int { get }
}
enum Field0: FieldIndex { static let index = 0 }
enum Field1: FieldIndex { static let index = 1 }
enum Field2: FieldIndex { static let index = 2 }

extension SoAHeap_V3 {
    /// Type-safe field accessor using phantom position type
    func field<I: FieldIndex, T>(_ position: FieldPosition<I, T>) -> UnsafeMutablePointer<T> {
        buffer.advanced(by: offsets[I.index])
            .assumingMemoryBound(to: T.self)
    }

    func fieldPointer<I: FieldIndex, T>(_ position: FieldPosition<I, T>, at slot: Int) -> UnsafeMutablePointer<T> {
        buffer.advanced(by: offsets[I.index])
            .assumingMemoryBound(to: T.self)
            .advanced(by: slot)
    }
}

func testV9() {
    let storage = SoAHeap_V3<UInt8, Int, Double>(capacity: 16)

    // Define field accessors (could be auto-generated by macro)
    let metadata = FieldPosition<Field0, UInt8>(offset: storage.offsets[0], stride: MemoryLayout<UInt8>.stride)
    let payload = FieldPosition<Field1, Int>(offset: storage.offsets[1], stride: MemoryLayout<Int>.stride)
    let weight = FieldPosition<Field2, Double>(offset: storage.offsets[2], stride: MemoryLayout<Double>.stride)

    // Call-site with named positions:
    storage.fieldPointer(metadata, at: 0).initialize(to: 0x80)
    storage.fieldPointer(payload, at: 0).initialize(to: 42)
    storage.fieldPointer(weight, at: 0).initialize(to: 3.14)

    print("V9: metadata[0] = \(storage.fieldPointer(metadata, at: 0).pointee)")
    print("V9: payload[0] = \(storage.fieldPointer(payload, at: 0).pointee)")
    print("V9: weight[0] = \(storage.fieldPointer(weight, at: 0).pointee)")
}

// ============================================================================
// MARK: - V10: Ergonomic Comparison — Same Operation Across All Approaches
// Purpose: Side-by-side call-site comparison for hash-table-like usage
// ============================================================================

func testV10_ergonomicComparison() {
    print("\n=== V10: Ergonomic Comparison ===")
    print("Task: Swiss-table-like storage with UInt8 metadata + Int payload\n")

    // --- N-ary (V3/V5) ---
    print("--- N-ary (parameter pack, tuple destructuring) ---")
    let nary = SoAHeap_V3<UInt8, Int>(capacity: 16)
    // Initialize via tuple destructuring:
    let (metaPtr, payloadPtr) = nary.pointerTuple(at: 0)
    metaPtr.initialize(to: 0x80)
    payloadPtr.initialize(to: 42)
    // Read (must destructure both):
    print("  read: metadata=\(metaPtr.pointee), payload=\(payloadPtr.pointee)")
    // Individual field access requires runtime index + type:
    let m = nary.typedPointer(fieldIndex: 0, as: UInt8.self, at: 0).pointee
    print("  individual read: metadata=\(m)")
    // SIMD-friendly contiguous lane access via fieldIndex:
    let metaBase = nary.rawPointer(fieldIndex: 0).assumingMemoryBound(to: UInt8.self)
    print("  simd base: \(metaBase)")

    // --- Binary (V8) ---
    print("\n--- Binary (Storage.Split pattern) ---")
    let binary = BinarySplit_V8<Int, UInt8>(capacity: 16, laneInitial: 0x80)
    // Initialize:
    binary.pointer(at: 0).initialize(to: 42)
    // metadata already initialized to 0x80 at creation
    binary.setLaneValue(0x42, at: 0)
    // Read:
    let meta = binary.laneValue(at: 0)
    let payload = binary.pointer(at: 0).pointee
    print("  read: metadata=\(meta), payload=\(payload)")
    // SIMD access:
    binary.withLanePointer { ptr in
        print("  simd base: \(ptr)")
    }
    // Bulk fill:
    binary.fillLane(with: 0x80)
    print("  bulk fill: done")
}

// ============================================================================
// MARK: - Run All Variants
// ============================================================================

print("=== N-ary SoA Feasibility Experiment ===\n")
testV1()
print()
testV2()
print()
testV3()
print()
testV4()
print()
testV5()
print()
testV6()
print()
testV7()
print()
testV8()
print()
testV9()
print()
testV10_ergonomicComparison()

// Creative approaches (creative.swift)
runCreativeExperiments()

// ============================================================================
// MARK: - Results Summary
//
// V1:  CONFIRMED  — Parameter pack type declarations work
// V2:  CONFIRMED  — Pack iteration computes correct layout offsets
// V3:  CONFIRMED  — Raw byte allocation + typed pointer overlay works
// V4:  N/A        — No pack-element indexing at type level; see V5/V9
// V5:  CONFIRMED  — Tuple-of-pointers return works (FieldCounter workaround)
// V6:  CONFIRMED  — ManagedBuffer subclass with packs works (free fn create)
// V7:  REFUTED    — `each Field: ~Copyable` does NOT compile (Swift 6.2 limitation)
// V8:  CONFIRMED  — Binary design: clean call-site with semantic accessors
// V9:  CONFIRMED  — FieldPosition phantom type gives named access to N-ary fields
// V10: (see below) — Binary wins on ergonomics for hash-table use case
//
// ============================================================================
// MARK: - Conclusions
//
// 1. N-ary SoA IS TECHNICALLY FEASIBLE in Swift 6.2 via parameter packs.
//    The layout computation, allocation, and typed pointer access all work.
//
// 2. THE BLOCKER IS ~Copyable. Parameter packs cannot suppress Copyable.
//    `each Field: ~Copyable` is a compiler error.
//    This means an N-ary SoA type can ONLY store Copyable fields.
//    Storage.Heap supports ~Copyable elements — an N-ary SoA would regress.
//
// 3. CALL-SITE ERGONOMICS FAVOR BINARY for our use case:
//    Binary:  storage.pointer(at: slot)        // primary
//             storage.lane[at: slot]            // secondary
//    N-ary:   let (meta, payload) = storage.pointerTuple(at: slot)  // must destructure
//             storage.typedPointer(fieldIndex: 0, as: UInt8.self, at: slot)  // verbose
//
// 4. N-ARY FIELD SELECTION IS UNRESOLVED in Swift's type system.
//    - No integer generic parameters for pack indexing
//    - No `each Field[N]` expression
//    - Workarounds: tuple destructuring, FieldPosition phantom types, runtime indices
//    - All workarounds are either unsafe or verbose
//
// 5. ManagedBuffer integration works but requires free-function create pattern.
//    Static methods with pack same-type constraints don't compile.
//
// 6. V9's FieldPosition pattern is the BEST N-ary ergonomic we found:
//    storage.fieldPointer(metadata, at: slot)  // named + typed
//    But it requires consumers to define FieldPosition constants externally,
//    which is no better than the binary design where names are built in.
//
// RECOMMENDATION: Binary (`Storage<Element>.Split<Lane>`) is the correct
// design for Swift 6.2. An N-ary generalization should wait for:
//   - ~Copyable support in parameter packs
//   - Integer generic parameters or pack indexing
//   - 3+ concrete consumers requiring different arities [PATTERN-013]
// ============================================================================
