// MARK: - Creative N-ary SoA Approaches
// Purpose: Explore non-parameter-pack paths to N-ary + ~Copyable SoA
// Hypothesis: Alternative type-level encoding can bypass the pack ~Copyable limitation
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Multiple viable paths exist (see Results Summary below)
// Date: 2026-02-07
//
// Results Summary:
// C1: CONFIRMED — Fixed-arity classes with ~Copyable phantom generics. Full ~Copyable support.
// C2: CONFIRMED — ManagedBuffer subclass with ~Copyable phantoms. Full ~Copyable support.
// C3: CONFIRMED — HList type-level encoding. ~Copyable layout works; typed accessors Copyable-only.
// C4: CONFIRMED — Protocol schema pattern. Same trade-off as C3.
// C5: CONFIRMED — Inline SoA via @_rawLayout composition. True inline, ~Copyable, correct sizing.
// C6: PARTIAL  — FieldDescriptor<T: ~Copyable> IS Copyable, but packs still need each F: Copyable.
// C7: CONFIRMED — SoAField handles with phantom Record type. Subscript for Copyable, pointer for ~Copyable.
// C8: CONFIRMED — Dynamic builder. Fully type-erased, ~Copyable via addField<T: ~Copyable>().

// ============================================================================
// MARK: - C1: Fixed-Arity with ~Copyable (SoA2, SoA3)
// Hypothesis: Classes with ~Copyable phantom generics work
// This is the Rust soa-vec approach (Soa2, Soa3, ..., Soa8)
// Result: CONFIRMED — SoA2<UInt8,Resource>, SoA2<Resource,Token>, SoA3<UInt8,Int,Double> all work
// ============================================================================

final class SoA2_C1<A: ~Copyable, B: ~Copyable>: @unchecked Sendable {
    let capacity: Int
    let buffer: UnsafeMutableRawPointer
    let offsetA: Int
    let offsetB: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.offsetA = 0
        let bStart = (capacity * MemoryLayout<A>.stride + MemoryLayout<B>.alignment - 1)
            & ~(MemoryLayout<B>.alignment - 1)
        self.offsetB = bStart
        let total = bStart + capacity * MemoryLayout<B>.stride
        self.buffer = .allocate(
            byteCount: max(total, 1),
            alignment: max(MemoryLayout<A>.alignment, MemoryLayout<B>.alignment)
        )
    }

    deinit { buffer.deallocate() }

    func pointerA(at slot: Int) -> UnsafeMutablePointer<A> {
        buffer.advanced(by: offsetA + slot * MemoryLayout<A>.stride)
            .assumingMemoryBound(to: A.self)
    }

    func pointerB(at slot: Int) -> UnsafeMutablePointer<B> {
        buffer.advanced(by: offsetB + slot * MemoryLayout<B>.stride)
            .assumingMemoryBound(to: B.self)
    }
}

final class SoA3_C1<A: ~Copyable, B: ~Copyable, C: ~Copyable>: @unchecked Sendable {
    let capacity: Int
    let buffer: UnsafeMutableRawPointer
    let offsetA: Int
    let offsetB: Int
    let offsetC: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.offsetA = 0
        let bStart = (capacity * MemoryLayout<A>.stride + MemoryLayout<B>.alignment - 1)
            & ~(MemoryLayout<B>.alignment - 1)
        self.offsetB = bStart
        let cStart = (bStart + capacity * MemoryLayout<B>.stride + MemoryLayout<C>.alignment - 1)
            & ~(MemoryLayout<C>.alignment - 1)
        self.offsetC = cStart
        let total = cStart + capacity * MemoryLayout<C>.stride
        self.buffer = .allocate(
            byteCount: max(total, 1),
            alignment: max(MemoryLayout<A>.alignment, max(MemoryLayout<B>.alignment, MemoryLayout<C>.alignment))
        )
    }

    deinit { buffer.deallocate() }

    func pointerA(at slot: Int) -> UnsafeMutablePointer<A> {
        buffer.advanced(by: offsetA + slot * MemoryLayout<A>.stride)
            .assumingMemoryBound(to: A.self)
    }
    func pointerB(at slot: Int) -> UnsafeMutablePointer<B> {
        buffer.advanced(by: offsetB + slot * MemoryLayout<B>.stride)
            .assumingMemoryBound(to: B.self)
    }
    func pointerC(at slot: Int) -> UnsafeMutablePointer<C> {
        buffer.advanced(by: offsetC + slot * MemoryLayout<C>.stride)
            .assumingMemoryBound(to: C.self)
    }
}

