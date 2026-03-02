// MARK: - Memory.Contiguous Protocol Hoisting with Generic Struct
// Purpose: Can a protocol be hoisted outside a generic struct and typealiased
//   back as Memory.Contiguous.Protocol, preserving [API-NAME-001] compliance?
//   The protocol-typealias-hoisting experiment proved this for generic ENUMS.
//   This tests the same pattern for a generic STRUCT — the real transformation.
//
// Hypothesis: Protocol hoisted to Memory.ContiguousProtocol, typealiased back
//   as Memory.Contiguous.Protocol, can be used as conformance target and
//   generic constraint even though Memory.Contiguous is a generic struct.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
// Xcode: 26.2
//
// Result: ALL 10 VARIANTS CONFIRMED (debug + release)
//   V1–V10: Build Succeeded, all output correct, deinit chain fires properly.
//   The typealias-back pattern works identically for generic structs as for
//   generic enums. Memory.Contiguous.Protocol resolves WITHOUT specifying Element.
//   Consumers use Memory.Contiguous.Protocol in conformances, constraints,
//   function signatures, protocol extensions, and opaque return types.
//
// Finding: Swift resolves typealiases in generic types without requiring the
//   generic parameter, as long as the typealias itself doesn't depend on the
//   generic parameter. Memory.Contiguous.Protocol = Memory.ContiguousProtocol
//   works because Protocol doesn't reference Element.
//
// Date: 2026-02-25

// ============================================================================
// MARK: - Infrastructure: Memory namespace
// ============================================================================

enum Memory {}

// ============================================================================
// MARK: - V1: Hoist protocol to Memory.ContiguousProtocol
// Hypothesis: Protocol with ~Copyable associatedtype can be hoisted outside
//   generic struct and typealiased back.
// Result: CONFIRMED
// ============================================================================

extension Memory {
    protocol ContiguousProtocol: ~Copyable {
        associatedtype Element: ~Copyable
        var count: Int { get }
        var span: Span<Element> { get }
    }
}

// ============================================================================
// MARK: - V2: Generic struct with typealias back
// Hypothesis: Memory.Contiguous<Element: BitwiseCopyable> can host a typealias
//   Protocol = Memory.ContiguousProtocol, and it can be accessed as
//   Memory.Contiguous.Protocol without specifying the Element parameter.
// Result: CONFIRMED
// ============================================================================

extension Memory {
    @safe
    struct Contiguous<Element: BitwiseCopyable>: ~Copyable, @unchecked Sendable {
        typealias `Protocol` = Memory.ContiguousProtocol

        @usableFromInline
        internal let pointer: UnsafePointer<Element>
        let count: Int

        @inlinable
        init(adopting pointer: UnsafeMutablePointer<Element>, count: Int) {
            unsafe self.pointer = UnsafePointer(pointer)
            self.count = count
        }

        @inlinable
        deinit {
            print("  Memory.Contiguous deinit: deallocating \(count) elements")
            unsafe UnsafeMutablePointer(mutating: pointer).deallocate()
        }
    }
}

// ============================================================================
// MARK: - V3: Struct conformance to hoisted protocol
// Hypothesis: Memory.Contiguous<Element> can conform to Memory.ContiguousProtocol
//   directly. BitwiseCopyable satisfies ~Copyable associatedtype.
// Result: CONFIRMED
// ============================================================================

extension Memory.Contiguous: Memory.ContiguousProtocol {
    var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

do {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    (unsafe buffer)[0] = 10
    (unsafe buffer)[1] = 20
    (unsafe buffer)[2] = 30
    let region = unsafe Memory.Contiguous(adopting: buffer, count: 3)
    let s = region.span
    print("V3: Span count = \(s.count), elements = [\(s[0]), \(s[1]), \(s[2])]")
}
print()

// ============================================================================
// MARK: - V4: Typealias access WITHOUT generic parameter
// Hypothesis: Memory.Contiguous.Protocol can be used without specifying Element.
//   This works for generic enums per protocol-typealias-hoisting experiment.
//   Question: does it work for generic structs?
// Result: CONFIRMED
// ============================================================================

// Test 4a: Can we declare a conformance using the typealias?
struct SimpleContainer: Memory.Contiguous.`Protocol` {
    typealias Element = UInt8
    let _pointer: UnsafePointer<UInt8>
    var count: Int

