// SUPERSEDED: See nonescapable-patterns
// MARK: - ContiguousProtocol with ~Escapable + @lifetime on property
// Purpose: Validate that @lifetime on protocol property requirement
//          enables the generalized ContiguousProtocol pattern where
//          both owned types AND ~Escapable views can conform.
//
// Toolchain: Apple Swift 6.2.4, 6.3-dev (Feb 6), 6.4-dev (Mar 16)
// Platform: macOS 26 (arm64)
//
// Result: MIXED
//   @lifetime on protocol PROPERTY — BLOCKED (all 3 toolchains)
//     "@lifetime attribute cannot be applied to this declaration"
//   @_lifetime on protocol METHOD — CONFIRMED (6.2.4+)
//     borrowing func span() with @_lifetime(borrow self) works
//   Workaround: ~Copyable-only protocol (no ~Escapable) with var span { get }
//     Owned types conform; views pass .span directly. CONFIRMED.
//
// Findings:
//   - @lifetime/@_lifetime on protocol properties is NOT implemented
//   - stdlib _BorrowingSequence uses @lifetime on METHOD, never property
//   - Protocol _read accessor also blocked ("expected get or set")
//   - borrowing get without annotation: "cannot infer lifetime"
//   - Existing Memory.Contiguous.Protocol (~Copyable only) is the
//     correct pattern for Swift 6.2 — views cannot conform but
//     provide .span directly
//
// Date: 2026-03-19


// ============================================================
// The protocol — property with @lifetime
// ============================================================

protocol ContiguousProtocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    @lifetime(borrow self)
    var span: Span<Element> { get }
}


// ============================================================
// V1: Owned ~Copyable type
// ============================================================

struct OwnedBuffer: ~Copyable, ContiguousProtocol {
    let _ptr: UnsafeMutablePointer<UInt8>
    let count: Int

    init(_ b: [UInt8]) {
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: b.count)
        for i in 0..<b.count { (unsafe p)[i] = b[i] }
        unsafe (self._ptr = p); self.count = b.count
    }
    deinit { _ptr.deallocate() }

    var span: Span<UInt8> {
        @lifetime(borrow self) @inlinable borrowing get {
            let s = unsafe Span(_unsafeStart: UnsafePointer(_ptr), count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }

    var view: BorrowedView {
        @lifetime(borrow self) borrowing get {
            let v = unsafe BorrowedView(UnsafePointer(_ptr), count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}


// ============================================================
// V2: ~Escapable view type
// ============================================================

struct BorrowedView: ~Copyable, ~Escapable, ContiguousProtocol {
    let pointer: UnsafePointer<UInt8>
    let count: Int

    @lifetime(borrow p)
    init(_ p: UnsafePointer<UInt8>, count: Int) {
        unsafe (self.pointer = p); self.count = count
    }

    var span: Span<UInt8> {
        @lifetime(copy self) borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}


// ============================================================
// V3: Copyable + Escapable type
// ============================================================

struct CopyableBuffer: ContiguousProtocol {
    let bytes: [UInt8]
    var span: Span<UInt8> {
        @lifetime(borrow self) borrowing get { bytes.span }
    }
}


// ============================================================
// V4: Generic functions over the protocol
// ============================================================

func genericSum<C: ContiguousProtocol & ~Copyable & ~Escapable>(
    _ source: borrowing C
) -> Int where C.Element == UInt8 {
    let s = source.span
    var sum = 0
    for i in 0..<s.count { sum += Int(s[i]) }
    return sum
}

func makeString<C: ContiguousProtocol & ~Copyable & ~Escapable>(
    _ source: borrowing C
) -> String where C.Element == UInt8 {
    String(copying: unsafe UTF8Span(unchecked: source.span))
}

func spansEqual<A: ContiguousProtocol & ~Copyable & ~Escapable,
                B: ContiguousProtocol & ~Copyable & ~Escapable>(
    _ a: borrowing A, _ b: borrowing B
) -> Bool where A.Element == UInt8, B.Element == UInt8 {
    let sa = a.span; let sb = b.span
    guard sa.count == sb.count else { return false }
    for i in 0..<sa.count { if sa[i] != sb[i] { return false } }
    return true
}


// ============================================================
// RUN
// ============================================================

print("=== ContiguousProtocol ~Escapable + @lifetime property (6.3) ===\n")

do {
    let buf = OwnedBuffer([10, 20, 30])
    assert(genericSum(buf) == 60)
    print("V1 CONFIRMED: Owned ~Copyable, sum = 60")
}
do {
    let buf = OwnedBuffer([5, 6, 7])
    let view = buf.view
    assert(genericSum(view) == 18)
    print("V2 CONFIRMED: ~Escapable view, sum = 18")
}
do {
    let cb = CopyableBuffer(bytes: [100, 50, 25])
    assert(genericSum(cb) == 175)
    print("V3 CONFIRMED: Copyable+Escapable, sum = 175")
}
do {
    let buf = OwnedBuffer([72, 101, 108, 108, 111])
    let s1 = makeString(buf)
    let view = buf.view
    let s2 = makeString(view)
    let cb = CopyableBuffer(bytes: [87, 111, 114, 108, 100])
    let s3 = makeString(cb)
    assert(s1 == "Hello" && s2 == "Hello" && s3 == "World")
    print("V4 CONFIRMED: Generic makeString — owned=\(s1) view=\(s2) copyable=\(s3)")
}
do {
    let buf = OwnedBuffer([1, 2, 3])
    let cb = CopyableBuffer(bytes: [1, 2, 3])
    assert(spansEqual(buf, cb))
    let view = buf.view
    assert(spansEqual(view, cb))
    print("V5 CONFIRMED: Cross-type generic equality")
}

print("\n=== All passed ===")
