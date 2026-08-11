// MARK: - Bit.Vector.Protocol Feasibility Experiment
// Purpose: Validate whether a ~Copyable protocol can unify Bit.Vector operations
//          across Copyable, ~Copyable, and value-generic types.
//
// Hypothesis: Swift 6.2 supports ~Copyable protocol with default extensions for
//             all core bit-vector operations, enabling a single protocol to replace
//             duplicated implementations across 5 Bit.Vector variants.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED (with one workaround — see V2 below)
// Date: 2026-02-12
//
// Evidence: Build Succeeded, all 10 variants pass at runtime.
// Workaround: subscript get/set in ~Copyable protocol extension crashes compiler
//             (swift bug). Use subscript as protocol REQUIREMENT instead of default.

// =============================================================================
// MARK: - Protocol Definition
// =============================================================================

// MARK: - V1: Protocol with word-level requirements + subscript requirement
// Hypothesis: ~Copyable protocol can declare word access + subscript as requirements.
// Result: CONFIRMED — Build Succeeded

protocol BitVectorProtocol: ~Copyable {
    /// Number of UInt words in backing storage.
    var wordCount: Int { get }

    /// Total bit capacity.
    var bitCapacity: Int { get }

    /// Read a word at the given index.
    borrowing func word(at index: Int) -> UInt

    /// Write a word at the given index.
    mutating func setWord(at index: Int, to value: UInt)

    /// Read/write a single bit. Protocol REQUIREMENT (not default) because
    /// subscript get/set in ~Copyable protocol extension triggers compiler crash.
    /// Each conformer provides this — trivial 5-line implementation.
    subscript(index: Int) -> Bool { get set }
}

// =============================================================================
// MARK: - V2: Read-only default extensions
// Hypothesis: popcount, allFalse, allTrue work as defaults on ~Copyable Self.
// Result: CONFIRMED — Build Succeeded + correct output

extension BitVectorProtocol where Self: ~Copyable {
    var popcount: Int {
        var total = 0
        for i in 0..<wordCount { total += word(at: i).nonzeroBitCount }
        return total
    }

    var allFalse: Bool {
        for i in 0..<wordCount { if word(at: i) != 0 { return false } }
        return true
    }

    var allTrue: Bool {
        let fullWords = bitCapacity / UInt.bitWidth
        let remainderBits = bitCapacity % UInt.bitWidth
        for i in 0..<fullWords { if word(at: i) != ~0 { return false } }
        if remainderBits > 0 {
            let mask: UInt = (1 << remainderBits) - 1
            if word(at: fullWords) & mask != mask { return false }
        }
        return true
    }
}

// =============================================================================
// MARK: - V3: Mutating default extensions (clearAll, setAll, popFirst)
// Hypothesis: Mutating methods work as defaults on ~Copyable Self.
// Result: CONFIRMED — Build Succeeded + correct output

extension BitVectorProtocol where Self: ~Copyable {
    mutating func clearAll() {
        for i in 0..<wordCount { setWord(at: i, to: 0) }
    }

    mutating func setAll() {
        let fullWords = bitCapacity / UInt.bitWidth
        let remainderBits = bitCapacity % UInt.bitWidth
        for i in 0..<fullWords { setWord(at: i, to: ~0) }
        if remainderBits > 0 {
            setWord(at: fullWords, to: (1 << remainderBits) - 1)
        }
    }

    /// Removes and returns the index of the lowest set bit (Wegner/Kernighan).
    mutating func popFirst() -> Int? {
        for i in 0..<wordCount {
            let w = word(at: i)
            if w != 0 {
                let bit = w.trailingZeroBitCount
                setWord(at: i, to: w & (w &- 1))
                let globalIndex = i * UInt.bitWidth + bit
                guard globalIndex < bitCapacity else { return nil }
                return globalIndex
            }
        }
        return nil
    }
}

// =============================================================================
// MARK: - V4: Ones iterator as default extension
// Hypothesis: Non-mutating Sequence return from ~Copyable protocol extension works.
// Result: CONFIRMED — Build Succeeded + correct output

struct OnesIterator: IteratorProtocol {
    var words: [UInt]
    let capacity: Int
    var wordIndex: Int = 0

