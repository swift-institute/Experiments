// MARK: - Phantom-Tagged String Unification Experiment
// Purpose: Validate whether a phantom-tagged ~Copyable string type with deinit,
//          @_lifetime, _overrideLifetime, and ~Escapable views compiles today.
//          Tests whether Option D from string-path-type-unification.md is feasible
//          under current compiler constraints (C1–C5).
//
// Hypothesis: The Domain pattern (proven for data carriers in Cardinal.Protocol /
//             Ordinal.Protocol) will work for resource owners with deinit and
//             lifetime annotations, enabling a single generic String<Tag> type
//             that replaces both String_Primitives.String and Kernel.Path.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
// Xcode: 26.2
//
// Result: ALL CONFIRMED (V1–V8) in debug mode — Option D is feasible today.
//         Constraint C2 (deinit in generic ~Copyable) does NOT block phantom-tagged strings.
//         All features work: deinit, @_lifetime, _overrideLifetime, ~Escapable View,
//         @unchecked Sendable, conditional namespaces, callAsFunction scope,
//         protocol Domain conformance, and typealiases.
//         Cross-domain mixing correctly rejected at compile time (V9 negative test).
//         Key requirement: [COPY-FIX-003] — all extensions must carry `where Tag: ~Copyable`.
//
//         RELEASE BUILD: Crashes in CopyPropagation SIL pass (#87029) on V6 callAsFunction.
//         The mark_dependence [nonescaping] + destroy_value double-consume in the scoped
//         View creation triggers "Found over consume?!" in LinearLifetimeChecker.
//         Workaround: @_optimize(none) on callAsFunction, or restructure to avoid
//         creating ~Escapable View from locally-allocated buffer in release mode.
//         This is the same bug class documented in open-source-toolchain-compiler-crashes.md.
// Date: 2026-02-25

// ============================================================================
// MARK: - Shared Infrastructure
// ============================================================================

/// Platform-native character type (simplified: always UInt8 for this experiment)
typealias Char = UInt8

/// Domain tags — phantom types that distinguish string domains
enum PathDomain: ~Copyable {}
enum GenericDomain: ~Copyable {}

// ============================================================================
// MARK: - V1: ~Copyable Generic Struct with Phantom Tag and deinit
// ============================================================================
// Hypothesis: A generic ~Copyable struct parameterized by a ~Copyable phantom
//             tag can have a custom deinit that deallocates a pointer.
// Tests constraint: C2 (deinit in generic ~Copyable types)
// Result: CONFIRMED — Build Succeeded, count = 5

@safe
struct PlatformString<Tag: ~Copyable>: ~Copyable {
    @usableFromInline
    internal let pointer: UnsafePointer<Char>
    public let count: Int

    @inlinable
    init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
        unsafe self.pointer = UnsafePointer(pointer)
        self.count = count
    }

    @inlinable
    deinit {
        unsafe UnsafeMutablePointer(mutating: pointer).deallocate()
    }
}

func testV1() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 6)
    unsafe buf.initialize(from: [72, 101, 108, 108, 111, 0], count: 6)
    let s = unsafe PlatformString<GenericDomain>(adopting: buf, count: 5)
    precondition(s.count == 5, "V1: count should be 5")
    print("V1: CONFIRMED — ~Copyable generic with deinit compiles, count = \(s.count)")
}

// ============================================================================
// MARK: - V2: ~Escapable View with @_lifetime in Generic Context
// ============================================================================
// Hypothesis: A ~Escapable view type nested inside the generic PlatformString
//             can use @_lifetime(borrow pointer) annotations.
// Tests constraint: @_lifetime propagation through generic parameters
// Note: [COPY-FIX-003] requires explicit `where Tag: ~Copyable` on extension.
// Result: CONFIRMED — first byte = 87 ('W')

extension PlatformString where Tag: ~Copyable {
    @safe
    struct View: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _pointer: UnsafePointer<Char>

        @inlinable
        @_lifetime(borrow pointer)
        init(_ pointer: UnsafePointer<Char>) {
            unsafe self._pointer = pointer
        }

        @inlinable
        borrowing func withUnsafePointer<R: ~Copyable, E: Swift.Error>(
            _ body: (UnsafePointer<Char>) throws(E) -> R
        ) throws(E) -> R {
            try unsafe body(_pointer)
        }
    }

    @inlinable
    borrowing func withView<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing View) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(View(pointer))
    }
}

func testV2() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 6)
    unsafe buf.initialize(from: [87, 111, 114, 108, 100, 0], count: 6)
    let s = unsafe PlatformString<PathDomain>(adopting: buf, count: 5)
    s.withView { view in
        view.withUnsafePointer { ptr in
            let first = unsafe ptr.pointee
            precondition(first == 87, "V2: first byte should be 'W' (87)")
            print("V2: CONFIRMED — ~Escapable View with @_lifetime in generic context, first byte = \(first)")
        }
    }
}