func testC1() {
    print("=== C1: Fixed-arity with ~Copyable ===")

    // 2-field with Copyable types
    let s2 = SoA2_C1<UInt8, Int>(capacity: 16)
    s2.pointerA(at: 0).initialize(to: 0x80)
    s2.pointerB(at: 0).initialize(to: 42)
    print("C1 SoA2<UInt8, Int>: A[0]=\(s2.pointerA(at: 0).pointee), B[0]=\(s2.pointerB(at: 0).pointee)")

    // 3-field
    let s3 = SoA3_C1<UInt8, Int, Double>(capacity: 8)
    s3.pointerA(at: 0).initialize(to: 0xFF)
    s3.pointerB(at: 0).initialize(to: 999)
    s3.pointerC(at: 0).initialize(to: 3.14)
    print("C1 SoA3<UInt8, Int, Double>: A=\(s3.pointerA(at: 0).pointee), B=\(s3.pointerB(at: 0).pointee), C=\(s3.pointerC(at: 0).pointee)")

    // Key test: ~Copyable element
    struct Resource: ~Copyable {
        var id: Int
        var name: String
    }

    let s2nc = SoA2_C1<UInt8, Resource>(capacity: 4)
    s2nc.pointerA(at: 0).initialize(to: 0x42)
    s2nc.pointerB(at: 0).initialize(to: Resource(id: 1, name: "hello"))
    print("C1 SoA2<UInt8, Resource>: A[0]=\(s2nc.pointerA(at: 0).pointee), B[0].id=\(s2nc.pointerB(at: 0).pointee.id)")
    s2nc.pointerB(at: 0).deinitialize(count: 1)

    // ALL ~Copyable
    struct Token: ~Copyable { var value: Int }
    let s2nn = SoA2_C1<Resource, Token>(capacity: 4)
    s2nn.pointerA(at: 0).initialize(to: Resource(id: 7, name: "world"))
    s2nn.pointerB(at: 0).initialize(to: Token(value: 99))
    print("C1 SoA2<Resource, Token>: A[0].id=\(s2nn.pointerA(at: 0).pointee.id), B[0].value=\(s2nn.pointerB(at: 0).pointee.value)")
    s2nn.pointerA(at: 0).deinitialize(count: 1)
    s2nn.pointerB(at: 0).deinitialize(count: 1)
}

// ============================================================================
// MARK: - C2: ManagedBuffer with ~Copyable Phantom Generics
// Hypothesis: ManagedBuffer<Header, UInt8> subclass can have ~Copyable phantom generics
// Result: CONFIRMED — SoAManaged_C2<UInt8, Resource>: ManagedBuffer works with ~Copyable
// ============================================================================

struct SoAHeader_C2: Sendable {
    let capacity: Int
    let offsetB: Int
}

final class SoAManaged_C2<A: ~Copyable, B: ~Copyable>: ManagedBuffer<SoAHeader_C2, UInt8> {
    deinit {}
}

func createSoAManaged_C2<A: ~Copyable, B: ~Copyable>(
    _: A.Type, _: B.Type,
    capacity: Int
) -> SoAManaged_C2<A, B> {
    let bStart = (capacity * MemoryLayout<A>.stride + MemoryLayout<B>.alignment - 1)
        & ~(MemoryLayout<B>.alignment - 1)
    let totalBytes = bStart + capacity * MemoryLayout<B>.stride

    let buf = SoAManaged_C2<A, B>.create(minimumCapacity: max(totalBytes, 1)) { _ in
        SoAHeader_C2(capacity: capacity, offsetB: bStart)
    }
    return unsafeDowncast(buf, to: SoAManaged_C2<A, B>.self)
}

// ~Copyable constraint propagation: explicit suppression needed on extensions
extension SoAManaged_C2 where A: ~Copyable, B: ~Copyable {
    func pointerA(at slot: Int) -> UnsafeMutablePointer<A> {
        withUnsafeMutablePointerToElements { base in
            UnsafeMutableRawPointer(base)
                .advanced(by: slot * MemoryLayout<A>.stride)
                .assumingMemoryBound(to: A.self)
        }
    }

    func pointerB(at slot: Int) -> UnsafeMutablePointer<B> {
        withUnsafeMutablePointerToElements { base in
            UnsafeMutableRawPointer(base)
                .advanced(by: header.offsetB + slot * MemoryLayout<B>.stride)
                .assumingMemoryBound(to: B.self)
        }
    }
}

