// MARK: - Bitmap Iterator Struct Storage Investigation
// Purpose: Determine why Bit.Vector.Ones.Bounded.Iterator produces 0 elements
//          when stored as a struct property, but works when used locally or in a class.
// Hypothesis: Storing the iterator in a struct property causes _currentWord to be 0
//             on first next() call — either through copy semantics, protocol witness
//             table dispatch, or cross-module specialization failure.
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-02-21-a
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — All 9 variants PASS in isolation.
//         The bitmap iterator works correctly when stored in structs, classes,
//         with IteratorProtocol, borrowing makeIterator, for-in, and explicit copy.
//         The bug requires the combination of factors in the Dictionary context
//         (Buffer.Slab conditional Copyable + -enable-testing compilation).
//         See iterator-slab-cross-module experiment for the narrowing.
// Date: 2026-02-24

import Bit_Vector_Primitives

// ============================================================================
// Setup: Create a bitmap with known set bits
// ============================================================================

// Helpers: Tagged<Bit, Ordinal/Cardinal> from integer literals
func bit(_ n: Ordinal) -> Bit.Index { .init(__unchecked: (), n) }
func bits(_ n: Cardinal) -> Bit.Index.Count { .init(__unchecked: (), n) }

func makeBitmap() -> Bit.Vector.Bounded {
    // Slab pattern: capacity == count, all bits start as 0 (vacant),
    // then individual bits set to true (occupied)
    var bitmap = try! Bit.Vector.Bounded(capacity: bits(64), count: bits(64))
    // Set bits at indices 0, 3, 7, 15, 63
    bitmap[bit(0)] = true
    bitmap[bit(3)] = true
    bitmap[bit(7)] = true
    bitmap[bit(15)] = true
    bitmap[bit(63)] = true
    return bitmap
}

let expectedCount = 5

// ============================================================================
// MARK: - Variant 1: Local var iterator, manual next()
// Hypothesis: Works — establishes baseline
// Result: [PENDING]
// ============================================================================

