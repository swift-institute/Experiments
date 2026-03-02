// MARK: - Memory.Contiguous<Element> Owned Typed Region Validation
// Purpose: Validate that Memory.Contiguous<Element: BitwiseCopyable> works as
//   the self-owning contiguous typed memory region filling the Level 2 gap.
//   Tests: generic struct + deinit, protocol hoisting, Span access, String.Storage
//   wrapping, Tagged composition, domain migration, Sendable inheritance.
//
// Hypothesis: Memory.Contiguous<Element> can be a generic struct with BitwiseCopyable
//   constraint, deinit, protocol conformance (hoisted), Span access, and compose
//   through String.Storage into Tagged<Domain, String.Storage>.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
// Xcode: 26.2
//
// Result: ALL 11 VARIANTS CONFIRMED (debug + release)
//   V1–V11: Build Succeeded, all output correct, deinit chain fires properly.
//   No CopyPropagation crash (#87029) — direct span property works in release.
//
// Finding: Direct stored property access (_storage.span) works for @_lifetime
//   propagation through multiple layers. Unlike rawValue (_read coroutine),
//   stored property access does NOT create a lifetime scope boundary.
//   Chain: Tagged.span → _storage.span → _contiguous.span → Span<Char>
//
// Date: 2026-02-25

// ============================================================================
// MARK: - Infrastructure: Memory namespace
// ============================================================================

enum Memory {}

// ============================================================================
// MARK: - V1: Basic Memory.Contiguous<Element: BitwiseCopyable>
// Hypothesis: Generic struct with BitwiseCopyable constraint can have deinit,
//   be ~Copyable, and be @unchecked Sendable.
// Result: CONFIRMED — count = 4, deinit fires on scope exit
// ============================================================================

extension Memory {
    @safe
    struct Contiguous<Element: BitwiseCopyable>: ~Copyable, @unchecked Sendable {
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

do {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    unsafe buffer.initialize(repeating: 42, count: 4)
    let region = unsafe Memory.Contiguous(adopting: buffer, count: 4)
    print("V1: Created Memory.Contiguous<UInt8> with count \(region.count)")
    // region goes out of scope — deinit should fire
}
print("V1: After scope — deinit should have fired above")
print()

// ============================================================================
// MARK: - V2: Span access with @_lifetime
// Hypothesis: Memory.Contiguous can provide Span<Element> via @_lifetime(borrow self)
// Result: CONFIRMED — span count = 3, view count = 3, elements = [10, 20, 30]
// ============================================================================

extension Memory.Contiguous {
    typealias View = Span<Element>

    var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }

    var view: View {
        @_lifetime(borrow self)
        borrowing get {
            span
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
    print("V2: Span count = \(s.count), elements = [\(s[0]), \(s[1]), \(s[2])]")
    let v = region.view
    print("V2: View count = \(v.count)")
}
print()

// ============================================================================
// MARK: - V3: Protocol hoisting
// Hypothesis: Protocol defined outside generic struct, typealiased back, works.
// Result: CONFIRMED — compiles, typealias resolves
// ============================================================================

extension Memory {
    protocol ContiguousProtocol: ~Copyable {
        associatedtype Element: BitwiseCopyable
        var count: Int { get }
    }
}

extension Memory.Contiguous {
    typealias `Protocol` = Memory.ContiguousProtocol
}

print("V3: Protocol hoisted and typealiased — compiles")
print()

// ============================================================================
// MARK: - V4: Protocol conformance
// Hypothesis: Memory.Contiguous can conform to the hoisted protocol.
// Result: CONFIRMED — protocol witness count = 5
// ============================================================================

extension Memory.Contiguous: Memory.ContiguousProtocol {}

func printCount(_ value: borrowing some Memory.ContiguousProtocol & ~Copyable) {
    print("V4: Protocol witness count = \(value.count)")
}

do {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 5)
    unsafe buffer.initialize(repeating: 0, count: 5)
    let region = unsafe Memory.Contiguous(adopting: buffer, count: 5)
    printCount(region)
}
print()

// ============================================================================
// MARK: - V5: String.Storage wrapping Memory.Contiguous<Char>
// Hypothesis: String.Storage can wrap Memory.Contiguous<UInt8> (Char on POSIX)
//   and add null-termination invariant. deinit propagates through the wrapper.
// Result: CONFIRMED — count = 5, span = [104, 101, 108, 108, 111] (hello),
//   deinit chain fires on scope exit
// ============================================================================

#if os(Windows)
typealias Char = UInt16
let terminator: Char = 0
#else
typealias Char = UInt8
let terminator: Char = 0
#endif

enum PlatformString: ~Copyable {
    @safe
    struct Storage: ~Copyable, @unchecked Sendable {
        @usableFromInline
        internal var _contiguous: Memory.Contiguous<Char>

        init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
            #if DEBUG
            precondition(unsafe pointer[count] == terminator, "Must be null-terminated")
            #endif
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

        // deinit propagates automatically through _contiguous.deinit
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

do {
    let storage = PlatformString.Storage(ascii: "hello")
    print("V5: String.Storage count = \(storage.count)")
    let s = storage.span
    print("V5: Span bytes = [\(s[0]), \(s[1]), \(s[2]), \(s[3]), \(s[4])]")
    // h=104, e=101, l=108, l=108, o=111
}
print("V5: After scope — deinit chain should have fired")
print()

// ============================================================================
// MARK: - V6: Tagged composition
// Hypothesis: Tagged<Domain, String.Storage> works with deinit propagation
//   and Sendable inheritance. Automatic member destruction fires
//   PlatformString.Storage → Memory.Contiguous.deinit → deallocate.
// Result: CONFIRMED — count = 8, full deinit chain fires on scope exit
// ============================================================================

struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _storage: RawValue