func testC2() {
    print("\n=== C2: ManagedBuffer + ~Copyable phantom generics ===")

    struct Resource: ~Copyable { var id: Int }

    let storage = createSoAManaged_C2(UInt8.self, Resource.self, capacity: 8)
    print("C2: created, capacity=\(storage.header.capacity), offsetB=\(storage.header.offsetB)")

    storage.pointerA(at: 0).initialize(to: 0x80)
    storage.pointerB(at: 0).initialize(to: Resource(id: 42))
    print("C2: A[0]=\(storage.pointerA(at: 0).pointee), B[0].id=\(storage.pointerB(at: 0).pointee.id)")
    storage.pointerB(at: 0).deinitialize(count: 1)
}

// ============================================================================
// MARK: - C3: Recursive Type-Level List (HList)
// Hypothesis: Type-level Cons/Nil encodes N fields; layout computed via protocol witness
// Result: CONFIRMED — Encodes ~Copyable fields in type structure, correct layout.
//         Typed accessors limited to Copyable fields; ~Copyable uses pointer(field:as:at:)
// ============================================================================

enum Nil_C3 {}
// Cons with ~Copyable Head AND Tail — both can be noncopyable
enum Cons_C3<Head: ~Copyable, Tail: ~Copyable> {}

protocol FieldList: ~Copyable {
    static var layouts: [(stride: Int, alignment: Int)] { get }
    static var fieldCount: Int { get }
}

extension Nil_C3: FieldList {
    static var layouts: [(stride: Int, alignment: Int)] { [] }
    static var fieldCount: Int { 0 }
}

extension Cons_C3: FieldList where Head: ~Copyable, Tail: FieldList & ~Copyable {
    static var layouts: [(stride: Int, alignment: Int)] {
        [(stride: MemoryLayout<Head>.stride, alignment: MemoryLayout<Head>.alignment)] + Tail.layouts
    }
    static var fieldCount: Int { 1 + Tail.fieldCount }
}

final class SoAHList_C3<Fields: FieldList & ~Copyable>: @unchecked Sendable {
    let capacity: Int
    let buffer: UnsafeMutableRawPointer
    let offsets: [Int]

    init(capacity: Int) {
        self.capacity = capacity
        var computedOffsets: [Int] = []
        var currentOffset = 0
        var maxAlign = 1
        for layout in Fields.layouts {
            if layout.alignment > maxAlign { maxAlign = layout.alignment }
            currentOffset = (currentOffset + layout.alignment - 1) & ~(layout.alignment - 1)
            computedOffsets.append(currentOffset)
            currentOffset += layout.stride * capacity
        }
        self.offsets = computedOffsets
        self.buffer = .allocate(byteCount: max(currentOffset, 1), alignment: maxAlign)
    }

    deinit { buffer.deallocate() }

    /// Runtime-indexed, caller-typed field access (~Copyable safe)
    func pointer<T: ~Copyable>(field: Int, as type: T.Type, at slot: Int) -> UnsafeMutablePointer<T> {
        buffer.advanced(by: offsets[field] + slot * MemoryLayout<T>.stride)
            .assumingMemoryBound(to: T.self)
    }
}

// Typed accessors: Head/A/B/C remain Copyable (typed pointer return).
// Tail is ~Copyable so lists containing ~Copyable fields still match.
// ~Copyable fields use the runtime-indexed pointer(field:as:at:) method.
extension SoAHList_C3 where Fields: ~Copyable {
    func first<Head, Tail: FieldList & ~Copyable>(
        at slot: Int
    ) -> UnsafeMutablePointer<Head> where Fields == Cons_C3<Head, Tail> {
        buffer.advanced(by: offsets[0] + slot * MemoryLayout<Head>.stride)
            .assumingMemoryBound(to: Head.self)
    }

    func second<A, B, Tail: FieldList & ~Copyable>(
        at slot: Int
    ) -> UnsafeMutablePointer<B> where Fields == Cons_C3<A, Cons_C3<B, Tail>> {
        buffer.advanced(by: offsets[1] + slot * MemoryLayout<B>.stride)
            .assumingMemoryBound(to: B.self)
    }

    func third<A, B, C, Tail: FieldList & ~Copyable>(
        at slot: Int
    ) -> UnsafeMutablePointer<C> where Fields == Cons_C3<A, Cons_C3<B, Cons_C3<C, Tail>>> {
        buffer.advanced(by: offsets[2] + slot * MemoryLayout<C>.stride)
            .assumingMemoryBound(to: C.self)
    }
}