do {
    print("=== V1: Local var iterator, manual next() ===")
    let bitmap = makeBitmap()
    var iterator = bitmap.ones.makeIterator()
    var count = 0
    while let index = iterator.next() {
        print("  V1 got index: \(index)")
        count += 1
    }
    print("  V1 count: \(count) (expected \(expectedCount))")
    print("  V1 result: \(count == expectedCount ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 2: Iterator stored as struct property, manual next()
// Hypothesis: If this fails, struct storage is the issue (hypothesis 1)
// Result: [PENDING]
// ============================================================================

do {
    print("=== V2: Struct-stored iterator, manual next() ===")

    struct Wrapper {
        var inner: Bit.Vector.Ones.Bounded.Iterator

        init(bitmap: Bit.Vector.Bounded) {
            self.inner = bitmap.ones.makeIterator()
        }

        mutating func next() -> Bit.Index? {
            inner.next()
        }
    }

    let bitmap = makeBitmap()
    var wrapper = Wrapper(bitmap: bitmap)
    var count = 0
    while let index = wrapper.next() {
        print("  V2 got index: \(index)")
        count += 1
    }
    print("  V2 count: \(count) (expected \(expectedCount))")
    print("  V2 result: \(count == expectedCount ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 3: Struct with IteratorProtocol conformance
// Hypothesis: Protocol conformance changes dispatch/copy semantics
// Result: [PENDING]
// ============================================================================

do {
    print("=== V3: Struct with IteratorProtocol conformance ===")

    struct ProtoWrapper: IteratorProtocol {
        var inner: Bit.Vector.Ones.Bounded.Iterator

        init(bitmap: Bit.Vector.Bounded) {
            self.inner = bitmap.ones.makeIterator()
        }

        mutating func next() -> Bit.Index? {
            inner.next()
        }
    }

    let bitmap = makeBitmap()
    var wrapper = ProtoWrapper(bitmap: bitmap)
    var count = 0
    while let index = wrapper.next() {
        print("  V3 got index: \(index)")
        count += 1
    }
    print("  V3 count: \(count) (expected \(expectedCount))")
    print("  V3 result: \(count == expectedCount ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 4: Sequence + IteratorProtocol, used via for-in
// Hypothesis: for-in desugaring causes extra copy (hypothesis 3)
// Result: [PENDING]
// ============================================================================

do {
    print("=== V4: for-in via Swift.Sequence ===")

    struct BitIndices: Swift.Sequence, IteratorProtocol {
        var inner: Bit.Vector.Ones.Bounded.Iterator

        init(bitmap: Bit.Vector.Bounded) {
            self.inner = bitmap.ones.makeIterator()
        }

        mutating func next() -> Bit.Index? {
            inner.next()
        }
    }

    let bitmap = makeBitmap()
    var count = 0
    for index in BitIndices(bitmap: bitmap) {
        print("  V4 got index: \(index)")
        count += 1
    }
    print("  V4 count: \(count) (expected \(expectedCount))")
    print("  V4 result: \(count == expectedCount ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 5: Iterator stored in class (reproduces working ConsumeState)
// Hypothesis: Always works — class storage doesn't copy
// Result: [PENDING]
// ============================================================================

do {
    print("=== V5: Class-stored iterator ===")

    final class ClassWrapper {
        var inner: Bit.Vector.Ones.Bounded.Iterator

        init(bitmap: Bit.Vector.Bounded) {
            self.inner = bitmap.ones.makeIterator()
        }

        func next() -> Bit.Index? {
            inner.next()
        }
    }

    let bitmap = makeBitmap()
    let wrapper = ClassWrapper(bitmap: bitmap)
    var count = 0
    while let index = wrapper.next() {
        print("  V5 got index: \(index)")
        count += 1
    }
    print("  V5 count: \(count) (expected \(expectedCount))")
    print("  V5 result: \(count == expectedCount ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 6: Separate Sequence and Iterator types (mirrors Dictionary pattern)
// Hypothesis: Splitting makeIterator() from next() adds an extra copy
// Result: [PENDING]
// ============================================================================

do {
    print("=== V6: Separate Sequence + Iterator (Dictionary pattern) ===")

    struct MyIterator: IteratorProtocol {
        var inner: Bit.Vector.Ones.Bounded.Iterator

        init(_ ones: Bit.Vector.Ones.Bounded) {
            self.inner = ones.makeIterator()
        }

        mutating func next() -> Bit.Index? {
            inner.next()
        }
    }

    struct MySequence: Swift.Sequence {
        let bitmap: Bit.Vector.Bounded

        func makeIterator() -> MyIterator {
            MyIterator(bitmap.ones)
        }
    }

    let bitmap = makeBitmap()
    var count = 0
    for index in MySequence(bitmap: bitmap) {
        print("  V6 got index: \(index)")
        count += 1
    }
    print("  V6 count: \(count) (expected \(expectedCount))")
    print("  V6 result: \(count == expectedCount ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 7: borrowing func makeIterator() (hypothesis 4)
// Hypothesis: The `borrowing` calling convention on makeIterator() causes
//             the returned iterator to be in a bad state
// Result: [PENDING]
// ============================================================================

do {
    print("=== V7: borrowing func makeIterator() ===")

    struct BorrowingIterator: IteratorProtocol {
        var inner: Bit.Vector.Ones.Bounded.Iterator

        init(_ ones: Bit.Vector.Ones.Bounded) {
            self.inner = ones.makeIterator()
        }

        mutating func next() -> Bit.Index? {
            inner.next()
        }
    }

    struct BorrowingSequence: Swift.Sequence {
        let bitmap: Bit.Vector.Bounded

        borrowing func makeIterator() -> BorrowingIterator {
            BorrowingIterator(bitmap.ones)
        }
    }

    let bitmap = makeBitmap()
    var count = 0
    for index in BorrowingSequence(bitmap: bitmap) {
        print("  V7 got index: \(index)")
        count += 1
    }
    print("  V7 count: \(count) (expected \(expectedCount))")
    print("  V7 result: \(count == expectedCount ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 8: forEach via Ones.Bounded directly (known working path)
// Hypothesis: Always works — this is the path that works in production
// Result: [PENDING]
// ============================================================================

do {
    print("=== V8: forEach on Bit.Vector.Ones.Bounded directly ===")
    let bitmap = makeBitmap()
    var count = 0
    bitmap.ones.forEach { index in
        print("  V8 got index: \(index)")
        count += 1
    }
    print("  V8 count: \(count) (expected \(expectedCount))")
    print("  V8 result: \(count == expectedCount ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 9: Extra copy between creation and first next()
// Hypothesis: An explicit copy of the iterator resets _currentWord
// Result: [PENDING]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

do {
    print("=== V9: Explicit copy between creation and next() ===")
    let bitmap = makeBitmap()
    var iterator = bitmap.ones.makeIterator()
    // Force an explicit copy
    var copy = iterator
    var count = 0
    while let index = copy.next() {
        print("  V9 got index: \(index)")
        count += 1
    }
    print("  V9 count: \(count) (expected \(expectedCount))")
    print("  V9 result: \(count == expectedCount ? "PASS" : "FAIL")")
    // Also check the original wasn't consumed
    var origCount = 0
    while let _ = iterator.next() {
        origCount += 1
    }
    print("  V9 original count: \(origCount) (expected \(expectedCount))")
    print()
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("=== RESULTS SUMMARY ===")
print("V1 (local var):              [check output above]")
print("V2 (struct stored):          [check output above]")
print("V3 (struct + IteratorProtocol): [check output above]")
print("V4 (for-in via Sequence):    [check output above]")
print("V5 (class stored):           [check output above]")
print("V6 (separate Seq + Iter):    [check output above]")
print("V7 (borrowing makeIterator): [check output above]")
print("V8 (forEach direct):         [check output above]")
print("V9 (explicit copy):          [check output above]")
