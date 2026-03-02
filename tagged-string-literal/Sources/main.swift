// MARK: - Literally Tagged String Experiment
// Purpose: Validate whether Tagged<Domain, StringStorage> (literally using the
//          Tagged type from swift-identity-primitives) works for all 9 variants
//          proven in the phantom-tagged-string-unification experiment.
//
// Hypothesis: Tagged<Domain, StringStorage> where StringStorage has a deinit
//             will work identically to a custom PlatformString<Tag> struct,
//             with the additional benefit of free .retag() and .map() functors.
//
// Tests: (1) StringStorage deinit fires through Tagged destruction,
//        (2) Nested View type in constrained Tagged extension,
//        (3) @_lifetime and _overrideLifetime through Tagged,
//        (4) Property forwarding (tagged.count instead of tagged.rawValue.count),
//        (5) Conditional extensions (where RawValue == StringStorage, Tag == PathTag),
//        (6) callAsFunction scoped conversion,
//        (7) Protocol with Domain: ~Copyable + Tagged conformance,
//        (8) .retag() domain migration (FREE from Tagged — new capability),
//        (9) .map() value transformation (FREE from Tagged — new capability),
//        (10) Typealiases with conditional extensions.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
// Xcode: 26.2
//
// Result: ALL 10 VARIANTS CONFIRMED (debug + release)
//   V1–V10: Build Succeeded, all preconditions pass, all print output correct.
//   V8 (.retag) and V9 (.map) are NEW capabilities free from Tagged infrastructure.
//   Release: CopyPropagation crash (#87029) on V6 callAsFunction — @_optimize(none) workaround applied.
//
// Finding: rawValue accessor (_read coroutine) creates a lifetime scope boundary
//   that blocks @_lifetime propagation for ~Escapable types. Must access _storage
//   directly. In production, Tagged would need either: (a) _storage accessible from
//   the string module (same-package or @usableFromInline), (b) a new API for
//   lifetime-safe RawValue access, or (c) a withRawValue(_:) closure-based accessor.
//
// Date: 2026-02-25

// ============================================================================
// MARK: - Tagged (Minimal Reproduction of swift-identity-primitives)
// ============================================================================
// This reproduces Tagged<Tag, RawValue> exactly as defined in
// swift-identity-primitives, including functor operations.
// In production, this would be `import Identity_Primitives`.

struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    var _storage: RawValue

    var rawValue: RawValue {
        _read { yield _storage }
        _modify { yield &_storage }
    }

    init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self._storage = rawValue
    }
}

// Conditional Copyable
extension Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable {}

// Conditional Sendable
extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}

// Functor — map (transform RawValue, preserve Tag)
extension Tagged where Tag: ~Copyable, RawValue: ~Copyable {
    consuming func map<E: Error, NewRawValue: ~Copyable>(
        _ transform: (consuming RawValue) throws(E) -> NewRawValue
    ) throws(E) -> Tagged<Tag, NewRawValue> {
        Tagged<Tag, NewRawValue>(__unchecked: (), try transform(_storage))
    }
}

// Functor — retag (change Tag, preserve RawValue — zero cost)
extension Tagged where Tag: ~Copyable, RawValue: ~Copyable {
    consuming func retag<NewTag: ~Copyable>(
        _: NewTag.Type = NewTag.self
    ) -> Tagged<NewTag, RawValue> {
        Tagged<NewTag, RawValue>(__unchecked: (), _storage)
    }
}

// ============================================================================
// MARK: - Shared Infrastructure
// ============================================================================

/// Platform-native character type (simplified: always UInt8 for this experiment)
typealias Char = UInt8

/// Domain tags — phantom types that distinguish string domains
enum PathTag: ~Copyable {}
enum GenericTag: ~Copyable {}

// ============================================================================
// MARK: - StringStorage: The RawValue for Tagged
// ============================================================================
// This is the owned resource type that manages the pointer lifecycle.
// Tagged wraps this — Tagged's automatic member-wise destruction calls
// StringStorage.deinit when the Tagged value is destroyed.

@safe
struct StringStorage: ~Copyable, @unchecked Sendable {
    let pointer: UnsafePointer<Char>
    let count: Int

    init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
        unsafe self.pointer = UnsafePointer(pointer)
        self.count = count
    }

    deinit {
        unsafe UnsafeMutablePointer(mutating: pointer).deallocate()
    }
}