    mutating func next() -> Int? {
        while wordIndex < words.count {
            let w = words[wordIndex]
            if w != 0 {
                let bit = w.trailingZeroBitCount
                words[wordIndex] = w & (w &- 1)
                let globalIndex = wordIndex * UInt.bitWidth + bit
                guard globalIndex < capacity else { return nil }
                return globalIndex
            }
            wordIndex += 1
        }
        return nil
    }
}

struct OnesSequence: Sequence {
    let words: [UInt]
    let capacity: Int
    func makeIterator() -> OnesIterator {
        OnesIterator(words: words, capacity: capacity)
    }
}

extension BitVectorProtocol where Self: ~Copyable {
    /// Non-mutating sequence of all set-bit indices. Copies word storage.
    var ones: OnesSequence {
        var wordsCopy: [UInt] = []
        wordsCopy.reserveCapacity(wordCount)
        for i in 0..<wordCount { wordsCopy.append(word(at: i)) }
        return OnesSequence(words: wordsCopy, capacity: bitCapacity)
    }
}

// =============================================================================
// MARK: - Conforming Types
// =============================================================================

// MARK: - V5: ~Copyable conformer (stand-in for Bit.Vector)
// Hypothesis: ~Copyable struct conforms and inherits all defaults.
// Result: CONFIRMED

struct HeapBitVector: ~Copyable, BitVectorProtocol {
    private var _words: UnsafeMutableBufferPointer<UInt>
    let bitCapacity: Int
    var wordCount: Int { _words.count }

    init(capacity: Int) {
        let wc = (capacity + UInt.bitWidth - 1) / UInt.bitWidth
        let ptr = UnsafeMutablePointer<UInt>.allocate(capacity: wc)
        ptr.initialize(repeating: 0, count: wc)
        _words = UnsafeMutableBufferPointer(start: ptr, count: wc)
        bitCapacity = capacity
    }

    deinit { _words.baseAddress?.deallocate() }

    borrowing func word(at index: Int) -> UInt { _words[index] }
    mutating func setWord(at index: Int, to value: UInt) { _words[index] = value }

    // Subscript requirement (5 lines — compiler bug workaround)
    subscript(index: Int) -> Bool {
        get { (word(at: index / UInt.bitWidth) >> (index % UInt.bitWidth)) & 1 != 0 }
        set {
            let mask: UInt = 1 << (index % UInt.bitWidth)
            let wi = index / UInt.bitWidth
            if newValue { setWord(at: wi, to: word(at: wi) | mask) }
            else { setWord(at: wi, to: word(at: wi) & ~mask) }
        }
    }
}

// MARK: - V6: Copyable conformer (stand-in for Bit.Vector.Bounded)
// Hypothesis: Copyable struct conforms to same ~Copyable protocol.
// Result: CONFIRMED

struct ArrayBitVector: BitVectorProtocol, Sendable {
    private var _words: [UInt]
    let bitCapacity: Int
    var wordCount: Int { _words.count }

    init(capacity: Int) {
        let wc = (capacity + UInt.bitWidth - 1) / UInt.bitWidth
        _words = Array(repeating: 0, count: wc)
        bitCapacity = capacity
    }

    borrowing func word(at index: Int) -> UInt { _words[index] }
    mutating func setWord(at index: Int, to value: UInt) { _words[index] = value }

    subscript(index: Int) -> Bool {
        get { (word(at: index / UInt.bitWidth) >> (index % UInt.bitWidth)) & 1 != 0 }
        set {
            let mask: UInt = 1 << (index % UInt.bitWidth)
            let wi = index / UInt.bitWidth
            if newValue { setWord(at: wi, to: word(at: wi) | mask) }
            else { setWord(at: wi, to: word(at: wi) & ~mask) }
        }
    }
}

// MARK: - V7: Value-generic conformer (stand-in for Bit.Vector.Static<N>)
// Hypothesis: Value-generic struct conforms and inherits all defaults.
// Result: CONFIRMED

struct InlineBitVector<let N: Int>: BitVectorProtocol, Sendable {
    private var _words: InlineArray<N, UInt>
    var wordCount: Int { N }
    var bitCapacity: Int { N * UInt.bitWidth }

    init() { _words = InlineArray(repeating: 0) }

