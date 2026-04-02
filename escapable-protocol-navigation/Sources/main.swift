// MARK: - ~Escapable Protocol Conformance for Navigation-Style APIs
// Purpose: Verify that a ~Copyable, ~Escapable type can conform to a protocol
//          whose requirements return Span<T> with @_lifetime annotations.
//          Determines feasibility of a Path.Navigation protocol at L1
//          implemented by platform packages.
// Hypothesis: Protocol conformance, @_lifetime in requirements, Span returns,
//             and owned ~Copyable returns all compile together.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 7 variants compile and produce correct output
// Date: 2026-04-01

// =============================================================================
// Minimal types mirroring path-primitives
// =============================================================================

struct OwnedBuffer: ~Copyable {
    let pointer: UnsafeMutablePointer<UInt8>
    let count: Int

    init(_ string: Swift.String) {
        let utf8 = Array(string.utf8)
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: utf8.count + 1)
        for i in 0..<utf8.count { unsafe (ptr[i] = utf8[i]) }
        unsafe (ptr[utf8.count] = 0)
        self.pointer = ptr
        self.count = utf8.count
    }

    init(adopting pointer: UnsafeMutablePointer<UInt8>, count: Int) {
        self.pointer = pointer
        self.count = count
    }

    deinit { pointer.deallocate() }

    var view: BufferView {
        @_lifetime(borrow self)
        borrowing get {
            let v = unsafe BufferView(pointer: UnsafePointer(pointer), count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}

struct BufferView: ~Copyable, ~Escapable {
    let pointer: UnsafePointer<UInt8>
    let count: Int

    @_lifetime(borrow pointer)
    init(pointer: UnsafePointer<UInt8>, count: Int) {
        self.pointer = pointer
        self.count = count
    }
}

// =============================================================================
// MARK: - Variant 1: ~Copyable type conforms to protocol (baseline)
// Hypothesis: A ~Copyable type can conform to a protocol with basic requirements
// =============================================================================

protocol V1Protocol: ~Copyable {
    var byteCount: Int { get }
}

extension OwnedBuffer: V1Protocol {
    var byteCount: Int { count }
}

func testVariant1() {
    let buf = OwnedBuffer("hello")
    print("V1 — ~Copyable protocol conformance: byteCount = \(buf.byteCount)")
}

// =============================================================================
// MARK: - Variant 2: ~Copyable, ~Escapable type conforms to protocol
// Hypothesis: A ~Copyable, ~Escapable type can conform to a protocol
// =============================================================================

protocol V2Protocol: ~Copyable, ~Escapable {
    var byteCount: Int { get }
}

extension BufferView: V2Protocol {
    var byteCount: Int { count }
}

func testVariant2() {
    let buf = OwnedBuffer("hello")
    let view = buf.view
    print("V2 — ~Escapable protocol conformance: byteCount = \(view.byteCount)")
}

// =============================================================================
// MARK: - Variant 3: Protocol requirement returns Span<UInt8>
// Hypothesis: A protocol can require a property returning Span with @_lifetime
// =============================================================================

protocol V3Protocol: ~Copyable, ~Escapable {
    var bytes: Span<UInt8> { @_lifetime(copy self) borrowing get }
}

extension BufferView: V3Protocol {
    var bytes: Span<UInt8> {
        @_lifetime(copy self)
        borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}

func testVariant3() {
    let buf = OwnedBuffer("/usr/bin/ls")
    let view = buf.view
    let span = view.bytes
    print("V3 — Span return from protocol: count = \(span.count)")
}

// =============================================================================
// MARK: - Variant 4: Protocol requirement returns Optional<Span<UInt8>>
// Hypothesis: Optional<Span> works as protocol requirement return type
// =============================================================================

protocol V4Protocol: ~Copyable, ~Escapable {
    var parentBytes: Span<UInt8>? { @_lifetime(copy self) borrowing get }
}

extension BufferView: V4Protocol {
    var parentBytes: Span<UInt8>? {
        @_lifetime(copy self)
        borrowing get {
            var lastSep = -1
            for i in 0..<count {
                if unsafe pointer[i] == 0x2F { lastSep = i }
            }
            guard lastSep >= 0 else { return nil }
            if lastSep == 0 && count == 1 { return nil }
            let parentCount = lastSep == 0 ? 1 : lastSep
            let s = unsafe Span(_unsafeStart: pointer, count: parentCount)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}

func testVariant4() {
    let buf = OwnedBuffer("/usr/bin/ls")
    let view = buf.view
    if let parent = view.parentBytes {
        print("V4 — Optional<Span> from protocol: parent count = \(parent.count)")
    } else {
        print("V4 — FAILED: parent was nil")
    }

    let root = OwnedBuffer("/")
    let rootView = root.view
    print("V4 — Root parent is nil: \(rootView.parentBytes == nil)")
}

// =============================================================================
// MARK: - Variant 5: Protocol requirement returns owned ~Copyable value
// Hypothesis: A borrowing method on ~Escapable protocol can return owned ~Copyable
// =============================================================================

protocol V5Protocol: ~Copyable, ~Escapable {
    borrowing func appending(_ other: borrowing Self) -> OwnedBuffer
}

extension BufferView: V5Protocol {
    borrowing func appending(_ other: borrowing BufferView) -> OwnedBuffer {
        let totalCount = count + 1 + other.count
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalCount + 1)
        unsafe buffer.initialize(from: pointer, count: count)
        (unsafe buffer)[count] = 0x2F
        unsafe (buffer + count + 1).initialize(from: other.pointer, count: other.count)
        (unsafe buffer)[totalCount] = 0
        return OwnedBuffer(adopting: buffer, count: totalCount)
    }
}

func testVariant5() {
    let a = OwnedBuffer("usr")
    let b = OwnedBuffer("bin")
    let result = a.view.appending(b.view)
    var str = ""
    for i in 0..<result.count {
        str.append(Character(UnicodeScalar(unsafe result.pointer[i])))
    }
    print("V5 — Owned return from protocol: \(str)")
}

// =============================================================================
// MARK: - Variant 6: Full Navigation protocol (all three methods)
// Hypothesis: Complete Path.Navigation protocol compiles end-to-end
// =============================================================================

protocol NavigationProtocol: ~Copyable, ~Escapable {
    associatedtype Char
    var parentBytes: Span<Char>? { @_lifetime(copy self) borrowing get }
    var lastComponentBytes: Span<Char> { @_lifetime(copy self) borrowing get }
    borrowing func appending(_ other: borrowing Self) -> OwnedBuffer
}

extension BufferView: NavigationProtocol {
    typealias Char = UInt8

    var lastComponentBytes: Span<UInt8> {
        @_lifetime(copy self)
        borrowing get {
            var lastSep = -1
            for i in 0..<count {
                if unsafe pointer[i] == 0x2F { lastSep = i }
            }
            guard lastSep >= 0 else {
                let s = unsafe Span(_unsafeStart: pointer, count: count)
                return unsafe _overrideLifetime(s, copying: self)
            }
            let offset = lastSep + 1
            let s = unsafe Span(_unsafeStart: pointer + offset, count: count - offset)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}

func testVariant6() {
    let buf = OwnedBuffer("/usr/bin/ls")
    let view = buf.view

    if let parent = view.parentBytes {
        var pStr = ""
        for i in 0..<parent.count { pStr.append(Character(UnicodeScalar(parent[i]))) }
        print("V6 — parentBytes: \(pStr)")
    }

    let component = view.lastComponentBytes
    var cStr = ""
    for i in 0..<component.count { cStr.append(Character(UnicodeScalar(component[i]))) }
    print("V6 — lastComponentBytes: \(cStr)")

    let base = OwnedBuffer("usr")
    let ext = OwnedBuffer("local")
    let joined = base.view.appending(ext.view)
    var jStr = ""
    for i in 0..<joined.count { jStr.append(Character(UnicodeScalar(unsafe joined.pointer[i]))) }
    print("V6 — appending: \(jStr)")
}

// =============================================================================
// MARK: - Variant 7: Generic function constrained by protocol
// Hypothesis: Can write generic code over NavigationProtocol
// =============================================================================

func decompose<V: NavigationProtocol & ~Copyable & ~Escapable>(
    _ view: borrowing V
) where V.Char == UInt8 {
    if let parent = view.parentBytes {
        print("V7 — Generic parent count: \(parent.count)")
    } else {
        print("V7 — Generic: no parent")
    }
    print("V7 — Generic component count: \(view.lastComponentBytes.count)")
}

func testVariant7() {
    let buf = OwnedBuffer("/usr/bin/ls")
    decompose(buf.view)
}

// =============================================================================
// MARK: - Run All
// =============================================================================

print("=== Experiment: escapable-protocol-navigation ===")
testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5()
testVariant6()
testVariant7()
print("=== Done ===")

// MARK: - Results Summary
// V1: CONFIRMED — ~Copyable protocol conformance (baseline)
// V2: CONFIRMED — ~Copyable, ~Escapable protocol conformance
// V3: CONFIRMED — Span return from protocol requirement (@_lifetime(copy self))
// V4: CONFIRMED — Optional<Span> return from protocol requirement
// V5: CONFIRMED — Owned ~Copyable return from borrowing ~Escapable protocol method
// V6: CONFIRMED — Full NavigationProtocol (parentBytes + lastComponentBytes + appending + associatedtype)
// V7: CONFIRMED — Generic function constrained by NavigationProtocol (borrowing ~Escapable generic param)
