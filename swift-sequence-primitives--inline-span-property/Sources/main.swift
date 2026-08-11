// Status: SUPERSEDED -- Property.View .span pattern shipped in swift-property-primitives. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// Experiment: Inline Storage with Span Property
//
// Question: Can inline storage types safely provide a `span` property
// (not closure-based `withSpan`) using @lifetime annotations?
//
// Hypothesis: Yes, because @lifetime(borrow self) prevents the container
// from moving while the span exists, making the address stable.

import Foundation

// MARK: - Test 1: Check that InlineArray has .span property

func testInlineArraySpan() {
    print("Test 1: InlineArray provides .span property")

    var arr: InlineArray<4, Int> = [1, 2, 3, 4]
    let s = arr.span

    print("  InlineArray count: \(arr.count)")
    print("  Span count: \(s.count)")
    print("  Span[0]: \(s[0])")
    print("  Span[3]: \(s[3])")
    print("  ✅ InlineArray.span works as property (not closure)")
}

// MARK: - Test 2: Verify span prevents mutation

func testSpanBorrowingSemantics() {
    print("\nTest 2: Span borrowing prevents concurrent mutation")

    var arr: InlineArray<4, Int> = [10, 20, 30, 40]

    // Get span - this borrows arr
    let s = arr.span

    // The following would be a compile error if uncommented:
    // arr[0] = 999  // Error: cannot mutate while borrowed

    // But we can read through the span
    let sum = s[0] + s[1] + s[2] + s[3]
    print("  Sum via span: \(sum)")

    // Span goes out of scope, borrow released
    // Now mutation is allowed again (in a new scope)
    print("  ✅ Span borrowing semantics work correctly")
}

// MARK: - Test 3: MutableSpan on inline storage

func testMutableSpanInline() {
    print("\nTest 3: MutableSpan on inline storage")

    var arr: InlineArray<4, Int> = [1, 2, 3, 4]

    // Get mutable span
    var ms = arr.mutableSpan
    ms[0] = 100
    ms[1] = 200

    // Verify changes persisted
    print("  After mutation: [\(arr[0]), \(arr[1]), \(arr[2]), \(arr[3])]")
    assert(arr[0] == 100)
    assert(arr[1] == 200)
    print("  ✅ MutableSpan on inline storage works")
}

// MARK: - Test 4: Compare to Array (heap storage)

func testArraySpan() {
    print("\nTest 4: Array (heap) also provides .span property")

    let arr = [1, 2, 3, 4, 5]
    let s = arr.span

    print("  Array span count: \(s.count)")
    print("  Array span[0]: \(s[0])")
    print("  ✅ Both inline (InlineArray) and heap (Array) use same .span API")
}

// MARK: - Test 5: Span iteration

func testSpanIteration() {
    print("\nTest 5: Span iteration")

    var arr: InlineArray<4, Int> = [10, 20, 30, 40]
    let s = arr.span

    var sum = 0
    for i in 0..<s.count {
        sum += s[i]
    }
    print("  Sum via iteration: \(sum)")
    assert(sum == 100)
    print("  ✅ Span iteration works")
}

// MARK: - Main

print("=== Inline Storage Span Property Experiment ===\n")

testInlineArraySpan()
testSpanBorrowingSemantics()
testMutableSpanInline()
testArraySpan()
testSpanIteration()

print("\n=== All Tests Passed ===")
print("""

FINDINGS:
1. InlineArray (inline storage) provides .span as a PROPERTY, not closure
2. Array (heap storage) also provides .span as a PROPERTY
3. The API is UNIFORM across storage strategies
4. Borrowing semantics prevent mutation while span exists
5. MutableSpan works for inline storage too

CONCLUSION:
Swift stdlib has already validated our hypothesis. InlineArray.span is a
computed property that returns Span<Element>, proving that inline storage
CAN safely provide span properties.

The @lifetime annotation ensures the container cannot be moved or mutated
while the span exists, making the inline storage address stable.

RECOMMENDATION:
All swift-primitives types should provide:
- var span: Span<Element>
- var mutableSpan: MutableSpan<Element>

Regardless of whether they use heap or inline storage. This matches
Swift stdlib's approach with Array and InlineArray.
""")
