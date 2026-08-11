// MARK: - Sequence.Protocol Conformance for Bit Vector Ones Iteration
// Purpose: Validate that types mirroring Bit.Vector.Ones.View and
//          Bit.Vector.Ones.Static can conform to Sequence.Protocol +
//          Swift.Sequence, proving the design compiles before integrating
//          into the real package.
//
// Hypotheses:
//   V1: A Wegner/Kernighan iterator across UInt words compiles — CONFIRMED
//   V2: A pointer-based view type conforms to Sequence.Protocol — CONFIRMED
//   V3: That same type conforms to Swift.Sequence (Copyable bridge) — CONFIRMED
//   V4: Swift.Sequence.forEach works on temporaries (non-mutating) — CONFIRMED
//   V5: An InlineArray-based static type conforms to both protocols — CONFIRMED
//   V6: for-in syntax works via Swift.Sequence conformance — CONFIRMED
//   V7: Bit.Vector.Ones.View (real type) can be extended with Swift.Sequence
//       retroactively once it has Sequence.Protocol conformance — CONFIRMED (by proxy)
//
// FINDING: Swift.Sequence conformance requires explicit `underestimatedCount`
//          override when the type also conforms to Sequence.Protocol. The
//          Sequence.Protocol+Swift.Sequence.swift extension provides one default,
//          and Swift.Sequence provides another. Compiler sees ambiguity.
//          Fix: add `var underestimatedCount: Int { 0 }` to each conformance.
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-01-18-a
// Status: SUPERSEDED 2026-04-30 — Sequence protocol restructured (Sequence.Protocol, Sequence.Borrowing.Protocol, Sequence.Iterator.Protocol, Sequence.Drain.Protocol, etc.); experiment tests an earlier non-decomposed Sequence surface and would require redesign against current ForEach/Drain witness shape
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 7 variants pass, build and runtime
// Output: V2 [0, 3, 63, 64, 127], V3 map OK, V4 forEach-on-temporary OK,
//         V5 [0, 5, 64, 100], V6 for-in OK, empty/capacity-bound edges OK
// Date: 2026-02-06

public import Bit_Vector_Primitives
public import Sequence_Primitives

// =============================================================================
// MARK: - V1/V2/V3: Pointer-based View with Iterator
// Hypothesis: A struct holding UnsafeMutablePointer<UInt>, word count, and
//             capacity can provide a Wegner/Kernighan iterator and conform
//             to Sequence.Protocol + Swift.Sequence.
// Result: CONFIRMED
// =============================================================================

/// Mirrors `Bit.Vector.Ones.View` structure for protocol conformance testing.
@safe
struct DynamicOnesView: Copyable, @unchecked Sendable {
    let words: UnsafeMutablePointer<UInt>
    let wordCount: Int
    let capacity: Int

    @safe
    struct Iterator: IteratorProtocol {
        let words: UnsafeMutablePointer<UInt>
        let wordCount: Int
        let capacity: Int
        var wordIndex: Int
        var currentWord: UInt

        init(view: DynamicOnesView) {
            unsafe self.words = view.words
            self.wordCount = view.wordCount
            self.capacity = view.capacity
            self.wordIndex = 0
            if view.wordCount > 0 {
                unsafe self.currentWord = view.words[0]
            } else {
                self.currentWord = 0
            }
        }

        mutating func next() -> Int? {
            // Advance to next word with set bits
            while currentWord == 0 {
                wordIndex += 1
                guard wordIndex < wordCount else { return nil }
                unsafe currentWord = words[wordIndex]
            }

            // Wegner/Kernighan: extract lowest set bit
            let bitPosition = currentWord.trailingZeroBitCount
            currentWord &= currentWord &- 1

            let globalIndex = wordIndex * UInt.bitWidth + bitPosition
            guard globalIndex < capacity else { return nil }
            return globalIndex
        }
    }
}

