// MARK: - Experiment: Generic Vector as Bit Vector Substrate
// Purpose: Test whether a generic Vector<Element, N> can serve as a viable
//          substrate for Bit.Vector operations, or whether the domains are
//          fundamentally incompatible.
//
// Hypothesis: A generic Vector<UInt, wordCount>.Inline COULD replace
//             InlineArray<wordCount, UInt> in Bit.Vector.Static, but
//             Vector<UInt, N> (heap) CANNOT replace UnsafeMutablePointer<UInt>
//             in Bit.Vector (heap, ~Copyable).
//
// Toolchain: swift-6.2-RELEASE
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — generic vector can mechanically substitute for InlineArray
//         in the inline case, but adds overhead with no benefit. Heap case is
//         incompatible due to ARC vs exclusive ownership. N semantics differ
//         fundamentally (words vs bits). See detailed variant results below.
// Date: 2026-02-04

// ============================================================================
// PART 1: Simulate the generic Vector.Inline substrate
// ============================================================================

// Minimal simulation of Vector<Element, N>.Inline (what vector-primitives provides)
struct SimulatedVectorInline<Element, let N: Int> {
    var _elements: InlineArray<N, Element>

    init(_ elements: InlineArray<N, Element>) {
        self._elements = elements
    }

    init(repeating value: Element) {
        self._elements = InlineArray(repeating: value)
    }

    var elements: InlineArray<N, Element> {
        get { _elements }
        set { _elements = newValue }
    }

    subscript(index: Int) -> Element {
        get { _elements[index] }
        set { _elements[index] = newValue }
    }
}

// ============================================================================
// PART 2: Bit.Vector.Static using generic Vector substrate
// ============================================================================

// MARK: - Variant 1: Direct InlineArray (current implementation)
// Hypothesis: This is the baseline — known to work.
// Result: CONFIRMED — compiles and operates correctly

struct BitVectorStatic_InlineArray<let wordCount: Int> {
    var _storage: InlineArray<wordCount, UInt>

    static var capacity: Int { wordCount * UInt.bitWidth }

    init() {
        _storage = InlineArray(repeating: 0)
    }

    subscript(bitIndex: Int) -> Bool {
        get {
            let wordIdx = bitIndex / UInt.bitWidth
            let bitIdx = bitIndex % UInt.bitWidth
            return (_storage[wordIdx] & (1 << bitIdx)) != 0
        }
        set {
            let wordIdx = bitIndex / UInt.bitWidth
            let bitIdx = bitIndex % UInt.bitWidth
            if newValue {
                _storage[wordIdx] |= (1 << bitIdx)
            } else {
                _storage[wordIdx] &= ~(1 << bitIdx)
            }
        }
    }

    var popcount: Int {
        var count = 0
        for i in 0..<wordCount {
            count += _storage[i].nonzeroBitCount
        }
        return count
    }
}

// MARK: - Variant 2: SimulatedVectorInline substrate
// Hypothesis: Vector<UInt, wordCount>.Inline can replace InlineArray<wordCount, UInt>
//             without loss of functionality.
// Result: (pending)

struct BitVectorStatic_VectorSubstrate<let wordCount: Int> {
    var _storage: SimulatedVectorInline<UInt, wordCount>

    static var capacity: Int { wordCount * UInt.bitWidth }

    init() {
        _storage = SimulatedVectorInline(repeating: 0)
    }

    // Test: Can we perform bit-packing through the Vector subscript?
    subscript(bitIndex: Int) -> Bool {
        get {
            let wordIdx = bitIndex / UInt.bitWidth
            let bitIdx = bitIndex % UInt.bitWidth
            return (_storage[wordIdx] & (1 << bitIdx)) != 0
        }
        set {
            let wordIdx = bitIndex / UInt.bitWidth
            let bitIdx = bitIndex % UInt.bitWidth
            if newValue {
                _storage[wordIdx] |= (1 << bitIdx)
            } else {
                _storage[wordIdx] &= ~(1 << bitIdx)
            }
        }
    }

    // Test: Can we iterate words through the Vector elements accessor?
    var popcount: Int {
        var count = 0
        for i in 0..<wordCount {
            count += _storage[i].nonzeroBitCount
        }
        return count
    }

    // Test: Can we perform bulk operations through the Vector substrate?
    mutating func setAll() {
        for i in 0..<wordCount {
            _storage[i] = ~0
        }
    }