typealias Fields2<A: ~Copyable, B: ~Copyable> = Cons_C3<A, Cons_C3<B, Nil_C3>>
typealias Fields3<A: ~Copyable, B: ~Copyable, C: ~Copyable> = Cons_C3<A, Cons_C3<B, Cons_C3<C, Nil_C3>>>

func testC3() {
    print("\n=== C3: Recursive HList ===")

    // Test with Copyable types first (typed accessors require Copyable due to constraint)
    let s3: SoAHList_C3<Fields3<UInt8, Int, Double>> = SoAHList_C3(capacity: 4)
    print("C3: 3-field offsets=\(s3.offsets), count=\(Fields3<UInt8, Int, Double>.fieldCount)")
    s3.first(at: 0).initialize(to: 0xFF as UInt8)
    s3.second(at: 0).initialize(to: 999 as Int)
    s3.third(at: 0).initialize(to: 3.14)
    print("C3: first=\(s3.first(at: 0).pointee), second=\(s3.second(at: 0).pointee), third=\(s3.third(at: 0).pointee)")

    // ~Copyable via runtime-indexed access (typed accessors limited to Copyable)
    struct Resource: ~Copyable { var id: Int }
    let s2: SoAHList_C3<Fields2<UInt8, Resource>> = SoAHList_C3(capacity: 8)
    print("C3: 2-field offsets=\(s2.offsets)")
    // Use runtime-typed access for ~Copyable field:
    s2.pointer(field: 0, as: UInt8.self, at: 0).initialize(to: 0x80)
    s2.pointer(field: 1, as: Resource.self, at: 0).initialize(to: Resource(id: 42))
    print("C3: field0=\(s2.pointer(field: 0, as: UInt8.self, at: 0).pointee), field1.id=\(s2.pointer(field: 1, as: Resource.self, at: 0).pointee.id)")
    s2.pointer(field: 1, as: Resource.self, at: 0).deinitialize(count: 1)

    // KEY FINDING: The HList ENCODES ~Copyable types in its type-level structure
    // (Fields2<UInt8, Resource> compiles and gives correct MemoryLayout)
    // but typed ACCESSORS for ~Copyable fields require runtime-indexed access
    // because Swift can't propagate ~Copyable through same-type constraints on methods.
}

// ============================================================================
// MARK: - C4: Protocol Schema with ~Copyable Phantom Generics
// Hypothesis: Struct<A: ~Copyable, B: ~Copyable> as schema, SoA generic over schema
// Result: CONFIRMED — Schema2/Schema3 work. Same typed/runtime accessor split as C3.
// ============================================================================

protocol SoASchema: ~Copyable {
    static var fieldCount: Int { get }
    static func offsets(capacity: Int) -> [Int]
    static func totalBytes(capacity: Int) -> Int
    static var maxAlignment: Int { get }
}

struct Schema2<A: ~Copyable, B: ~Copyable>: SoASchema {
    static var fieldCount: Int { 2 }
    static var maxAlignment: Int {
        max(MemoryLayout<A>.alignment, MemoryLayout<B>.alignment)
    }
    static func offsets(capacity: Int) -> [Int] {
        let offsetB = (capacity * MemoryLayout<A>.stride + MemoryLayout<B>.alignment - 1)
            & ~(MemoryLayout<B>.alignment - 1)
        return [0, offsetB]
    }
    static func totalBytes(capacity: Int) -> Int {
        offsets(capacity: capacity)[1] + capacity * MemoryLayout<B>.stride
    }
}

struct Schema3<A: ~Copyable, B: ~Copyable, C: ~Copyable>: SoASchema {
    static var fieldCount: Int { 3 }
    static var maxAlignment: Int {
        max(MemoryLayout<A>.alignment, max(MemoryLayout<B>.alignment, MemoryLayout<C>.alignment))
    }
    static func offsets(capacity: Int) -> [Int] {
        let oB = (capacity * MemoryLayout<A>.stride + MemoryLayout<B>.alignment - 1) & ~(MemoryLayout<B>.alignment - 1)
        let oC = (oB + capacity * MemoryLayout<B>.stride + MemoryLayout<C>.alignment - 1) & ~(MemoryLayout<C>.alignment - 1)
        return [0, oB, oC]
    }
    static func totalBytes(capacity: Int) -> Int {
        let offs = offsets(capacity: capacity)
        return offs[2] + capacity * MemoryLayout<C>.stride
    }
}

final class SoASchema_C4<S: SoASchema & ~Copyable>: @unchecked Sendable {
    let capacity: Int
    let buffer: UnsafeMutableRawPointer
    let fieldOffsets: [Int]

