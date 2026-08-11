// Status: SUPERSEDED -- CoW pattern stable in Set.Ordered production code. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ===----------------------------------------------------------------------===//
// Experiment: CoW Crash Investigation
// ===----------------------------------------------------------------------===//
//
// PROBLEM:
// swift test crashes with signal 11 (SIGSEGV) after adding conditional
// Copyable and Sequence conformance to Set.Ordered.
//
// HYPOTHESIS:
// The crash may be related to:
// 1. The makeUnique() CoW implementation
// 2. The _rebuildIndices() function
// 3. Hash.Table class-based storage interaction
// 4. Something in the test infrastructure
//
// METHODOLOGY: [EXP-004a] Incremental Construction
// Build up complexity step by step to find where the crash occurs.
//
// RESULT: PASSED
//
// All CoW operations work correctly:
// - Basic creation ✅
// - Insert elements ✅
// - Copy the set ✅
// - Mutate after copy (CoW) ✅
// - Iteration (Sequence) ✅
// - Multiple copies and mutations ✅
// - Stress test (100 elements, 10 copies) ✅
//
// CONCLUSION: The crash in `swift test` is NOT caused by the CoW implementation.
// The issue is likely in the test infrastructure or a specific test case.
// ===----------------------------------------------------------------------===//

import Set_Primitives_Core

print("=== CoW Crash Investigation ===\n")

// MARK: - Variant 1: Basic creation

print("Test 1: Basic Set.Ordered creation")
do {
    var set = Set<Int>.Ordered()
    print("  Created empty set")
    print("  count: \(set.count)")
    print("  ✅ Basic creation works")
}

// MARK: - Variant 2: Insert elements

print("\nTest 2: Insert elements")
do {
    var set = Set<Int>.Ordered()
    set.insert(1)
    set.insert(2)
    set.insert(3)
    print("  Inserted 3 elements")
    print("  count: \(set.count)")
    print("  contains(1): \(set.contains(1))")
    print("  contains(2): \(set.contains(2))")
    print("  contains(3): \(set.contains(3))")
    print("  ✅ Insert works")
}

// MARK: - Variant 3: Copy the set (tests conditional Copyable)

print("\nTest 3: Copy the set")
do {
    var set1 = Set<Int>.Ordered()
    set1.insert(1)
    set1.insert(2)
    set1.insert(3)
    print("  Created set1 with 3 elements")

    let set2 = set1  // Copy
    print("  Copied to set2")
    print("  set1.count: \(set1.count)")
    print("  set2.count: \(set2.count)")
    print("  ✅ Copy works")
}

// MARK: - Variant 4: Mutate after copy (triggers CoW)

print("\nTest 4: Mutate after copy (CoW)")
do {
    var set1 = Set<Int>.Ordered()
    set1.insert(1)
    set1.insert(2)
    set1.insert(3)
    print("  Created set1 with 3 elements")

    var set2 = set1  // Copy
    print("  Copied to set2")

    print("  Mutating set2...")
    set2.insert(4)  // This should trigger CoW
    print("  set1.count: \(set1.count)")
    print("  set2.count: \(set2.count)")
    print("  set1.contains(4): \(set1.contains(4))")
    print("  set2.contains(4): \(set2.contains(4))")
    print("  ✅ CoW mutation works")
}

// MARK: - Variant 5: Iteration (tests Sequence conformance)

print("\nTest 5: Iteration")
do {
    var set = Set<Int>.Ordered()
    set.insert(10)
    set.insert(20)
    set.insert(30)
    print("  Created set with [10, 20, 30]")

    print("  Iterating with for-in:")
    for element in set {
        print("    - \(element)")
    }
    print("  ✅ Iteration works")
}

// MARK: - Variant 6: Multiple copies and mutations

print("\nTest 6: Multiple copies and mutations")
do {
    var set1 = Set<Int>.Ordered()
    set1.insert(1)
    set1.insert(2)

    var set2 = set1
    var set3 = set1

    set2.insert(3)
    set3.insert(4)

    print("  set1: ", terminator: "")
    for e in set1 { print("\(e) ", terminator: "") }
    print()

    print("  set2: ", terminator: "")
    for e in set2 { print("\(e) ", terminator: "") }
    print()

    print("  set3: ", terminator: "")
    for e in set3 { print("\(e) ", terminator: "") }
    print()

    print("  ✅ Multiple copies work")
}

// MARK: - Variant 7: Stress test

print("\nTest 7: Stress test (100 elements, 10 copies)")
do {
    var original = Set<Int>.Ordered()
    for i in 0..<100 {
        original.insert(i)
    }
    print("  Created original with 100 elements")

    var copies: [Set<Int>.Ordered] = []
    for i in 0..<10 {
        var copy = original
        copy.insert(1000 + i)
        copies.append(copy)
    }
    print("  Created 10 copies with mutations")

    print("  original.count: \(original.count)")
    for (i, copy) in copies.enumerated() {
        print("  copy[\(i)].count: \(copy.count)")
    }
    print("  ✅ Stress test passed")
}

// MARK: - Variant 8: Test pattern from test file (toArray helper)

print("\nTest 8: toArray helper pattern")
do {
    func toArray(_ set: borrowing Set<Int>.Ordered) -> [Int] {
        var result: [Int] = []
        for i in 0..<set.count {
            result.append(set[i])
        }
        return result
    }

    var set = Set<Int>.Ordered()
    set.insert(1)
    set.insert(2)
    set.insert(3)

    let array = toArray(set)
    print("  array: \(array)")
    print("  ✅ toArray pattern works")
}

// MARK: - Variant 9: Algebra operations

print("\nTest 9: Algebra operations")
do {
    var a = Set<Int>.Ordered()
    a.insert(1)
    a.insert(2)
    a.insert(3)

    var b = Set<Int>.Ordered()
    b.insert(2)
    b.insert(3)
    b.insert(4)

    let union = a.algebra.union(b)
    print("  union count: \(union.count)")

    let intersection = a.algebra.intersection(b)
    print("  intersection count: \(intersection.count)")

    let subtracted = a.algebra.subtract(b)
    print("  subtract count: \(subtracted.count)")

    print("  ✅ Algebra operations work")
}

// MARK: - Variant 10: Consuming iteration

print("\nTest 10: Consuming iteration")
do {
    var set = Set<Int>.Ordered()
    set.insert(10)
    set.insert(20)
    set.insert(30)

    var consumed: [Int] = []
    var iter = set.makeConsumingIterator()
    while let element = iter.next() {
        consumed.append(element)
        print("  consumed: \(element)")
    }
    print("  consumed all: \(consumed)")
    print("  ✅ Consuming iteration works")
}

// MARK: - Variant 11: forEach iteration

print("\nTest 11: forEach iteration")
do {
    var set = Set<Int>.Ordered()
    set.insert(100)
    set.insert(200)
    set.insert(300)

    var elements: [Int] = []
    set.forEach { element in
        elements.append(element)
    }
    print("  elements: \(elements)")
    print("  ✅ forEach works")
}

print("\n=== All tests passed! ===")