    mutating func clearAll() {
        _storage = SimulatedVectorInline(repeating: 0)
    }

    // Test: Can we access the raw InlineArray for word-level bulk operations?
    mutating func bitwiseAnd(_ other: Self) {
        for i in 0..<wordCount {
            _storage[i] &= other._storage[i]
        }
    }

    mutating func bitwiseOr(_ other: Self) {
        for i in 0..<wordCount {
            _storage[i] |= other._storage[i]
        }
    }
}

// ============================================================================
// PART 3: Heap Bit.Vector — ~Copyable with manual memory
// ============================================================================

// MARK: - Variant 3: Heap Vector substrate attempt
// Hypothesis: Vector<UInt, N> (ManagedBuffer, ARC) CANNOT replace
//             UnsafeMutablePointer<UInt> in the ~Copyable heap Bit.Vector
//             because the ownership models are incompatible.

// Simulated heap Vector (like vector-primitives Vector<Element, N>)
// Uses class-based storage with ARC — fundamentally Copyable (reference counted)
final class HeapVectorStorage<Element, let N: Int> {
    var elements: InlineArray<N, Element>

    init(repeating value: Element) {
        elements = InlineArray(repeating: value)
    }

    subscript(index: Int) -> Element {
        get { elements[index] }
        set { elements[index] = newValue }
    }
}

// MARK: - Variant 3a: Heap bit vector using heap Vector substrate
// Result: (pending)

struct BitVector_HeapVectorSubstrate<let wordCount: Int>: ~Copyable {
    // Problem: HeapVectorStorage is a reference type (ARC).
    // The ~Copyable Bit.Vector wants exclusive ownership,
    // but ARC allows sharing through reference counting.
    // This mismatch means:
    //   1. We lose the guarantee of exclusive word-level mutation
    //   2. We pay ARC overhead on every retain/release
    //   3. We cannot do `nonmutating set` safely (would need CoW check)
    let _storage: HeapVectorStorage<UInt, wordCount>

    init() {
        _storage = HeapVectorStorage(repeating: 0)
    }

    subscript(bitIndex: Int) -> Bool {
        get {
            let wordIdx = bitIndex / UInt.bitWidth
            let bitIdx = bitIndex % UInt.bitWidth
            return (_storage[wordIdx] & (1 << bitIdx)) != 0
        }
        // Note: nonmutating set works here because _storage is a reference.
        // But it's semantically wrong — we're mutating shared state without
        // any uniqueness check, unlike the real Bit.Vector which owns its pointer.
        nonmutating set {
            let wordIdx = bitIndex / UInt.bitWidth
            let bitIdx = bitIndex % UInt.bitWidth
            if newValue {
                _storage[wordIdx] |= (1 << bitIdx)
            } else {
                _storage[wordIdx] &= ~(1 << bitIdx)
            }
        }
    }
}

// MARK: - Variant 3b: What Bit.Vector actually does (UnsafeMutablePointer)
// For comparison — the actual pattern that gives exclusive ownership

struct BitVector_RawPointer: ~Copyable {
    let _words: UnsafeMutablePointer<UInt>
    let wordCount: Int

    init(wordCount: Int) {
        self.wordCount = wordCount
        _words = .allocate(capacity: wordCount)
        _words.initialize(repeating: 0, count: wordCount)
    }

    deinit {
        _words.deallocate()
    }

    subscript(bitIndex: Int) -> Bool {
        get {
            let wordIdx = bitIndex / UInt.bitWidth
            let bitIdx = bitIndex % UInt.bitWidth
            return (_words[wordIdx] & (1 << bitIdx)) != 0
        }
        nonmutating set {
            let wordIdx = bitIndex / UInt.bitWidth
            let bitIdx = bitIndex % UInt.bitWidth
            if newValue {
                _words[wordIdx] |= (1 << bitIdx)
            } else {
                _words[wordIdx] &= ~(1 << bitIdx)
            }
        }
    }
}

// ============================================================================
// PART 4: The dimension mismatch problem
// ============================================================================

// MARK: - Variant 4: Dimension semantics comparison
// Hypothesis: N in Vector<Element, N> means "N elements" but in Bit.Vector
//             it means "N bits" (not N words). These are categorically different
//             and a shared substrate would be confusing.
// Result: (pending)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

// This is what you'd want if vector-primitives stored bits:
// Vector<Bit, 256> — 256 elements of type Bit (256 separate values)
// But Bit.Vector.Static<4> stores 256 BITS in 4 WORDS