    init(capacity: Int) {
        self.capacity = capacity
        self.fieldOffsets = S.offsets(capacity: capacity)
        self.buffer = .allocate(byteCount: max(S.totalBytes(capacity: capacity), 1), alignment: S.maxAlignment)
    }

    deinit { buffer.deallocate() }

    func pointer<T: ~Copyable>(field: Int, as: T.Type, at slot: Int) -> UnsafeMutablePointer<T> {
        buffer.advanced(by: fieldOffsets[field] + slot * MemoryLayout<T>.stride)
            .assumingMemoryBound(to: T.self)
    }
}

// Schema2 typed accessors — Copyable fresh generics, ~Copyable schema support
extension SoASchema_C4 where S: ~Copyable {
    func fieldA<A, B>(at slot: Int) -> UnsafeMutablePointer<A>
    where S == Schema2<A, B> {
        pointer(field: 0, as: A.self, at: slot)
    }
    func fieldB<A, B>(at slot: Int) -> UnsafeMutablePointer<B>
    where S == Schema2<A, B> {
        pointer(field: 1, as: B.self, at: slot)
    }
}

func testC4() {
    print("\n=== C4: Protocol schema ===")

    // With Copyable types (typed accessors work)
    let storage = SoASchema_C4<Schema2<UInt8, Int>>(capacity: 8)
    print("C4: offsets=\(storage.fieldOffsets)")
    storage.fieldA(at: 0).initialize(to: 0x80 as UInt8)
    storage.fieldB(at: 0).initialize(to: 42 as Int)
    print("C4: A[0]=\(storage.fieldA(at: 0).pointee), B[0]=\(storage.fieldB(at: 0).pointee)")

    // With ~Copyable types (runtime-indexed access)
    struct Resource: ~Copyable { var id: Int }
    let s2 = SoASchema_C4<Schema2<UInt8, Resource>>(capacity: 8)
    s2.pointer(field: 0, as: UInt8.self, at: 0).initialize(to: 0x80)
    s2.pointer(field: 1, as: Resource.self, at: 0).initialize(to: Resource(id: 42))
    print("C4 ~Copyable: field0=\(s2.pointer(field: 0, as: UInt8.self, at: 0).pointee), field1.id=\(s2.pointer(field: 1, as: Resource.self, at: 0).pointee.id)")
    s2.pointer(field: 1, as: Resource.self, at: 0).deinitialize(count: 1)

    // 3-field schema
    let s3 = SoASchema_C4<Schema3<UInt8, Int, Double>>(capacity: 4)
    print("C4: 3-field offsets=\(s3.fieldOffsets)")
    s3.pointer(field: 0, as: UInt8.self, at: 0).initialize(to: 0xFF)
    s3.pointer(field: 1, as: Int.self, at: 0).initialize(to: 999)
    s3.pointer(field: 2, as: Double.self, at: 0).initialize(to: 3.14)
    print("C4 3-field: \(s3.pointer(field: 0, as: UInt8.self, at: 0).pointee), \(s3.pointer(field: 1, as: Int.self, at: 0).pointee), \(s3.pointer(field: 2, as: Double.self, at: 0).pointee)")
}

// ============================================================================
// MARK: - C5: Inline SoA via Nested @_rawLayout
// Hypothesis: Struct with multiple @_rawLayout members gives inline N-ary SoA
// Result: CONFIRMED — InlineSoA2<UInt8,Int,4> = 40 bytes (4+pad+32), correct layout.
//         InlineSoA2<UInt8,Resource,2> = 24 bytes. True inline, ~Copyable, zero allocation.
// ============================================================================

@_rawLayout(likeArrayOf: A, count: capacity)
struct RawField_C5<A: ~Copyable, let capacity: Int>: ~Copyable {
    init() {}
}

struct InlineSoA2_C5<A: ~Copyable, B: ~Copyable, let capacity: Int>: ~Copyable {
    var _fieldA: RawField_C5<A, capacity>
    var _fieldB: RawField_C5<B, capacity>

    init() {
        _fieldA = RawField_C5()
        _fieldB = RawField_C5()
    }
}