extension DynamicOnesView: Sequence.`Protocol` {
    typealias Element = Int

    func makeIterator() -> Iterator {
        Iterator(view: self)
    }
}

extension DynamicOnesView: Swift.Sequence {
    // Disambiguate: Sequence.Protocol+Swift.Sequence.swift provides
    // underestimatedCount on Sequence.Protocol & Copyable, AND Swift.Sequence
    // has its own default. Compiler sees two candidates. Explicit override resolves.
    var underestimatedCount: Int { 0 }
}

// =============================================================================
// MARK: - V5: InlineArray-based Static type with Iterator
// Hypothesis: A Copyable struct copying InlineArray<wordCount, UInt> conforms
//             to Sequence.Protocol + Swift.Sequence.
// Result: CONFIRMED
// =============================================================================

@safe
struct StaticOnesView<let wordCount: Int>: Copyable, Sendable {
    let storage: InlineArray<wordCount, UInt>

    @safe
    struct Iterator: IteratorProtocol {
        let storage: InlineArray<wordCount, UInt>
        var wordIndex: Int
        var currentWord: UInt

        init(storage: InlineArray<wordCount, UInt>) {
            self.storage = storage
            self.wordIndex = 0
            if wordCount > 0 {
                self.currentWord = storage[0]
            } else {
                self.currentWord = 0
            }
        }

        mutating func next() -> Int? {
            while currentWord == 0 {
                wordIndex += 1
                guard wordIndex < wordCount else { return nil }
                currentWord = storage[wordIndex]
            }

            let bitPosition = currentWord.trailingZeroBitCount
            currentWord &= currentWord &- 1

            return wordIndex * UInt.bitWidth + bitPosition
        }
    }
}

extension StaticOnesView: Sequence.`Protocol` {
    typealias Element = Int

    func makeIterator() -> Iterator {
        Iterator(storage: storage)
    }
}

extension StaticOnesView: Swift.Sequence {
    var underestimatedCount: Int { 0 }
}

// =============================================================================
// MARK: - V7: Real Bit.Vector.Ones.View retroactive conformance
// Hypothesis: The real Bit.Vector.Ones.View can be retroactively conformed
//             to Swift.Sequence if it already has a makeIterator() that
//             returns an IteratorProtocol-conforming type.
//
// Note: We can't add Sequence.Protocol conformance from outside the module
//       (internal stored properties), but we CAN test that the retroactive
//       Swift.Sequence conformance compiles when Sequence.Protocol is satisfied.
//       The real conformance will be added inside the package.
// Result: CONFIRMED (by proxy via DynamicOnesView)
// =============================================================================

// This variant tests the pattern: given a type that already conforms to
// Sequence.Protocol, can we add Swift.Sequence in a separate extension?
// (Tested via DynamicOnesView above, which mirrors the real type.)

// =============================================================================
// MARK: - Runtime Validation
// =============================================================================

func testDynamic() {
    print("=== V1/V2/V3/V4/V6: Dynamic (pointer-based) ===")

    // Allocate 2 words = 128 bits
    let words = UnsafeMutablePointer<UInt>.allocate(capacity: 2)
    unsafe words.initialize(repeating: 0, count: 2)
    defer { unsafe words.deallocate() }

    // Set bits: 0, 3, 63, 64, 127
    unsafe words[0] = (1 << 0) | (1 << 3) | (1 << 63)  // word 0
    unsafe words[1] = (1 << 0) | (1 << 63)              // word 1 → bits 64, 127

    let view = unsafe DynamicOnesView(words: words, wordCount: 2, capacity: 128)

    // V2: Sequence.Protocol — makeIterator()
    var iter = view.makeIterator()
    var indices: [Int] = []
    while let i = iter.next() { indices.append(i) }
    print("  V2 makeIterator(): \(indices)")
    assert(indices == [0, 3, 63, 64, 127], "V2 FAILED: \(indices)")
    print("  V2: CONFIRMED")

    // V3: Swift.Sequence — map
    let mapped = view.map { $0 }
    print("  V3 map(): \(mapped)")
    assert(mapped == [0, 3, 63, 64, 127], "V3 FAILED")
    print("  V3: CONFIRMED")

    // V4: forEach on temporary — no variable binding for the view
    var tempIndices: [Int] = []
    unsafe DynamicOnesView(words: words, wordCount: 2, capacity: 128)
        .forEach { tempIndices.append($0) }
    print("  V4 forEach on temporary: \(tempIndices)")
    assert(tempIndices == [0, 3, 63, 64, 127], "V4 FAILED")
    print("  V4: CONFIRMED")

    // V6: for-in
    var forInIndices: [Int] = []
    for i in view { forInIndices.append(i) }
    print("  V6 for-in: \(forInIndices)")
    assert(forInIndices == [0, 3, 63, 64, 127], "V6 FAILED")
    print("  V6: CONFIRMED")
}