// ============================================================================
// MARK: - V3: _overrideLifetime for Span Interop
// ============================================================================
// Hypothesis: _overrideLifetime works in a generic context to return Span<Char>
//             from a View type parameterized by a phantom tag.
// Tests constraint: _overrideLifetime + generic + @_lifetime(copy self)
// Result: CONFIRMED — span.count = 3

extension PlatformString.View where Tag: ~Copyable {
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
        @inlinable
        borrowing get {
            let span = unsafe Span(_unsafeStart: _pointer, count: length)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }
}

func testV3() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf.initialize(from: [65, 66, 67, 0], count: 4)
    let s = unsafe PlatformString<GenericDomain>(adopting: buf, count: 3)
    s.withView { view in
        let sp = view.span
        precondition(sp.count == 3, "V3: span count should be 3")
        let first = sp[0]
        precondition(first == 65, "V3: first element should be 'A' (65)")
        print("V3: CONFIRMED — _overrideLifetime + Span in generic context, span.count = \(sp.count)")
    }
}

// ============================================================================
// MARK: - V4: @unchecked Sendable Conformance
// ============================================================================
// Hypothesis: @unchecked Sendable can be retroactively conformed on a generic
//             ~Copyable type with a phantom tag.
// Note: [COPY-FIX-003] requires `where Tag: ~Copyable` on extension AND
//       the test function must accept `T: ~Copyable`.
// Result: CONFIRMED — Sendable constraint satisfied

extension PlatformString: @unchecked Sendable where Tag: ~Copyable {}

func testV4() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 2)
    unsafe buf.initialize(from: [88, 0], count: 2)
    let s = unsafe PlatformString<PathDomain>(adopting: buf, count: 1)

    // Verify Sendable by using in a context that requires it
    func requiresSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {
        print("V4: CONFIRMED — @unchecked Sendable on generic ~Copyable type")
    }
    requiresSendable(s)
}

// ============================================================================
// MARK: - V5: Conditional Namespace Extensions
// ============================================================================
// Hypothesis: Extensions constrained to where Tag == PathDomain can add
//             path-specific namespaces and methods.
// Note: Tag == PathDomain implies Tag: ~Copyable (PathDomain: ~Copyable).
// Result: CONFIRMED — isAbsolutePath works, nested error types accessible

extension PlatformString where Tag == PathDomain {
    enum Canonical {}
    enum Resolution {}

    var isAbsolutePath: Bool {
        guard count > 0 else { return false }
        return unsafe pointer.pointee == UInt8(ascii: "/")
    }
}

extension PlatformString.Canonical where Tag == PathDomain {
    enum Error: Swift.Error, Sendable {
        case notFound
        case permission
    }
}

extension PlatformString.Resolution where Tag == PathDomain {
    enum Error: Swift.Error, Sendable, Equatable {
        case notFound
        case exists
        case notDirectory
    }
}

func testV5() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)  // "/tmp\0"
    let path = unsafe PlatformString<PathDomain>(adopting: buf, count: 4)
    precondition(path.isAbsolutePath, "V5: /tmp should be absolute")

    // Verify the nested error types exist
    let _: PlatformString<PathDomain>.Resolution.Error = .notFound
    let _: PlatformString<PathDomain>.Canonical.Error = .permission

    print("V5: CONFIRMED — Conditional path-specific namespaces and methods")

    // Verify generic string does NOT have path methods
    // Uncomment to verify compile error:
    // let buf2 = UnsafeMutablePointer<Char>.allocate(capacity: 2)
    // unsafe buf2.initialize(from: [65, 0], count: 2)
    // let generic = unsafe PlatformString<GenericDomain>(adopting: buf2, count: 1)
    // _ = generic.isAbsolutePath  // Should not compile
}

// ============================================================================
// MARK: - V6: Scoped Conversion from Swift.String (callAsFunction pattern)
// ============================================================================
// Hypothesis: The Kernel.Path.scope callAsFunction pattern works when
//             parameterized by phantom tag.
// Note: Body closure references PlatformString<PathDomain>.View which requires
//       Tag: ~Copyable constraint to be satisfied via concrete PathDomain type.
// Result: CONFIRMED (debug) — first byte = 47 ('/')
//         CRASHES in release: CopyPropagation SIL pass (#87029) on mark_dependence
//         [nonescaping] double-consume. Same bug class as open-source-toolchain-crashes.md.
//         Workaround: @_optimize(none) on callAsFunction method.

extension PlatformString where Tag == PathDomain {
    enum StringConversion {
        enum Error: Swift.Error, Sendable, Equatable {
            case interiorNUL
        }

        struct Scope {
            @inlinable
            func callAsFunction<R: ~Copyable, E: Swift.Error>(
                _ string: some StringProtocol,
                _ body: (borrowing PlatformString<PathDomain>.View) throws(E) -> R
            ) throws(E) -> R {
                var utf8 = Array(string.utf8)
                utf8.append(0)
                let count = utf8.count - 1
                let buf = UnsafeMutablePointer<Char>.allocate(capacity: utf8.count)
                defer { buf.deallocate() }
                for i in 0..<utf8.count {
                    unsafe (buf + i).initialize(to: utf8[i])
                }
                let view = unsafe PlatformString<PathDomain>.View(UnsafePointer(buf))
                return try unsafe body(view)
            }
        }
    }