func testC5() {
    print("\n=== C5: Inline SoA via nested @_rawLayout ===")

    var storage = InlineSoA2_C5<UInt8, Int, 4>()
    print("C5: size = \(MemoryLayout<InlineSoA2_C5<UInt8, Int, 4>>.size)")
    print("C5: stride = \(MemoryLayout<InlineSoA2_C5<UInt8, Int, 4>>.stride)")
    print("C5: alignment = \(MemoryLayout<InlineSoA2_C5<UInt8, Int, 4>>.alignment)")

    // Expected: fieldA = 4 bytes (4 × UInt8), fieldB = 32 bytes (4 × Int)
    withUnsafeMutablePointer(to: &storage) { sPtr in
        let aBase = UnsafeMutableRawPointer(sPtr).assumingMemoryBound(to: UInt8.self)
        aBase.advanced(by: 0).initialize(to: 0x80)
        aBase.advanced(by: 1).initialize(to: 0x42)

        // MemoryLayout.offset(of:) doesn't support ~Copyable types,
        // so compute the offset manually: _fieldA is RawField_C5<UInt8, 4> = 4 bytes,
        // then _fieldB is RawField_C5<Int, 4> with alignment 8.
        let fieldASize = MemoryLayout<RawField_C5<UInt8, 4>>.size
        let fieldBAlign = MemoryLayout<RawField_C5<Int, 4>>.alignment
        let fieldBOffset = (fieldASize + fieldBAlign - 1) & ~(fieldBAlign - 1)
        print("C5: computed _fieldB offset = \(fieldBOffset)")

        let bBase = UnsafeMutableRawPointer(sPtr).advanced(by: fieldBOffset)
            .assumingMemoryBound(to: Int.self)
        bBase.advanced(by: 0).initialize(to: 42)
        bBase.advanced(by: 1).initialize(to: 99)
        print("C5: A[0]=\(aBase.pointee), A[1]=\(aBase.advanced(by: 1).pointee)")
        print("C5: B[0]=\(bBase.pointee), B[1]=\(bBase.advanced(by: 1).pointee)")
    }

    // Test with ~Copyable element
    struct Resource: ~Copyable { var id: Int }
    let _ = InlineSoA2_C5<UInt8, Resource, 2>()
    print("C5: InlineSoA2<UInt8, Resource, 2> size = \(MemoryLayout<InlineSoA2_C5<UInt8, Resource, 2>>.size)")
}

// ============================================================================
// MARK: - C6: FieldDescriptor — Copyable Wrapper Carrying ~Copyable Layout
// Hypothesis: FieldDescriptor<T: ~Copyable> is Copyable, enabling layout computation
//             even for ~Copyable types without parameter pack ~Copyable support
// Result: PARTIAL — FieldDescriptor<Resource> IS Copyable. But pack `each F` still
//         requires Copyable, so can't pass through packs. Array-based workaround works.
// ============================================================================

struct FieldDescriptor<T: ~Copyable>: Copyable, Sendable {
    let stride: Int
    let alignment: Int
    init() {
        self.stride = MemoryLayout<T>.stride
        self.alignment = MemoryLayout<T>.alignment
    }
}

// Pack of COPYABLE descriptors — each describing a potentially ~Copyable type
func computeLayout_C6<each F>(
    _ descriptors: repeat FieldDescriptor<each F>,
    capacity: Int
) -> [Int] {
    var offsets: [Int] = []
    var current = 0
    for desc in repeat (each descriptors) {
        current = (current + desc.alignment - 1) & ~(desc.alignment - 1)
        offsets.append(current)
        current += desc.stride * capacity
    }
    return offsets
}

func testC6() {
    print("\n=== C6: FieldDescriptor (Copyable wrapper for ~Copyable layout) ===")

    struct Resource: ~Copyable { var id: Int }

    // POSITIVE: FieldDescriptor<Resource> is Copyable even though Resource is ~Copyable!
    let d1 = FieldDescriptor<UInt8>()
    let d2 = FieldDescriptor<Resource>()
    let d3 = FieldDescriptor<Int>()

    print("C6: FieldDescriptor<Resource> stride=\(d2.stride), alignment=\(d2.alignment)")
    print("C6: FieldDescriptor is Copyable: \(type(of: d2))")

    // NEGATIVE: Can't use parameter packs with ~Copyable type arguments.
    // computeLayout_C6<UInt8, Resource, Int>(...) fails because `each F` is implicitly Copyable.
    // Even though FieldDescriptor<each F> is Copyable, the pack type F itself must be Copyable.
    // This is the same fundamental pack limitation as V7.

    // Workaround: Use pack with all-Copyable types
    let offsets = computeLayout_C6(d1, d3, capacity: 16)
    print("C6: offsets for <UInt8, Int> cap=16: \(offsets)")

    // Workaround: Array of type-erased descriptors for ~Copyable types
    let descriptors: [(stride: Int, alignment: Int)] = [
        (d1.stride, d1.alignment),
        (d2.stride, d2.alignment),
        (d3.stride, d3.alignment),
    ]
    var arrayOffsets: [Int] = []
    var current = 0
    for desc in descriptors {
        current = (current + desc.alignment - 1) & ~(desc.alignment - 1)
        arrayOffsets.append(current)
        current += desc.stride * 16
    }
    print("C6: array-based offsets for <UInt8, Resource, Int> cap=16: \(arrayOffsets)")

    // KEY FINDING: FieldDescriptor<T: ~Copyable> IS Copyable and carries layout info.
    // But parameter packs STILL require each F: Copyable, so the Copyable wrapper
    // doesn't help with pack-based N-ary. Works via array-based type erasure instead.
}