    borrowing func word(at index: Int) -> UInt { _words[index] }
    mutating func setWord(at index: Int, to value: UInt) { _words[index] = value }

    subscript(index: Int) -> Bool {
        get { (word(at: index / UInt.bitWidth) >> (index % UInt.bitWidth)) & 1 != 0 }
        set {
            let mask: UInt = 1 << (index % UInt.bitWidth)
            let wi = index / UInt.bitWidth
            if newValue { setWord(at: wi, to: word(at: wi) | mask) }
            else { setWord(at: wi, to: word(at: wi) & ~mask) }
        }
    }
}

// =============================================================================
// MARK: - V8: Generic function over all conformers
// Hypothesis: Single generic function works with ~Copyable, Copyable, value-generic.
// Result: CONFIRMED
// =============================================================================

func testAll<V: BitVectorProtocol & ~Copyable>(_ v: inout V, label: String) {
    print("--- \(label) ---")

    // V2: Read-only defaults
    assert(v.allFalse)
    assert(v.popcount == 0)

    // Subscript (requirement, not default)
    v[0] = true
    v[3] = true
    v[7] = true
    assert(v.popcount == 3)
    assert(v[0] && !v[1] && v[3] && v[7])
    print("  subscript: [0]=\(v[0]) [3]=\(v[3]) [7]=\(v[7]) popcount=\(v.popcount)")

    // V4: Ones iteration (non-destructive)
    var indices: [Int] = []
    for i in v.ones { indices.append(i) }
    assert(indices == [0, 3, 7])
    assert(v.popcount == 3, "ones must be non-destructive")
    print("  ones: \(indices)")

    // V3: popFirst (destructive Wegner/Kernighan)
    assert(v.popFirst() == 0)
    assert(v.popFirst() == 3)
    assert(v.popcount == 1)
    print("  popFirst x2: remaining popcount=\(v.popcount)")

    // V3: clearAll / setAll / allTrue
    v.clearAll()
    assert(v.allFalse)
    v.setAll()
    assert(v.allTrue)
    print("  setAll: popcount=\(v.popcount) allTrue=\(v.allTrue)")

    v.clearAll()
    print("  PASS")
}

// =============================================================================
// MARK: - V9: Borrowing generic read-only
// Hypothesis: borrowing parameter works with ~Copyable protocol defaults.
// Result: CONFIRMED
// =============================================================================

func readOnly<V: BitVectorProtocol & ~Copyable>(_ v: borrowing V) -> Int {
    v.popcount
}

// =============================================================================
// MARK: - V10: forEach via ones on all types (stand-in for deinit pattern)
// Hypothesis: ones.forEach works in non-mutating context on all conformers.
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// =============================================================================

func forEachOnes<V: BitVectorProtocol & ~Copyable>(_ v: borrowing V) -> [Int] {
    var result: [Int] = []
    for i in v.ones { result.append(i) }
    return result
}

// =============================================================================
// MARK: - Execution
// =============================================================================

print("=== Bit.Vector.Protocol Feasibility Experiment ===\n")

// ~Copyable
var heap = HeapBitVector(capacity: 64)
testAll(&heap, label: "V5: HeapBitVector (~Copyable)")

// Copyable
var arr = ArrayBitVector(capacity: 64)
testAll(&arr, label: "V6: ArrayBitVector (Copyable)")

// Value-generic
var inl = InlineBitVector<1>()
testAll(&inl, label: "V7: InlineBitVector<1> (value-generic)")

// V9: Borrowing
var heap2 = HeapBitVector(capacity: 128)
heap2[42] = true
heap2[99] = true
print("\n--- V9: borrowing readOnly ---")
print("  heap2 popcount: \(readOnly(heap2))")
assert(readOnly(heap2) == 2)
print("  arr popcount: \(readOnly(arr))")
print("  PASS")

// V10: forEach via ones
heap2.clearAll()
heap2[10] = true
heap2[20] = true
heap2[30] = true
print("\n--- V10: forEachOnes ---")
let onesFromHeap = forEachOnes(heap2)
print("  heap2 ones: \(onesFromHeap)")
assert(onesFromHeap == [10, 20, 30])
print("  PASS")

print("\n=== ALL 10 VARIANTS CONFIRMED ===")