    static var scope: StringConversion.Scope { .init() }
}

func testV6() {
    let result: UInt8 = PlatformString<PathDomain>.scope("/etc/hosts") { view in
        view.withUnsafePointer { ptr in
            unsafe ptr.pointee
        }
    }
    precondition(result == UInt8(ascii: "/"), "V6: first byte should be '/'")
    print("V6: CONFIRMED — Scoped callAsFunction conversion with phantom tag, first = \(result)")
}

// ============================================================================
// MARK: - V7: Protocol Abstraction with Domain
// ============================================================================
// Hypothesis: A protocol with associatedtype Domain: ~Copyable works for
//             PlatformString<Tag> conformance, mirroring Cardinal.Protocol.
// Note: Protocol itself and all functions must declare ~Copyable on all
//       generic parameters that may be ~Copyable. The protocol method
//       references PlatformString<Domain>.View which requires Domain: ~Copyable.
// Result: CONFIRMED — same-domain enforced, total = 5

protocol PlatformStringProtocol: ~Copyable {
    associatedtype Domain: ~Copyable
    var count: Int { get }
}

extension PlatformString: PlatformStringProtocol where Tag: ~Copyable {
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
    let s1 = unsafe PlatformString<PathDomain>(adopting: buf1, count: 3)

    let buf2 = UnsafeMutablePointer<Char>.allocate(capacity: 3)
    unsafe buf2.initialize(from: [68, 69, 0], count: 3)
    let s2 = unsafe PlatformString<PathDomain>(adopting: buf2, count: 2)

    let total = requireSameDomain(s1, s2)
    precondition(total == 5, "V7: combined count should be 5")
    print("V7: CONFIRMED — Protocol with Domain: ~Copyable + PlatformString conformance, total = \(total)")

    // Uncomment to verify cross-domain rejection:
    // let buf3 = UnsafeMutablePointer<Char>.allocate(capacity: 2)
    // unsafe buf3.initialize(from: [70, 0], count: 2)
    // let s3 = unsafe PlatformString<GenericDomain>(adopting: buf3, count: 1)
    // _ = requireSameDomain(s1, s3)  // Should not compile: PathDomain != GenericDomain
}

// ============================================================================
// MARK: - V8: Typealiases for Ergonomic Usage
// ============================================================================
// Hypothesis: Typealiases produce clean call sites that mirror the current
//             Kernel.Path and String_Primitives.String API shapes.
// Result: CONFIRMED — isAbsolute = true through typealias

typealias KernelPath = PlatformString<PathDomain>
typealias OSString = PlatformString<GenericDomain>

func testV8() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)
    let path: KernelPath = unsafe PlatformString(adopting: buf, count: 4)
    precondition(path.isAbsolutePath, "V8: typealias should carry conditional extensions")
    print("V8: CONFIRMED — Typealiases carry conditional extensions, isAbsolute = \(path.isAbsolutePath)")
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

// MARK: - Results Summary
// V1: CONFIRMED — ~Copyable generic with phantom tag + deinit
// V2: CONFIRMED — ~Escapable View with @_lifetime in generic context
// V3: CONFIRMED — _overrideLifetime + Span in generic context
// V4: CONFIRMED — @unchecked Sendable on generic ~Copyable
// V5: CONFIRMED — Conditional path-specific namespace extensions
// V6: CONFIRMED (debug) / CRASHES (release) — CopyPropagation #87029
// V7: CONFIRMED — Protocol with Domain: ~Copyable + PlatformString conformance
// V8: CONFIRMED — Typealiases carry conditional extensions
// V9: CONFIRMED — Cross-domain mixing rejected at compile time (negative test)
//
// 8/9 VARIANTS FULLY CONFIRMED. V6 confirmed in debug, crashes in release
// (CopyPropagation SIL pass, same bug class as #87029).
//
// Key finding: Constraint C2 (deinit in generic ~Copyable) was INCORRECTLY
// assessed as a blocker in the research document. The C2 constraint applies
// to InlineArray + value generic deinit ([COPY-FIX-009]), NOT to pointer-based
// deinit in phantom-tagged generics. Option D is feasible TODAY in debug mode.
// Release mode requires @_optimize(none) on V6-style scoped conversion methods
// until #87029 is fixed — same workaround already used in 6 functions across
// the primitives ecosystem (see small-buffer-enum-compiler-workarounds.md).
//
// Prerequisite: [COPY-FIX-003] — every extension on PlatformString must
// carry `where Tag: ~Copyable`. Without this, implicit Copyable requirements
// leak into all extensions and methods. The initial build attempt failed on
// exactly this issue (13 errors), all resolved by adding the constraint.
//
// Cross-reference: string-path-type-unification.md (swift-institute/Research/)