// ============================================================================
// MARK: - C7: SoAField Handle (Record-Typed, ~Copyable-Safe)
// Hypothesis: Phantom-typed field handles give type-safe access without
//             requiring ~Copyable propagation through extensions
// Result: CONFIRMED — subscript for Copyable, pointer() for ~Copyable. Both work with ~Copyable Record.
// ============================================================================

/// Type-safe field handle — Record is phantom, Value determines the pointer type
struct SoAField_C7<Record: ~Copyable, Value: ~Copyable>: Copyable, Sendable {
    let fieldIndex: Int
    let fieldOffset: Int
    let fieldStride: Int
}

final class SoARecord_C7<Record: ~Copyable>: @unchecked Sendable {
    let capacity: Int
    let buffer: UnsafeMutableRawPointer

    init(capacity: Int, totalBytes: Int, alignment: Int) {
        self.capacity = capacity
        self.buffer = .allocate(byteCount: max(totalBytes, 1), alignment: alignment)
    }

    deinit { buffer.deallocate() }

    /// Core pointer access — field handle carries type info
    func pointer<Value: ~Copyable>(_ field: SoAField_C7<Record, Value>, at slot: Int) -> UnsafeMutablePointer<Value> {
        buffer.advanced(by: field.fieldOffset + slot * field.fieldStride)
            .assumingMemoryBound(to: Value.self)
    }
}

// Copyable subscript — explicit ~Copyable on Record so it works for noncopyable record types
extension SoARecord_C7 where Record: ~Copyable {
    subscript<Value: Copyable>(_ field: SoAField_C7<Record, Value>, at slot: Int) -> Value {
        get { pointer(field, at: slot).pointee }
        set { pointer(field, at: slot).pointee = newValue }
    }
}

func testC7() {
    print("\n=== C7: SoAField handles ===")

    // ~Copyable record type
    struct Slot: ~Copyable {
        var metadata: UInt8
        var payload: Int
    }

    let cap = 16
    let metaStride = MemoryLayout<UInt8>.stride
    let payloadOffset = (cap * metaStride + MemoryLayout<Int>.alignment - 1) & ~(MemoryLayout<Int>.alignment - 1)
    let totalBytes = payloadOffset + cap * MemoryLayout<Int>.stride

    let storage = SoARecord_C7<Slot>(
        capacity: cap,
        totalBytes: totalBytes,
        alignment: MemoryLayout<Int>.alignment
    )

    // Field handles — typed and named
    let metadata = SoAField_C7<Slot, UInt8>(fieldIndex: 0, fieldOffset: 0, fieldStride: metaStride)
    let payload = SoAField_C7<Slot, Int>(fieldIndex: 1, fieldOffset: payloadOffset, fieldStride: MemoryLayout<Int>.stride)

    // Subscript access (Copyable values):
    storage[metadata, at: 0] = 0x80
    storage[payload, at: 0] = 42
    print("C7: metadata[0]=\(storage[metadata, at: 0]), payload[0]=\(storage[payload, at: 0])")

    // Pointer access (works for ~Copyable too):
    storage.pointer(metadata, at: 1).initialize(to: 0x42)
    storage.pointer(payload, at: 1).initialize(to: 99)
    print("C7: pointer — metadata[1]=\(storage.pointer(metadata, at: 1).pointee), payload[1]=\(storage.pointer(payload, at: 1).pointee)")

    // Test: ~Copyable value in a field
    struct Resource: ~Copyable { var id: Int }
    struct Slot2: ~Copyable { var meta: UInt8; var res: Resource }

    let resOffset = (cap * metaStride + MemoryLayout<Resource>.alignment - 1) & ~(MemoryLayout<Resource>.alignment - 1)
    let total2 = resOffset + cap * MemoryLayout<Resource>.stride
    let s2 = SoARecord_C7<Slot2>(capacity: cap, totalBytes: total2, alignment: MemoryLayout<Resource>.alignment)
    let metaField2 = SoAField_C7<Slot2, UInt8>(fieldIndex: 0, fieldOffset: 0, fieldStride: metaStride)
    let resField2 = SoAField_C7<Slot2, Resource>(fieldIndex: 1, fieldOffset: resOffset, fieldStride: MemoryLayout<Resource>.stride)

    s2[metaField2, at: 0] = 0xFF
    s2.pointer(resField2, at: 0).initialize(to: Resource(id: 42))
    print("C7 ~Copyable: meta=\(s2[metaField2, at: 0]), res.id=\(s2.pointer(resField2, at: 0).pointee.id)")
    s2.pointer(resField2, at: 0).deinitialize(count: 1)
}