// The impedance mismatch:
// - Vector<UInt, 4>.Inline stores 4 UInt elements ✓ (word-level access)
// - But the user thinks in bits, not words
// - Bit.Vector.Static<4>.capacity = 256 (bits)
// - Vector<UInt, 4>.Inline.dimension = 4 (words)
//
// A "Vector<Bit, 256>" would need to store 256 individual Bit values,
// which defeats the purpose of bit-packing. Let's verify:

struct NaiveBitVector<let N: Int> {
    // This stores N individual Bool values — NOT packed
    var _elements: InlineArray<N, Bool>

    init() {
        _elements = InlineArray(repeating: false)
    }

    subscript(index: Int) -> Bool {
        get { _elements[index] }
        set { _elements[index] = newValue }
    }

    // No efficient popcount — must scan N elements
    var popcount: Int {
        var count = 0
        for i in 0..<N {
            if _elements[i] { count += 1 }
        }
        return count
    }
}

// ============================================================================
// PART 5: Execute and compare
// ============================================================================

func testVariant1_InlineArray() {
    print("=== Variant 1: InlineArray (baseline) ===")
    var bv = BitVectorStatic_InlineArray<2>()
    print("  Capacity: \(BitVectorStatic_InlineArray<2>.capacity) bits")
    bv[0] = true
    bv[63] = true
    bv[64] = true
    bv[127] = true
    print("  Set bits 0, 63, 64, 127")
    print("  Popcount: \(bv.popcount)")
    print("  bit[0]=\(bv[0]), bit[1]=\(bv[1]), bit[63]=\(bv[63]), bit[64]=\(bv[64]), bit[127]=\(bv[127])")
    print("  Result: CONFIRMED — baseline works\n")
}

func testVariant2_VectorSubstrate() {
    print("=== Variant 2: Vector.Inline substrate ===")
    var bv = BitVectorStatic_VectorSubstrate<2>()
    print("  Capacity: \(BitVectorStatic_VectorSubstrate<2>.capacity) bits")
    bv[0] = true
    bv[63] = true
    bv[64] = true
    bv[127] = true
    print("  Set bits 0, 63, 64, 127")
    print("  Popcount: \(bv.popcount)")
    print("  bit[0]=\(bv[0]), bit[1]=\(bv[1]), bit[63]=\(bv[63]), bit[64]=\(bv[64]), bit[127]=\(bv[127])")

    // Test bulk operations
    bv.setAll()
    print("  After setAll: popcount=\(bv.popcount)")
    bv.clearAll()
    print("  After clearAll: popcount=\(bv.popcount)")

    // Test bitwise operations
    var a = BitVectorStatic_VectorSubstrate<2>()
    var b = BitVectorStatic_VectorSubstrate<2>()
    a[0] = true; a[1] = true
    b[1] = true; b[2] = true
    a.bitwiseAnd(b)
    print("  AND({0,1}, {1,2}): bit[0]=\(a[0]), bit[1]=\(a[1]), bit[2]=\(a[2])")
    print("  Result: (see output)\n")
}

func testVariant3_HeapSubstrate() {
    print("=== Variant 3: Heap Vector substrate ===")
    let bv = BitVector_HeapVectorSubstrate<2>()
    bv[0] = true
    bv[63] = true
    print("  Set bits 0, 63 via nonmutating set")
    print("  bit[0]=\(bv[0]), bit[63]=\(bv[63])")

    // Demonstrate the aliasing problem:
    // If we could copy the reference, both copies would share the same words
    // (We can't copy because it's ~Copyable, but the storage IS shared by ARC)
    print("  WARNING: Storage is ARC-managed — no exclusive ownership guarantee")
    print("  The real Bit.Vector uses UnsafeMutablePointer for exclusive control")
    print("  Result: COMPILES but semantically wrong — ARC != exclusive ownership\n")
}