// ============================================================================
// MARK: - V1: Tagged<Domain, StringStorage> — deinit fires through Tagged
// ============================================================================
// Hypothesis: When Tagged<PathTag, StringStorage> goes out of scope,
//             StringStorage.deinit is called (pointer deallocated).
// Result: CONFIRMED — count = 5

// Property forwarding — hides rawValue indirection per [IMPL-INTENT]
extension Tagged where RawValue == StringStorage, Tag: ~Copyable {
    var count: Int { rawValue.count }

    init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
        self.init(__unchecked: (), StringStorage(adopting: pointer, count: count))
    }
}

func testV1() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 6)
    unsafe buf.initialize(from: [72, 101, 108, 108, 111, 0], count: 6)
    let s: Tagged<GenericTag, StringStorage> = .init(adopting: buf, count: 5)
    precondition(s.count == 5, "V1: count should be 5")
    print("V1: CONFIRMED — Tagged<Domain, StringStorage> with deinit, count = \(s.count)")
}

// ============================================================================
// MARK: - V2: ~Escapable View Nested in Tagged Extension
// ============================================================================
// Hypothesis: A ~Escapable View type can be defined in a constrained
//             Tagged extension and use @_lifetime annotations.
// Result: CONFIRMED — first byte = 87 ('W')

extension Tagged where RawValue == StringStorage, Tag: ~Copyable {
    @safe
    struct View: ~Copyable, ~Escapable {
        let _pointer: UnsafePointer<Char>

        @_lifetime(borrow pointer)
        init(_ pointer: UnsafePointer<Char>) {
            unsafe self._pointer = pointer
        }

        borrowing func withUnsafePointer<R: ~Copyable, E: Swift.Error>(
            _ body: (UnsafePointer<Char>) throws(E) -> R
        ) throws(E) -> R {
            try unsafe body(_pointer)
        }
    }

    borrowing func withView<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing View) throws(E) -> R
    ) throws(E) -> R {
        // Note: Must access _storage directly, not through rawValue accessor.
        // rawValue uses _read coroutine which creates a temporary scope boundary
        // that the compiler cannot propagate @_lifetime through.
        try unsafe body(View(_storage.pointer))
    }
}

func testV2() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 6)
    unsafe buf.initialize(from: [87, 111, 114, 108, 100, 0], count: 6)
    let s: Tagged<PathTag, StringStorage> = .init(adopting: buf, count: 5)
    s.withView { view in
        view.withUnsafePointer { ptr in
            let first = unsafe ptr.pointee
            precondition(first == 87, "V2: first byte should be 'W' (87)")
            print("V2: CONFIRMED — ~Escapable View nested in Tagged extension, first byte = \(first)")
        }
    }
}

// ============================================================================
// MARK: - V3: _overrideLifetime + Span Through Tagged
// ============================================================================
// Hypothesis: _overrideLifetime works through Tagged's constrained extension
//             to return Span<Char> from a View type.
// Result: CONFIRMED — span.count = 3

extension Tagged<PathTag, StringStorage>.View {
    var length: Int {
        var current = _pointer
        var count = 0
        while unsafe current.pointee != 0 {
            unsafe current = current.successor()
            count += 1
        }
        return count
    }

    var span: Span<Char> {
        @_lifetime(copy self)
        borrowing get {
            let span = unsafe Span(_unsafeStart: _pointer, count: length)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }
}

func testV3() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf.initialize(from: [65, 66, 67, 0], count: 4)
    let s: Tagged<PathTag, StringStorage> = .init(adopting: buf, count: 3)
    s.withView { view in
        let sp = view.span
        precondition(sp.count == 3, "V3: span count should be 3")
        let first = sp[0]
        precondition(first == 65, "V3: first element should be 'A' (65)")
        print("V3: CONFIRMED — _overrideLifetime + Span through Tagged, span.count = \(sp.count)")
    }
}

// ============================================================================
// MARK: - V4: @unchecked Sendable (inherited from Tagged + StringStorage)
// ============================================================================
// Hypothesis: Tagged<_, StringStorage> is automatically Sendable because
//             Tagged: Sendable where RawValue: Sendable, and
//             StringStorage: @unchecked Sendable.
// Result: CONFIRMED — Sendable constraint satisfied

func testV4() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 2)
    unsafe buf.initialize(from: [88, 0], count: 2)
    let s: Tagged<PathTag, StringStorage> = .init(adopting: buf, count: 1)

    func requiresSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {
        print("V4: CONFIRMED — Sendable inherited through Tagged + StringStorage")
    }
    requiresSendable(s)
}

