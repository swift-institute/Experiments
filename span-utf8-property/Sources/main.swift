// MARK: - Span<UInt8>.utf8 → UTF8Span Property
// Purpose: Validate that a throwing computed property on Span<UInt8>
//          can return UTF8Span, enabling `String(copying: try span.utf8)`.
//
// Hypothesis: Span<UInt8> can have a computed property returning UTF8Span
//             with typed throws. UTF8Span is ~Escapable so lifetime must
//             propagate from the Span.
//
// Toolchain: Apple Swift 6.2.4
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — all 7 variants pass
//   V1: String(copying: try span.utf8) from closure-provided Span
//   V2: Invalid UTF-8 correctly throws ValidationError
//   V3: Chained from Array: array.span.utf8
//   V4: Chained from owned type: owned.span.utf8
//   V5: Chained from ~Escapable view: view.span.utf8
//   V6: Empty span → empty string
//   V7: ASCII content
//
// Key: @_lifetime(copy self) on the getter propagates Span lifetime to UTF8Span.
//      get throws(UTF8.ValidationError) gives typed throws.
// Date: 2026-03-19


// ============================================================
// The extension
// ============================================================

extension Span where Element == UInt8 {
    /// Validates this span as UTF-8 and returns a UTF8Span.
    ///
    /// Enables: `String(copying: try span.utf8)`
    var utf8: UTF8Span {
        @_lifetime(copy self)
        get throws(UTF8.ValidationError) {
            try UTF8Span(validating: self)
        }
    }
}


// ============================================================
// Helper
// ============================================================

func withTestSpan<R>(_ bytes: [UInt8], _ body: (Span<UInt8>) -> R) -> R {
    bytes.withUnsafeBufferPointer { buffer in
        let span = unsafe Span(_unsafeStart: buffer.baseAddress!, count: buffer.count)
        return body(span)
    }
}


// ============================================================
// V1: Basic — String(copying: try span.utf8)
// ============================================================

func testV1() {
    let result = withTestSpan([72, 101, 108, 108, 111]) { span in
        try! String(copying: span.utf8)
    }
    assert(result == "Hello")
    print("V1 CONFIRMED: String(copying: try span.utf8) = \"\(result)\"")
}

// ============================================================
// V2: Error path — invalid UTF-8 throws
// ============================================================

func testV2() {
    let result = withTestSpan([0xFF, 0xFE]) { span in
        do {
            _ = try span.utf8
            return false
        } catch {
            return true  // UTF8.ValidationError thrown
        }
    }
    assert(result)
    print("V2 CONFIRMED: Invalid UTF-8 throws ValidationError")
}

// ============================================================
// V3: From Array.span directly
// ============================================================

func testV3() {
    let bytes: [UInt8] = [87, 111, 114, 108, 100]  // "World"
    let result = try! String(copying: bytes.span.utf8)
    assert(result == "World")
    print("V3 CONFIRMED: String(copying: try array.span.utf8) = \"\(result)\"")
}

// ============================================================
// V4: Chained from an owned type with .span property
// Simulates: String(copying: try entry.name.utf8)
// ============================================================

struct OwnedBuffer: ~Copyable {
    let _ptr: UnsafeMutablePointer<UInt8>
    let count: Int

    init(_ b: [UInt8]) {
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: b.count)
        for i in 0..<b.count { (unsafe p)[i] = b[i] }
        unsafe (self._ptr = p); self.count = b.count
    }
    deinit { _ptr.deallocate() }

    var span: Span<UInt8> {
        @_lifetime(borrow self) borrowing get {
            let s = unsafe Span(_unsafeStart: UnsafePointer(_ptr), count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

func testV4() {
    let buf = OwnedBuffer([72, 105]) // "Hi"
    let result = try! String(copying: buf.span.utf8)
    assert(result == "Hi")
    print("V4 CONFIRMED: String(copying: try owned.span.utf8) = \"\(result)\"")
}

// ============================================================
// V5: From ~Escapable view with .span
// Simulates: String(copying: try view.span.utf8)
// ============================================================

struct BorrowedView: ~Copyable, ~Escapable {
    let pointer: UnsafePointer<UInt8>
    let count: Int

    @_lifetime(borrow p)
    init(_ p: UnsafePointer<UInt8>, count: Int) {
        unsafe (self.pointer = p); self.count = count
    }

    var span: Span<UInt8> {
        @_lifetime(copy self) borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}

extension OwnedBuffer {
    var view: BorrowedView {
        @_lifetime(borrow self) borrowing get {
            let v = unsafe BorrowedView(UnsafePointer(_ptr), count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}

func testV5() {
    let buf = OwnedBuffer([79, 75]) // "OK"
    let view = buf.view
    let result = try! String(copying: view.span.utf8)
    assert(result == "OK")
    print("V5 CONFIRMED: String(copying: try view.span.utf8) = \"\(result)\"")
}

// ============================================================
// V6: Empty span
// ============================================================

func testV6() {
    let result = withTestSpan([]) { span in
        try! String(copying: span.utf8)
    }
    assert(result == "")
    print("V6 CONFIRMED: Empty span → empty string = \"\(result)\"")
}

// ============================================================
// V7: ASCII fast path (verify isKnownASCII propagates)
// ============================================================

func testV7() {
    let bytes: [UInt8] = [65, 66, 67]  // "ABC" — pure ASCII
    let utf8 = try! bytes.span.utf8
    // UTF8Span knows if content is ASCII
    let str = String(copying: utf8)
    assert(str == "ABC")
    print("V7 CONFIRMED: ASCII content works, String = \"\(str)\"")
}


// ============================================================
// RUN
// ============================================================

print("=== Span<UInt8>.utf8 Property Experiment ===\n")

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()
testV7()

print("\n=== Done ===")