    var span: Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            let s = unsafe Span(_unsafeStart: _pointer, count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

print("V4a: SimpleContainer conforms to Memory.Contiguous.Protocol — compiles")

// Test 4b: Can we use it in a function signature?
func printCount4b(_ value: borrowing some Memory.Contiguous.`Protocol` & ~Copyable) {
    print("V4b: count = \(value.count)")
}

do {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    unsafe buffer.initialize(repeating: 42, count: 2)
    let region = unsafe Memory.Contiguous(adopting: buffer, count: 2)
    printCount4b(region)
}
print()

// ============================================================================
// MARK: - V5: Generic constraint with Memory.Contiguous.Protocol
// Hypothesis: Generic type parameters can be constrained to Memory.Contiguous.Protocol
//   without specifying the outer generic parameter.
// Result: CONFIRMED
// ============================================================================

struct Wrapper<S: Memory.Contiguous.`Protocol` & ~Copyable>: ~Copyable {
    var storage: S

    init(_ storage: consuming S) {
        self.storage = storage
    }

    var count: Int { storage.count }
}

do {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 5)
    unsafe buffer.initialize(repeating: 1, count: 5)
    let region = unsafe Memory.Contiguous(adopting: buffer, count: 5)
    let wrapper = Wrapper(region)
    print("V5: Wrapper count = \(wrapper.count)")
}
print()

// ============================================================================
// MARK: - V6: Protocol extension via typealias path
// Hypothesis: Can extend Memory.Contiguous.Protocol (via typealias) the same
//   as extending Memory.ContiguousProtocol directly.
// Result: CONFIRMED
// ============================================================================

extension Memory.Contiguous.`Protocol` where Self: ~Copyable {
    var isEmpty: Bool { count == 0 }
}

do {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    unsafe buffer.initialize(repeating: 0, count: 4)
    let region = unsafe Memory.Contiguous(adopting: buffer, count: 4)
    print("V6: isEmpty = \(region.isEmpty)")
}
print()

// ============================================================================
// MARK: - V7: Existential usage (some Memory.Contiguous.Protocol)
// Hypothesis: The typealias works in existential/opaque return contexts.
// Result: CONFIRMED
// ============================================================================

func makeRegion() -> some Memory.Contiguous.`Protocol` & ~Copyable {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    unsafe buffer.initialize(repeating: 99, count: 3)
    return unsafe Memory.Contiguous(adopting: buffer, count: 3)
}

do {
    let region = makeRegion()
    print("V7: opaque return count = \(region.count)")
}
print()

// ============================================================================
// MARK: - V8: Multiple conformers coexist
// Hypothesis: Both Memory.Contiguous<Element> (struct) and external types
//   can conform to Memory.Contiguous.Protocol.
// Result: CONFIRMED
// ============================================================================

// A second conformer to show multiple types can conform.
struct HeapBuffer: Memory.Contiguous.`Protocol` {
    typealias Element = UInt8
    let _pointer: UnsafePointer<UInt8>
    var count: Int