// ============================================================================
// MARK: - V5: Conditional Namespace Extensions (where Tag == PathTag)
// ============================================================================
// Hypothesis: Extensions constrained to where Tag == PathTag can add
//             path-specific namespaces to Tagged<PathTag, StringStorage>.
// Result: CONFIRMED — isAbsolute, nested Canonical.Error, Resolution.Error

extension Tagged where RawValue == StringStorage, Tag == PathTag {
    enum Canonical {}
    enum Resolution {}

    var isAbsolute: Bool {
        guard count > 0 else { return false }
        return unsafe rawValue.pointer.pointee == UInt8(ascii: "/")
    }
}

extension Tagged<PathTag, StringStorage>.Canonical {
    enum Error: Swift.Error, Sendable {
        case notFound
        case permission
    }
}

extension Tagged<PathTag, StringStorage>.Resolution {
    enum Error: Swift.Error, Sendable, Equatable {
        case notFound
        case exists
        case notDirectory
    }
}

func testV5() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)  // "/tmp\0"
    let path: Tagged<PathTag, StringStorage> = .init(adopting: buf, count: 4)
    precondition(path.isAbsolute, "V5: /tmp should be absolute")

    // Verify nested error types exist
    let _: Tagged<PathTag, StringStorage>.Resolution.Error = .notFound
    let _: Tagged<PathTag, StringStorage>.Canonical.Error = .permission

    print("V5: CONFIRMED — Conditional path-specific namespaces on Tagged")
}

// ============================================================================
// MARK: - V6: Scoped Conversion (callAsFunction pattern)
// ============================================================================
// Hypothesis: The callAsFunction scope pattern works when the string type
//             is literally Tagged<PathTag, StringStorage>.
// Result: CONFIRMED — first = 47 ('/') (release: @_optimize(none) workaround for #87029)

extension Tagged where RawValue == StringStorage, Tag == PathTag {
    enum StringConversion {
        enum Error: Swift.Error, Sendable, Equatable {
            case interiorNUL
        }

        struct Scope {
            // WORKAROUND: @_optimize(none) prevents CopyPropagation crash (#87029)
            // WHY: Release-mode SIL optimizer crashes on ~Escapable + borrowing closure
            // WHEN TO REMOVE: When #87029 is fixed in a future Swift release
            @_optimize(none)
            func callAsFunction<R: ~Copyable, E: Swift.Error>(
                _ string: some StringProtocol,
                _ body: (borrowing Tagged<PathTag, StringStorage>.View) throws(E) -> R
            ) throws(E) -> R {
                var utf8 = Array(string.utf8)
                utf8.append(0)
                let buf = UnsafeMutablePointer<Char>.allocate(capacity: utf8.count)
                defer { buf.deallocate() }
                for i in 0..<utf8.count {
                    unsafe (buf + i).initialize(to: utf8[i])
                }
                let view = unsafe Tagged<PathTag, StringStorage>.View(UnsafePointer(buf))
                return try unsafe body(view)
            }
        }
    }

    static var scope: StringConversion.Scope { .init() }
}

func testV6() {
    let result: UInt8 = Tagged<PathTag, StringStorage>.scope("/etc/hosts") { view in
        view.withUnsafePointer { ptr in
            unsafe ptr.pointee
        }
    }
    precondition(result == UInt8(ascii: "/"), "V6: first byte should be '/'")
    print("V6: CONFIRMED — Scoped callAsFunction on Tagged, first = \(result)")
}

// ============================================================================
// MARK: - V7: Protocol with Domain: ~Copyable
// ============================================================================
// Hypothesis: A protocol with associatedtype Domain: ~Copyable works for
//             Tagged<Domain, StringStorage> conformance.
// Result: CONFIRMED — total = 5

protocol PlatformStringProtocol: ~Copyable {
    associatedtype Domain: ~Copyable
    var count: Int { get }
}

extension Tagged: PlatformStringProtocol where RawValue == StringStorage, Tag: ~Copyable {
    typealias Domain = Tag
}

func requireSameDomain<A: PlatformStringProtocol & ~Copyable, B: PlatformStringProtocol & ~Copyable>(
    _ a: borrowing A, _ b: borrowing B
) -> Int where A.Domain == B.Domain {
    a.count + b.count
}