// ============================================================================
// MARK: - C8: Dynamic Builder
// Hypothesis: Runtime builder pattern with ~Copyable field registration
// Result: CONFIRMED — addField<T: ~Copyable>() works. Fully dynamic, type-erased, ~Copyable safe.
// ============================================================================

final class SoADynamic_C8: @unchecked Sendable {
    struct FieldInfo {
        let offset: Int
        let stride: Int
    }

    let capacity: Int
    let buffer: UnsafeMutableRawPointer
    let fields: [FieldInfo]

    init(capacity: Int, fields: [FieldInfo], totalBytes: Int, alignment: Int) {
        self.capacity = capacity
        self.fields = fields
        self.buffer = .allocate(byteCount: max(totalBytes, 1), alignment: alignment)
    }

    deinit { buffer.deallocate() }

    func rawPointer(field: Int, at slot: Int) -> UnsafeMutableRawPointer {
        buffer.advanced(by: fields[field].offset + slot * fields[field].stride)
    }
}

struct SoABuilder_C8 {
    var fieldInfos: [(stride: Int, alignment: Int)] = []
    var capacity: Int

    init(capacity: Int) { self.capacity = capacity }

    mutating func addField<T: ~Copyable>(_: T.Type) -> Int {
        let index = fieldInfos.count
        fieldInfos.append((stride: MemoryLayout<T>.stride, alignment: MemoryLayout<T>.alignment))
        return index
    }

    func build() -> SoADynamic_C8 {
        var offsets: [Int] = []
        var current = 0
        var maxAlign = 1
        for info in fieldInfos {
            if info.alignment > maxAlign { maxAlign = info.alignment }
            current = (current + info.alignment - 1) & ~(info.alignment - 1)
            offsets.append(current)
            current += info.stride * capacity
        }
        let fields = zip(offsets, fieldInfos).map { offset, info in
            SoADynamic_C8.FieldInfo(offset: offset, stride: info.stride)
        }
        return SoADynamic_C8(capacity: capacity, fields: fields, totalBytes: current, alignment: maxAlign)
    }
}

func testC8() {
    print("\n=== C8: Dynamic builder ===")

    struct Resource: ~Copyable { var id: Int }

    var builder = SoABuilder_C8(capacity: 16)
    let metaField = builder.addField(UInt8.self)
    let resField = builder.addField(Resource.self)
    let scoreField = builder.addField(Double.self)
    let storage = builder.build()

    storage.rawPointer(field: metaField, at: 0).assumingMemoryBound(to: UInt8.self).initialize(to: 0x80)
    storage.rawPointer(field: resField, at: 0).assumingMemoryBound(to: Resource.self).initialize(to: Resource(id: 42))
    storage.rawPointer(field: scoreField, at: 0).assumingMemoryBound(to: Double.self).initialize(to: 3.14)

    print("C8: meta=\(storage.rawPointer(field: metaField, at: 0).assumingMemoryBound(to: UInt8.self).pointee)")
    print("C8: res.id=\(storage.rawPointer(field: resField, at: 0).assumingMemoryBound(to: Resource.self).pointee.id)")
    print("C8: score=\(storage.rawPointer(field: scoreField, at: 0).assumingMemoryBound(to: Double.self).pointee)")

    storage.rawPointer(field: resField, at: 0).assumingMemoryBound(to: Resource.self).deinitialize(count: 1)
}

// ============================================================================
// MARK: - Run
// ============================================================================

func runCreativeExperiments() {
    print("\n" + String(repeating: "=", count: 60))
    print("CREATIVE N-ARY SOA EXPERIMENTS")
    print(String(repeating: "=", count: 60) + "\n")

    testC1()
    testC2()
    testC3()
    testC4()
    testC5()
    testC6()
    testC7()
    testC8()

    print("\n" + String(repeating: "=", count: 60))
    print("CREATIVE EXPERIMENTS COMPLETE")
    print(String(repeating: "=", count: 60))
}