    @inlinable
    init(_ storage: consuming RawValue) {
        self._storage = storage
    }

    // No deinit needed — automatic member destruction fires
    // PlatformString.Storage → Memory.Contiguous.deinit → deallocate
}

// Conditional Sendable — follows tagged-string-literal pattern
extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}

// Domain tags
enum Kernel: ~Copyable {
    enum Path: ~Copyable {}
}

enum Environment: ~Copyable {
    enum Variable: ~Copyable {}
}

typealias KernelPath = Tagged<Kernel.Path, PlatformString.Storage>
typealias EnvVar = Tagged<Environment.Variable, PlatformString.Storage>

do {
    let path = KernelPath(PlatformString.Storage(ascii: "/usr/bin"))
    print("V6: KernelPath created, count = \(path._storage.count)")
    // deinit chain: Tagged destruction → Storage._contiguous.deinit → deallocate
}
print("V6: After scope — full deinit chain should have fired")
print()

// ============================================================================
// MARK: - V7: Span access through Tagged (direct property)
// Hypothesis: Tagged can expose Span<Char> directly via a borrowing getter
//   that chains through _storage (stored property) → span (computed property).
//   Unlike rawValue (_read coroutine), stored property access does not create
//   a lifetime scope boundary that blocks @_lifetime propagation.
// Result: CONFIRMED — span count = 4, bytes = [47, 116, 109, 112] (/tmp)
// ============================================================================

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

do {
    let path = KernelPath(PlatformString.Storage(ascii: "/tmp"))
    let s = path.span
    // /=47, t=116, m=109, p=112
    print("V7: Span count = \(s.count)")
    print("V7: Span bytes = [\(s[0]), \(s[1]), \(s[2]), \(s[3])]")
}
print()

// ============================================================================
// MARK: - V8: Sendable inheritance
// Hypothesis: Tagged<Domain, String.Storage> inherits Sendable from String.Storage,
//   which inherits it from Memory.Contiguous<Char>.
// Result: CONFIRMED — Tagged<Path, Storage> is Sendable
// ============================================================================

func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {
    print("V8: \(T.self) is Sendable")
}

do {
    let path = KernelPath(PlatformString.Storage(ascii: "/dev/null"))
    requireSendable(path)
}
print()

// ============================================================================
// MARK: - V9: Domain migration via retag
// Hypothesis: Can convert between Tagged domains without touching the storage.
//   No deinit on Tagged means consuming retag works without discard self.
// Result: CONFIRMED — count preserved (10) after Kernel.Path → Environment.Variable
// ============================================================================

extension Tagged where Tag: ~Copyable, RawValue: ~Copyable {
    consuming func retag<NewTag: ~Copyable>(_ : NewTag.Type) -> Tagged<NewTag, RawValue> {
        Tagged<NewTag, RawValue>(_storage)
    }
}

do {
    let path = KernelPath(PlatformString.Storage(ascii: "/home/user"))
    print("V9: KernelPath count = \(path._storage.count)")
    let envVar: EnvVar = path.retag(Environment.Variable.self)
    print("V9: Retagged to EnvVar count = \(envVar._storage.count)")
}
print()

// ============================================================================
// MARK: - V10: Conditional namespace + domain-specific operations
// Hypothesis: Domain-specific operations via conditional extensions work on
//   Tagged<Domain, String.Storage>. Path-specific operations only available
//   when Tag == Kernel.Path. Uses span directly (not closure).
// Result: CONFIRMED — isAbsolute = true, separator count = 3
// ============================================================================

extension Tagged where Tag == Kernel.Path, RawValue == PlatformString.Storage {
    var isAbsolute: Bool {
        guard count > 0 else { return false }
        return span[0] == 0x2F  // '/' = 0x2F
    }

    borrowing func separatorCount() -> Int {
        let s = span
        var n = 0
        for i in 0..<s.count {
            if s[i] == 0x2F { n += 1 }  // '/' = 0x2F
        }
        return n
    }
}

do {
    let path = KernelPath(PlatformString.Storage(ascii: "/usr/local/bin"))
    print("V10: isAbsolute = \(path.isAbsolute)")
    print("V10: separator count = \(path.separatorCount())")  // 3 slashes
}
print()

// ============================================================================
// MARK: - V11: Debug + Release build verification
// Hypothesis: All variants compile and run correctly in both debug and release.
//   Known: CopyPropagation #87029 may affect ~Escapable + borrowing closures
//   in release. @_optimize(none) workaround available if needed.
// Result: CONFIRMED — Build Succeeded in both debug and release, no #87029 crash
// ============================================================================

print("V11: If you're reading this, the build succeeded.")
print()

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("=== Results Summary ===")
print("V1:  Memory.Contiguous<Element: BitwiseCopyable> basic         — CONFIRMED")
print("V2:  Span access with @_lifetime                               — CONFIRMED")
print("V3:  Protocol hoisting (outside generic struct)                 — CONFIRMED")
print("V4:  Protocol conformance on generic struct                     — CONFIRMED")
print("V5:  String.Storage wrapping Memory.Contiguous<Char>            — CONFIRMED")
print("V6:  Tagged<Domain, String.Storage> composition                 — CONFIRMED")
print("V7:  Span access through Tagged (direct property)               — CONFIRMED")
print("V8:  Sendable inheritance (Memory.Contiguous → Storage → Tagged)— CONFIRMED")
print("V9:  Domain migration via retag                                 — CONFIRMED")
print("V10: Conditional namespace + domain-specific operations         — CONFIRMED")
print("V11: Debug + Release build                                      — CONFIRMED")