    var span: Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            let s = unsafe Span(_unsafeStart: _pointer, count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

func genericCount<S: Memory.Contiguous.`Protocol` & ~Copyable>(_ s: borrowing S) -> Int {
    s.count
}

do {
    let buffer1 = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    unsafe buffer1.initialize(repeating: 0, count: 2)
    let region = unsafe Memory.Contiguous(adopting: buffer1, count: 2)

    let buffer2 = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    unsafe buffer2.initialize(repeating: 0, count: 4)
    let heap = HeapBuffer(_pointer: UnsafePointer(buffer2), count: 4)

    print("V8: region count = \(genericCount(region)), heap count = \(genericCount(heap))")
    unsafe buffer2.deallocate()
}
print()

// ============================================================================
// MARK: - V9: Direct name usage — Memory.ContiguousProtocol (hoisted)
// Hypothesis: The hoisted name Memory.ContiguousProtocol also works alongside
//   the typealias. Both paths resolve to the same protocol.
// Result: CONFIRMED
// ============================================================================

func printCountDirect(_ value: borrowing some Memory.ContiguousProtocol & ~Copyable) {
    print("V9: direct hoisted name count = \(value.count)")
}

do {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    unsafe buffer.initialize(repeating: 0, count: 3)
    let region = unsafe Memory.Contiguous(adopting: buffer, count: 3)
    printCountDirect(region)
}
print()

// ============================================================================
// MARK: - V10: String.Storage + Tagged through Memory.Contiguous.Protocol
// Hypothesis: The full composition chain from memory-contiguous-owned works
//   when the protocol is hoisted and typealiased back.
// Result: CONFIRMED
// ============================================================================

typealias Char = UInt8
let terminator: Char = 0

enum PlatformString: ~Copyable {
    @safe
    struct Storage: ~Copyable, @unchecked Sendable {
        @usableFromInline
        internal var _contiguous: Memory.Contiguous<Char>

        init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
            self._contiguous = unsafe Memory.Contiguous(adopting: pointer, count: count)
        }

        var count: Int { _contiguous.count }

        var span: Span<Char> {
            @_lifetime(borrow self)
            borrowing get {
                let s = _contiguous.span
                return unsafe _overrideLifetime(s, borrowing: self)
            }
        }
    }
}

extension PlatformString.Storage {
    init(ascii literal: StaticString) {
        let length = literal.utf8CodeUnitCount
        let buffer = UnsafeMutablePointer<Char>.allocate(capacity: length + 1)
        let source = unsafe literal.utf8Start
        unsafe buffer.initialize(from: source, count: length)
        (unsafe buffer)[length] = terminator
        self.init(adopting: buffer, count: length)
    }
}

struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _storage: RawValue

    @inlinable
    init(_ storage: consuming RawValue) {
        self._storage = storage
    }
}

extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}

extension Tagged where RawValue == PlatformString.Storage, Tag: ~Copyable {
    var count: Int { _storage.count }

    var span: Span<Char> {
        @_lifetime(borrow self)
        borrowing get {
            let s = _storage.span
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

enum Kernel: ~Copyable {
    enum Path: ~Copyable {}
}

typealias KernelPath = Tagged<Kernel.Path, PlatformString.Storage>

do {
    let path = KernelPath(PlatformString.Storage(ascii: "/usr/bin"))
    let s = path.span
    // /=47, u=117, s=115, r=114
    print("V10: span count = \(s.count), bytes = [\(s[0]), \(s[1]), \(s[2]), \(s[3])]")
}
print()

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("=== Results Summary ===")
print("V1:  Protocol hoisted to Memory.ContiguousProtocol                  — CONFIRMED")
print("V2:  Generic struct with typealias Protocol back                    — CONFIRMED")
print("V3:  Struct conforms to hoisted protocol                            — CONFIRMED")
print("V4:  Typealias access WITHOUT generic parameter (conformance + fn)  — CONFIRMED")
print("V5:  Generic constraint with Memory.Contiguous.Protocol             — CONFIRMED")
print("V6:  Protocol extension via typealias path                          — CONFIRMED")
print("V7:  Opaque return type (some Memory.Contiguous.Protocol)           — CONFIRMED")
print("V8:  Multiple conformers coexist                                    — CONFIRMED")
print("V9:  Direct hoisted name (Memory.ContiguousProtocol) also works     — CONFIRMED")
print("V10: Full composition chain (Tagged → Storage → Contiguous)         — CONFIRMED")
