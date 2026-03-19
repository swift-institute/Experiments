// ============================================================
// with-closure-to-property-migration — Consumer module
//
// Tests all property-based access patterns at call sites.
// Each V* function exercises a specific gap from the analysis.
//
// Gaps tested:
//   A — Path.view property (~Copyable owner → ~Escapable View)
//   B — Region.span property (Copyable owner → ~Escapable Span)
//   C — Region.mutableSpan (MutableSpan from property)
//   D — Cross-module ~Escapable chaining
//   E — Call-site ergonomics (let-binding, direct pass, sequential use)
//   F — Scale pattern (multiple operations on same ~Escapable value)
// ============================================================

import Primitives
import Foundations


// ============================================================
// V1: ~Copyable owner → ~Escapable View property (Gap A)
// Mirrors: Path.view replacing Path.withView { }
// ============================================================

func testV1() {
    let buf = OwnedBuffer([72, 101, 108, 108, 111])  // "Hello"
    let view = buf.view
    assert(view.count == 5)
    print("V1 CONFIRMED: ~Copyable owner → ~Escapable View property")
}

// ============================================================
// V2: ~Copyable owner → Span property
// Mirrors: Path.span / String.span
// ============================================================

func testV2() {
    let buf = OwnedBuffer([1, 2, 3, 4, 5])
    let span = buf.span
    assert(span[0] == 1)
    assert(span[4] == 5)
    print("V2 CONFIRMED: ~Copyable owner → Span property")
}

// ============================================================
// V3: View.span — two-level ~Escapable chain
// owner.view (→ ~Escapable) .span (→ ~Escapable)
// ============================================================

func testV3() {
    let buf = OwnedBuffer([10, 20, 30])
    let view = buf.view
    let span = view.span
    assert(span[0] == 10)
    assert(span[2] == 30)
    print("V3 CONFIRMED: Two-level ~Escapable chain (view → span)")
}

// ============================================================
// V4: Copyable owner → ~Escapable Span (Gap B)
// Mirrors: Kernel.Memory.Map.Region.withSpan → .span
// Key question: @_lifetime(borrow self) on Copyable type
// ============================================================

func testV4() {
    let memory = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    defer { memory.deallocate() }
    (unsafe memory)[0] = 42; (unsafe memory)[1] = 43; (unsafe memory)[2] = 44
    let region = unsafe MappedRegion(base: memory, length: 3)
    let span = region.span
    assert(span[0] == 42)
    assert(span[2] == 44)
    print("V4 CONFIRMED: Copyable owner → ~Escapable Span (Gap B)")
}

// ============================================================
// V4nil: Copyable owner with nil base → empty Span
// Edge case: _overrideLifetime on empty Span
// ============================================================

func testV4nil() {
    let region = MappedRegion(base: nil, length: 0)
    let span = region.span
    assert(span.count == 0)
    print("V4nil CONFIRMED: Nil base → empty Span")
}

// ============================================================
// V5a: MutableSpan via borrowing get (Gap C, option A)
// Tests: Can a borrowing getter return MutableSpan?
// ============================================================

func testV5a_read() {
    let memory = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    defer { memory.deallocate() }
    (unsafe memory)[0] = 1; (unsafe memory)[1] = 2; (unsafe memory)[2] = 3
    let region = unsafe MappedRegion(base: memory, length: 3)
    let ms = region.mutableSpanGet
    assert(ms[0] == 1)
    print("V5a CONFIRMED: MutableSpan via borrowing get (read)")
}

// V5a write: Can we write through a MutableSpan from a borrowing get?
// This may fail if MutableSpan subscript set is mutating.
// If it fails to compile, comment out and note BLOCKED.
func testV5a_write() {
    let memory = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    defer { memory.deallocate() }
    (unsafe memory)[0] = 1; (unsafe memory)[1] = 2; (unsafe memory)[2] = 3
    let region = unsafe MappedRegion(base: memory, length: 3)
    var ms = region.mutableSpanGet
    ms[0] = 99
    assert((unsafe memory)[0] == 99)
    print("V5a_write CONFIRMED: MutableSpan write via borrowing get")
}

// ============================================================
// V5b: MutableSpan via _modify (Gap C, option B)
// Tests: Can _modify yield a ~Escapable MutableSpan?
// Requires var self at call site.
// ============================================================

func testV5b() {
    let memory = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    defer { memory.deallocate() }
    (unsafe memory)[0] = 1; (unsafe memory)[1] = 2; (unsafe memory)[2] = 3
    var region = unsafe MappedRegion(base: memory, length: 3)
    region.mutableSpanModify[0] = 88
    assert((unsafe memory)[0] == 88)
    print("V5b CONFIRMED: MutableSpan via _modify (write)")
}