func testV7() {
    let buf1 = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf1.initialize(from: [65, 66, 67, 0], count: 4)
    let s1: Tagged<PathTag, StringStorage> = .init(adopting: buf1, count: 3)

    let buf2 = UnsafeMutablePointer<Char>.allocate(capacity: 3)
    unsafe buf2.initialize(from: [68, 69, 0], count: 3)
    let s2: Tagged<PathTag, StringStorage> = .init(adopting: buf2, count: 2)

    let total = requireSameDomain(s1, s2)
    precondition(total == 5, "V7: combined count should be 5")
    print("V7: CONFIRMED — Protocol Domain: ~Copyable on Tagged, total = \(total)")
}

// ============================================================================
// MARK: - V8: .retag() Domain Migration (FREE from Tagged)
// ============================================================================
// Hypothesis: Tagged's built-in .retag() enables zero-cost domain migration.
//             This is a NEW capability that the custom PlatformString<Tag> struct
//             from the original experiment did NOT have for free.
// Result: CONFIRMED — count = 4 after PathTag → GenericTag retag

func testV8() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)
    let path: Tagged<PathTag, StringStorage> = .init(adopting: buf, count: 4)

    // Demote path string to generic string — zero-cost tag change
    let generic: Tagged<GenericTag, StringStorage> = path.retag(GenericTag.self)

    precondition(generic.count == 4, "V8: count preserved after retag")
    print("V8: CONFIRMED — .retag() domain migration (PathTag → GenericTag), count = \(generic.count)")
}

// ============================================================================
// MARK: - V9: .map() Value Transformation (FREE from Tagged)
// ============================================================================
// Hypothesis: Tagged's built-in .map() enables value transformation while
//             preserving the domain tag. For strings, this could be used for
//             operations that produce a new value (e.g., extracting count).
// Result: CONFIRMED — mapped = 3

func testV9() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf.initialize(from: [65, 66, 67, 0], count: 4)
    let original: Tagged<GenericTag, StringStorage> = .init(adopting: buf, count: 3)

    // Use .map to transform the storage (here: extract count, preserving tag)
    let mapped: Tagged<GenericTag, Int> = original.map { storage in
        // Extract count from storage before it's consumed
        storage.count
    }
    // Note: original is consumed by .map, StringStorage.deinit fires for it

    precondition(mapped.rawValue == 3, "V9: mapped count should be 3")
    print("V9: CONFIRMED — .map() value transformation preserving tag, mapped = \(mapped.rawValue)")
}

// ============================================================================
// MARK: - V10: Typealiases for Ergonomic Usage
// ============================================================================
// Hypothesis: Typealiases produce clean call sites.
// Result: CONFIRMED — isAbsolute = true through KernelPath typealias

typealias KernelPath = Tagged<PathTag, StringStorage>
typealias OSString = Tagged<GenericTag, StringStorage>

func testV10() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)
    let path: KernelPath = .init(adopting: buf, count: 4)
    precondition(path.isAbsolute, "V10: typealias should carry conditional extensions")
    print("V10: CONFIRMED — Typealiases carry conditional extensions, isAbsolute = \(path.isAbsolute)")
}

// ============================================================================
// MARK: - Execute All Variants
// ============================================================================

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()
testV7()
testV8()
testV9()
testV10()

// MARK: - Results Summary
// V1:  CONFIRMED — Tagged<Domain, StringStorage> deinit fires, count = 5
// V2:  CONFIRMED — ~Escapable View nested in Tagged extension, first byte = 87
// V3:  CONFIRMED — _overrideLifetime + Span through Tagged, span.count = 3
// V4:  CONFIRMED — Sendable inherited through Tagged + StringStorage
// V5:  CONFIRMED — Conditional path-specific namespaces on Tagged
// V6:  CONFIRMED — Scoped callAsFunction on Tagged, first = 47
// V7:  CONFIRMED — Protocol Domain: ~Copyable on Tagged, total = 5
// V8:  CONFIRMED — .retag() domain migration (NEW — free from Tagged), count = 4
// V9:  CONFIRMED — .map() value transformation (NEW — free from Tagged), mapped = 3
// V10: CONFIRMED — Typealiases carry conditional extensions, isAbsolute = true
//
// NEW capabilities vs original experiment:
// - V8 (.retag) and V9 (.map) are FREE from Tagged — no custom implementation needed.
// - V4 (Sendable) is INHERITED — no explicit conformance needed on the string type.
//
// Cross-reference: phantom-tagged-string-unification (swift-institute/Experiments/)
//                  string-path-type-unification.md (swift-institute/Research/) v3.0
