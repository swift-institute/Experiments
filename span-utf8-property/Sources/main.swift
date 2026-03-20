// MARK: - String(Span<UInt8>) Init
// Purpose: Validate that a simple `String.init(_ span: Span<UInt8>)`
//          with typed throws works as the canonical Span → String path.
//
// Toolchain: Apple Swift 6.2.4
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — all 8 variants pass
//   Extension: String.init(_ span: Span<UInt8>) throws(UTF8.ValidationError)
//   Body: self = String(copying: try UTF8Span(validating: span))
//   V1-V8: basic, error path, array.span, owned.span, view.span, empty, emoji, production pattern
// Date: 2026-03-19


// ============================================================
// The extension — one init, nothing else
// ============================================================

extension Swift.String {
    init(_ span: Span<UInt8>) throws(UTF8.ValidationError) {
        self = String(copying: try UTF8Span(validating: span))
    }
}


// ============================================================
// Helper
// ============================================================

func withSpan<R>(_ bytes: [UInt8], _ body: (Span<UInt8>) -> R) -> R {
    bytes.withUnsafeBufferPointer { buf in
        let span = unsafe Span(_unsafeStart: buf.baseAddress!, count: buf.count)
        return body(span)
    }
}

struct Owned: ~Copyable {
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

struct View: ~Copyable, ~Escapable {
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

extension Owned {
    var view: View {
        @_lifetime(borrow self) borrowing get {
            let v = unsafe View(UnsafePointer(_ptr), count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}


// ============================================================
// V1: try String(span) — basic
// ============================================================

func testV1() {
    let s = withSpan([72, 101, 108, 108, 111]) { try! String($0) }
    assert(s == "Hello")
    print("V1 CONFIRMED: try String(span) = \"\(s)\"")
}

// ============================================================
// V2: Invalid UTF-8 throws
// ============================================================

func testV2() {
    let threw = withSpan([0xFF, 0xFE]) { span in
        do { _ = try String(span); return false }
        catch { return true }
    }
    assert(threw)
    print("V2 CONFIRMED: Invalid UTF-8 throws")
}

// ============================================================
// V3: try String(array.span)
// ============================================================

func testV3() {
    let bytes: [UInt8] = [87, 111, 114, 108, 100]
    let s = try! String(bytes.span)
    assert(s == "World")
    print("V3 CONFIRMED: try String(array.span) = \"\(s)\"")
}

// ============================================================
// V4: try String(owned.span)
// ============================================================

func testV4() {
    let buf = Owned([72, 105])
    let s = try! String(buf.span)
    assert(s == "Hi")
    print("V4 CONFIRMED: try String(owned.span) = \"\(s)\"")
}

// ============================================================
// V5: try String(view.span)
// ============================================================

func testV5() {
    let buf = Owned([79, 75])
    let view = buf.view
    let s = try! String(view.span)
    assert(s == "OK")
    print("V5 CONFIRMED: try String(view.span) = \"\(s)\"")
}

// ============================================================
// V6: Empty span
// ============================================================

func testV6() {
    let s = withSpan([]) { try! String($0) }
    assert(s == "")
    print("V6 CONFIRMED: Empty span → \"\"")
}

// ============================================================
// V7: Multi-byte UTF-8 (emoji)
// ============================================================

func testV7() {
    // 👋 = F0 9F 91 8B
    let s = withSpan([0xF0, 0x9F, 0x91, 0x8B]) { try! String($0) }
    assert(s == "👋")
    print("V7 CONFIRMED: Multi-byte UTF-8 = \"\(s)\"")
}

// ============================================================
// V8: The actual production pattern — entry.name equivalent
// ============================================================

func testV8() {
    let buf = Owned([47, 85, 115, 101, 114, 115]) // "/Users"
    // Simulates: let name = try String(entry.name)
    let name = try! String(buf.span)
    assert(name == "/Users")
    print("V8 CONFIRMED: Production pattern = \"\(name)\"")
}


// ============================================================
// RUN
// ============================================================

print("=== String(Span<UInt8>) Experiment ===\n")

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()
testV7()
testV8()

print("\n=== Done ===")