func testStatic() {
    print("\n=== V5: Static (InlineArray-based) ===")

    var storage = InlineArray<2, UInt>(repeating: 0)
    // Set bits: 0, 5, 64, 100
    storage[0] = (1 << 0) | (1 << 5)
    storage[1] = (1 << 0) | (1 << 36)  // bits 64, 100

    let ones = StaticOnesView<2>(storage: storage)

    // makeIterator
    var iter = ones.makeIterator()
    var indices: [Int] = []
    while let i = iter.next() { indices.append(i) }
    print("  V5 makeIterator(): \(indices)")
    assert(indices == [0, 5, 64, 100], "V5 FAILED: \(indices)")

    // map (Swift.Sequence)
    let mapped = ones.map { $0 }
    print("  V5 map(): \(mapped)")
    assert(mapped == [0, 5, 64, 100], "V5 FAILED")

    // for-in
    var forInIndices: [Int] = []
    for i in ones { forInIndices.append(i) }
    print("  V5 for-in: \(forInIndices)")
    assert(forInIndices == [0, 5, 64, 100], "V5 FAILED")
    print("  V5: CONFIRMED")
}

func testEmpty() {
    print("\n=== Edge: Empty vectors ===")

    // Dynamic empty
    let words = UnsafeMutablePointer<UInt>.allocate(capacity: 1)
    unsafe words.initialize(to: 0)
    defer { unsafe words.deallocate() }

    let emptyDynamic = unsafe DynamicOnesView(words: words, wordCount: 1, capacity: 64)
    assert(Array(emptyDynamic).isEmpty, "Empty dynamic should produce []")
    print("  Empty dynamic: CONFIRMED")

    // Static empty
    let emptyStatic = StaticOnesView<2>(storage: InlineArray(repeating: 0))
    assert(Array(emptyStatic).isEmpty, "Empty static should produce []")
    print("  Empty static: CONFIRMED")

    // Zero-word dynamic
    let zeroWords = unsafe DynamicOnesView(words: words, wordCount: 0, capacity: 0)
    assert(Array(zeroWords).isEmpty, "Zero-word should produce []")
    print("  Zero-word: CONFIRMED")
}

func testCapacityBound() {
    print("\n=== Edge: Capacity bounds ===")

    // Set all bits in 1 word, but capacity is only 10
    let words = UnsafeMutablePointer<UInt>.allocate(capacity: 1)
    unsafe words.initialize(to: UInt.max)
    defer { unsafe words.deallocate() }

    let bounded = unsafe DynamicOnesView(words: words, wordCount: 1, capacity: 10)
    let indices = Array(bounded)
    print("  All bits set, capacity 10: \(indices)")
    assert(indices == Array(0..<10), "Should only produce indices 0..<10")
    print("  Capacity bound: CONFIRMED")
}

testDynamic()
testStatic()
testEmpty()
testCapacityBound()

print("\n=== ALL VARIANTS CONFIRMED ===")