// ============================================================
// V6: ~Escapable owner → Span properties (Gap A variant)
// Mirrors: Entry.withName → .name, Entry.withValue → .value
// Key: ~Escapable struct returning ~Escapable Span
// ============================================================

func testV6() {
    let nameData = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    let valueData = UnsafeMutablePointer<UInt8>.allocate(capacity: 6)
    defer { nameData.deallocate(); valueData.deallocate() }
    // "HOME"
    (unsafe nameData)[0] = 72; (unsafe nameData)[1] = 79
    (unsafe nameData)[2] = 77; (unsafe nameData)[3] = 69
    // "/Users"
    (unsafe valueData)[0] = 47; (unsafe valueData)[1] = 85
    (unsafe valueData)[2] = 115; (unsafe valueData)[3] = 101
    (unsafe valueData)[4] = 114; (unsafe valueData)[5] = 115

    let entry = unsafe EnvironmentEntry(
        name: UnsafePointer(nameData), nameLength: 4,
        value: UnsafePointer(valueData), valueLength: 6
    )
    let name = entry.name
    assert(name.count == 4)
    assert(name[0] == 72)  // 'H'
    let value = entry.value
    assert(value.count == 6)
    assert(value[0] == 47)  // '/'
    print("V6 CONFIRMED: ~Escapable owner → Span properties")
}

// ============================================================
// V7a: Cross-module ~Escapable return (Gap D)
// Foundations.FoundationPath.view returns Primitives.BorrowedView
// ============================================================

func testV7a() {
    let path = FoundationPath([47, 116, 109, 112])  // "/tmp"
    let view = path.view
    assert(view.count == 4)
    assert(view.span[0] == 47)  // '/'
    print("V7a CONFIRMED: Cross-module ~Escapable view (Gap D)")
}

// ============================================================
// V7b: Two-hop ~Escapable bridge (Gap D)
// FoundationPath → OwnedBuffer.view → BridgedView
// Mirrors: Path.withKernelPath { } → Path.kernelView
// ============================================================

func testV7b() {
    let path = FoundationPath([47, 116, 109, 112])
    let bv = path.bridgedView
    assert(bv.count == 4)
    assert(bv.span[0] == 47)
    print("V7b CONFIRMED: Two-hop ~Escapable bridge (Gap D)")
}

// ============================================================
// V7c: Cross-module three-level Span chain (Gap D)
// FoundationPath → OwnedBuffer.view → BorrowedView.span
// ============================================================

func testV7c() {
    let path = FoundationPath([65, 66, 67])
    let span = path.span
    assert(span.count == 3)
    assert(span[0] == 65)  // 'A'
    print("V7c CONFIRMED: Cross-module three-level Span chain (Gap D)")
}

// ============================================================
// V8: Direct pass to function — no let-binding (Gap E)
// ============================================================

func consumeView(_ view: borrowing BorrowedView) -> Int { view.count }

func testV8() {
    let buf = OwnedBuffer([1, 2, 3])
    let n = consumeView(buf.view)
    assert(n == 3)
    print("V8 CONFIRMED: Direct pass to function (Gap E)")
}

// ============================================================
// V9: Multiple sequential uses of same ~Escapable (Gap F)
// Mirrors: file-system code doing multiple ops with kernelPath
// ============================================================

func operation1(_ view: borrowing BorrowedView) -> Int { view.count }
func operation2(_ view: borrowing BorrowedView) -> UInt8 { view.span[0] }

func testV9() {
    let buf = OwnedBuffer([5, 6, 7])
    let view = buf.view
    let count = operation1(view)
    let first = operation2(view)
    assert(count == 3)
    assert(first == 5)
    print("V9 CONFIRMED: Multiple sequential uses (Gap F)")
}

// ============================================================
// V10: Trivial public property (no lifetime features)
// Mirrors: FileHandle.withDescriptor → .descriptor
// ============================================================

func testV10() {
    let handle = FileHandle(descriptor: 42)
    assert(handle.descriptor == 42)
    print("V10 CONFIRMED: Public descriptor property (trivial)")
}


// ============================================================
// RUN ALL
// ============================================================

print("=== with-closure-to-property-migration ===\n")

testV1()
testV2()
testV3()
testV4()
testV4nil()
testV5a_read()
testV5a_write()
testV5b()
testV6()
testV7a()
testV7b()
testV7c()
testV8()
testV9()
testV10()

runStressTests()
runNegativeTests()

print("\n=== All variants passed ===")
