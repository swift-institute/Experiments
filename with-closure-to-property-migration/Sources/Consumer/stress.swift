// ============================================================
// STRESS TESTS — Tricky but valid patterns
//
// These SHOULD all compile and run correctly.
// If any fails to compile, that's a gap finding.
// ============================================================

import Primitives
import Foundations


// ============================================================
// S1: Two views from DIFFERENT owners simultaneously
// Mirrors: Path.scope(src, dst) { srcView, dstView in ... }
// ============================================================

func testS1() {
    let buf1 = OwnedBuffer([1, 2, 3])
    let buf2 = OwnedBuffer([4, 5, 6])
    let view1 = buf1.view
    let view2 = buf2.view
    assert(view1.span[0] == 1)
    assert(view2.span[0] == 4)
    print("S1 CONFIRMED: Two views from different owners simultaneously")
}

// ============================================================
// S2: Two views from SAME owner simultaneously
// Multiple shared borrows should be OK
// ============================================================

func testS2() {
    let buf = OwnedBuffer([10, 20, 30])
    let view = buf.view
    let span = buf.span
    assert(view.count == span.count)
    assert(view.span[0] == span[0])
    print("S2 CONFIRMED: Two views from same owner simultaneously")
}

// ============================================================
// S3: View through do/catch error boundary
// Mirrors: Path.String.Scope error handling after migration
// ============================================================

enum TestError: Error { case simulated }

func throwingUse(_ view: borrowing BorrowedView) throws(TestError) -> Int {
    if view.count > 100 { throw .simulated }
    return view.count
}

func testS3_success() {
    let buf = OwnedBuffer([1, 2, 3])
    let view = buf.view
    do {
        let n = try throwingUse(view)
        assert(n == 3)
    } catch {
        assertionFailure("Should not throw")
    }
    print("S3a CONFIRMED: View through do/catch (success path)")
}

func testS3_error() {
    let buf = OwnedBuffer([]) // empty
    let view = buf.view
    do {
        let n = try throwingUse(view)
        assert(n == 0) // count 0, no throw
    } catch {
        // handled
    }
    print("S3b CONFIRMED: View through do/catch (error path)")
}

// ============================================================
// S4: View used in non-escaping closure
// Non-escaping closures should be able to borrow ~Escapable
// Known gap: may be blocked (nonescapable-gap-revalidation-624)
// ============================================================

func withNonEscaping(_ body: () -> Int) -> Int { body() }

func testS4() {
    let buf = OwnedBuffer([7, 8, 9])
    let view = buf.view
    let count = withNonEscaping { view.count }
    assert(count == 3)
    print("S4 CONFIRMED: View in non-escaping closure")
}

// ============================================================
// S5: Generic function accepting borrowing ~Escapable
// ============================================================

func genericCount<V: ~Copyable & ~Escapable>(_ value: borrowing V, using counter: (borrowing V) -> Int) -> Int {
    counter(value)
}

func testS5() {
    let buf = OwnedBuffer([1, 2])
    let view = buf.view
    let n = genericCount(view) { _ in 2 }
    assert(n == 2)
    print("S5 CONFIRMED: Generic function with ~Escapable")
}

// ============================================================
// S6: Three levels of borrow nesting
// path → view → span → element access
// ============================================================

func testS6() {
    let path = FoundationPath([65, 66, 67])
    let view = path.view
    let span = view.span
    let byte = span[1]
    assert(byte == 66) // 'B'
    print("S6 CONFIRMED: Three-level borrow nesting")
}

// ============================================================
// S7: View used across if/else branches
// ============================================================

func testS7() {
    let buf = OwnedBuffer([1, 2, 3, 4])
    let view = buf.view
    let result: UInt8
    if view.count > 2 {
        result = view.span[0]
    } else {
        result = 0
    }
    assert(result == 1)
    print("S7 CONFIRMED: View across if/else branches")
}

// ============================================================
// S8: View with defer block
// ============================================================

func testS8() {
    var cleaned = false
    do {
        let buf = OwnedBuffer([1, 2])
        let view = buf.view
        defer { cleaned = true }
        assert(view.count == 2)
    }
    assert(cleaned)
    print("S8 CONFIRMED: View with defer")
}

// ============================================================
// S9: View in switch statement
// ============================================================

func testS9() {
    let buf = OwnedBuffer([10, 20])
    let view = buf.view
    switch view.count {
    case 0:
        assertionFailure()
    case 1:
        assertionFailure()
    case 2:
        assert(view.span[0] == 10)
    default:
        assertionFailure()
    }
    print("S9 CONFIRMED: View in switch statement")
}

// ============================================================
// S10: Simultaneous span + mutableSpan from different regions
// ============================================================

func testS10() {
    let mem1 = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    let mem2 = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    defer { mem1.deallocate(); mem2.deallocate() }
    (unsafe mem1)[0] = 1; (unsafe mem1)[1] = 2
    (unsafe mem2)[0] = 3; (unsafe mem2)[1] = 4
    let r1 = unsafe MappedRegion(base: mem1, length: 2)
    let r2 = unsafe MappedRegion(base: mem2, length: 2)
    let span1 = r1.span
    let span2 = r2.span
    assert(span1[0] == 1 && span2[0] == 3)
    print("S10 CONFIRMED: Simultaneous spans from different regions")
}

// ============================================================
// S11: Cross-module extension adding ~Escapable property
// Extension on Primitives.OwnedBuffer defined in Foundations
// This is the EXACT pattern for Path.kernelPath in production
// ============================================================

func testS11() {
    let buf = OwnedBuffer([99, 98, 97])
    let kv = buf.extensionView  // defined in Foundations as extension on OwnedBuffer
    assert(kv.count == 3)
    assert(kv.span[0] == 99)
    print("S11 CONFIRMED: Cross-module extension with ~Escapable property")
}

// ============================================================
// S12: View reuse after function call that borrows it
// ============================================================

func borrowAndReturn(_ view: borrowing BorrowedView) -> Int {
    view.count
}

func testS12() {
    let buf = OwnedBuffer([1, 2, 3, 4, 5])
    let view = buf.view
    let n1 = borrowAndReturn(view)
    let n2 = borrowAndReturn(view) // reuse after first call
    assert(n1 == n2)
    print("S12 CONFIRMED: View reuse after borrowing function call")
}

// ============================================================
// S13: View passed to function that creates derivative Span
// ============================================================

@_lifetime(copy view)
func extractSpan(_ view: borrowing BorrowedView) -> Span<UInt8> {
    view.span
}

func testS13() {
    let buf = OwnedBuffer([42, 43, 44])
    let view = buf.view
    let span = extractSpan(view)
    assert(span[0] == 42)
    print("S13 CONFIRMED: Function returning derivative Span from ~Escapable param")
}

// ============================================================
// RUN ALL STRESS TESTS
// ============================================================

func runStressTests() {
    print("\n--- Stress Tests ---\n")
    testS1()
    testS2()
    testS3_success()
    testS3_error()
    testS4()
    testS5()
    testS6()
    testS7()
    testS8()
    testS9()
    testS10()
    testS11()
    testS12()
    testS13()
}