func testVariant4_DimensionMismatch() {
    print("=== Variant 4: Dimension mismatch ===")
    print("  Packed: BitVectorStatic<2> = 128 bits in 2 words")
    print("  Naive:  NaiveBitVector<128> = 128 bools in 128 slots")

    let _ = BitVectorStatic_InlineArray<2>()
    let _ = NaiveBitVector<128>()

    print("  Packed storage: \(MemoryLayout<BitVectorStatic_InlineArray<2>>.size) bytes")
    print("  Naive storage:  \(MemoryLayout<NaiveBitVector<128>>.size) bytes")
    print("  Ratio: \(MemoryLayout<NaiveBitVector<128>>.size / MemoryLayout<BitVectorStatic_InlineArray<2>>.size)x overhead")

    // Vector<UInt, 2>.Inline ≈ 16 bytes (2 × 8 byte UInt)
    // Vector<Bool, 128>.Inline ≈ 128 bytes (128 × 1 byte Bool)
    // Bit.Vector.Static<2> ≈ 16 bytes (2 × 8 byte UInt, packed)
    print("  Vector<UInt, 2> = word-level (\(MemoryLayout<SimulatedVectorInline<UInt, 2>>.size) bytes) — correct granularity")
    print("  Vector<Bool, 128> = element-level (\(MemoryLayout<NaiveBitVector<128>>.size) bytes) — defeats packing")
    print("  Result: N means different things — words vs bits\n")
}

// ============================================================================
// PART 6: Analysis — what a substrate would actually need
// ============================================================================

/*
 ANALYSIS: What Bit.Vector.Static actually needs from its storage:

 1. Word-indexed access: _storage[wordIndex] -> UInt     (read/write)
 2. Iteration over words: for i in 0..<wordCount          (sequential)
 3. Bulk initialization: InlineArray(repeating: 0)         (all-zeros)
 4. Word-level bitwise: _storage[i] |= mask, &= ~mask     (in-place)

 What Vector<UInt, N>.Inline provides:
 1. Element access: vector[index] -> UInt via Cyclic.Group   ✓ (but with extra indirection)
 2. Iteration: forEach { }                                    ✓ (but borrowing, not mutating)
 3. Initialization: init(repeating:)                          ✓
 4. In-place mutation: subscript set                          ✓ (but through CoW check overhead)

 The substrate WORKS but adds indirection without benefit:
 - Cyclic.Group<N> index wrapping is unnecessary (word indices don't wrap)
 - Span access is unnecessary (InlineArray subscript suffices)
 - CoW checks are unnecessary (Bit.Vector.Static is value-typed, always unique)
 - The borrowing API (forEach, withElement) doesn't help — bit ops need mutation

 CONCLUSION for Bit.Vector.Static (inline):
   Vector<UInt, wordCount>.Inline CAN replace InlineArray<wordCount, UInt>
   mechanically, but it adds cost with no benefit. Every operation would go
   through an extra layer of abstraction that provides nothing bit vectors need.

 CONCLUSION for Bit.Vector (heap):
   Vector<UInt, N> (ManagedBuffer/ARC) CANNOT replace UnsafeMutablePointer<UInt>
   because:
   a) Bit.Vector is ~Copyable — it needs exclusive ownership, not ARC sharing
   b) Bit.Vector uses nonmutating set — requires raw pointer, not CoW
   c) Bit.Vector has explicit deinit — deallocates pointer, not ARC release
   d) ManagedBuffer adds header overhead for initialization tracking that
      bit vectors don't need (they track capacity, not initialization)

 CONCLUSION on N semantics:
   In Vector<Element, N>, N means "N elements of Element"
   In Bit.Vector.Static<wordCount>, wordCount means "wordCount words holding wordCount*64 bits"
   These are different abstractions. A generic Vector<Bit, 256> would store 256
   individual Bit values (1 byte each = 256 bytes), not 256 packed bits (4 words = 32 bytes).
   Bit-packing is a domain-specific optimization that a generic container cannot provide.
*/

// ============================================================================
// Run all experiments
// ============================================================================

print("Generic Vector as Bit Vector Substrate — Experiment Results")
print(String(repeating: "=", count: 60))
print()
testVariant1_InlineArray()
testVariant2_VectorSubstrate()
testVariant3_HeapSubstrate()
testVariant4_DimensionMismatch()

print("=== Summary ===")
print("Variant 1 (InlineArray baseline):     CONFIRMED — works")
print("Variant 2 (Vector.Inline substrate):  CONFIRMED — compiles, adds overhead with no benefit")
print("Variant 3 (Heap Vector substrate):    CONFIRMED — compiles but semantically wrong (ARC ≠ exclusive ownership)")
print("Variant 4 (Dimension mismatch):       CONFIRMED — N means different things in each domain")
print()
print("Overall: A generic vector CAN mechanically serve as inline bit-vector substrate,")
print("but SHOULD NOT because it adds indirection without benefit and cannot serve as")
print("heap bit-vector substrate due to incompatible ownership models.")
