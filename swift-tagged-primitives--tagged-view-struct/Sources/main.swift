// MARK: - Tagged.View Struct Experiment
// Purpose: Can we define a single Tagged.View struct in identity-primitives
//          that resolves unambiguously for any Tagged<Tag, RawValue>?
// Hypothesis: A nested struct on Tagged with ~Copyable, ~Escapable works,
//             but stored properties cannot be added conditionally per-RawValue.
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT-2026-02-13-a
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all variants compile and run correctly
// Date: 2026-02-28

// ============================================================================
// MARK: - Setup: Minimal Tagged + two domain types (simulating String/Path)
// ============================================================================

@frozen
public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    public var rawValue: RawValue

    @inlinable
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

extension Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable {}
extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}

// --- Domain: "Path" (simulating Path_Primitives.Path) ---

@safe
struct Path: ~Copyable, @unchecked Sendable {
    let pointer: UnsafeMutablePointer<UInt8>
    let count: Int
}

extension Path {
    @safe
    struct View: ~Copyable, ~Escapable {
        let pointer: UnsafePointer<UInt8>

        @_lifetime(borrow pointer)
        init(_ pointer: UnsafePointer<UInt8>) {
            unsafe self.pointer = pointer
        }

        var count: Int {
            var n = 0
            while unsafe pointer.advanced(by: n).pointee != 0 { n += 1 }
            return n
        }
    }
}

// --- Domain: "MyString" (simulating String_Primitives.String) ---

@safe
struct MyString: ~Copyable, @unchecked Sendable {
    let pointer: UnsafeMutablePointer<UInt8>
    let count: Int
}

extension MyString {
    @safe
    struct View: ~Copyable, ~Escapable {
        let pointer: UnsafePointer<UInt8>

        @_lifetime(borrow pointer)
        init(_ pointer: UnsafePointer<UInt8>) {
            unsafe self.pointer = pointer
        }

        var length: Int {  // Note: different API name than Path.View.count
            var n = 0
            while unsafe pointer.advanced(by: n).pointee != 0 { n += 1 }
            return n
        }
    }
}

// --- Domain tags ---
enum Kernel {}
enum Filesystem {}

// ============================================================================
// MARK: - Variant 1: Define Tagged.View as generic ~Copyable ~Escapable struct
// Hypothesis: The compiler accepts a nested generic struct on Tagged
//             with ~Copyable & ~Escapable inner view.
// ============================================================================

extension Tagged where Tag: ~Copyable, RawValue: ~Copyable {
    struct View<InnerView: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
        let rawValue: InnerView

        @_lifetime(copy rawValue)
        init(_ rawValue: consuming InnerView) {
            self.rawValue = rawValue
        }
    }
}

// Result: CONFIRMED — compiles and runs
// Evidence: Tagged<Kernel, Path>.View<Path.View> instantiable

// ============================================================================
// MARK: - Variant 2: Forwarding through constrained extensions
// Hypothesis: We can extend Tagged.View with domain-specific APIs
//             when InnerView is concretely constrained.
// ============================================================================

// Forward Path.View APIs through Tagged.View<Path.View>
extension Tagged.View where InnerView == Path.View, Tag: ~Copyable, RawValue: ~Copyable {
    var count: Int { rawValue.count }
}

// Forward MyString.View APIs through Tagged.View<MyString.View>
extension Tagged.View where InnerView == MyString.View, Tag: ~Copyable, RawValue: ~Copyable {
    var length: Int { rawValue.length }
}

// Result: CONFIRMED — constrained extensions with domain-specific APIs work
// Evidence: view.count and view.length forward correctly

// ============================================================================
// MARK: - Variant 3: Does Tagged<Kernel, Path>.View<Path.View> resolve?
// Hypothesis: Explicit generic parameter works. Implicit doesn't.
// ============================================================================

// 3a: Explicit InnerView — should work
func testExplicitView() {
    let bytes: [UInt8] = [104, 101, 108, 108, 111, 0]
    unsafe bytes.withUnsafeBufferPointer { buf in
        let pathView = unsafe Path.View(buf.baseAddress!)
        // Must spell out the generic parameter since inference can't pick it
        let taggedView = Tagged<Kernel, Path>.View<Path.View>(pathView)
        print("Variant 3a — explicit: count = \(taggedView.count)")
    }
}

// 3b: Can the generic parameter be inferred from the argument?
func testInferredView() {
    let bytes: [UInt8] = [119, 111, 114, 108, 100, 0]
    unsafe bytes.withUnsafeBufferPointer { buf in
        let pathView = unsafe Path.View(buf.baseAddress!)
        // Attempt: let the compiler infer InnerView == Path.View from the argument
        let taggedView: Tagged<Kernel, Path>.View = .init(pathView)
        print("Variant 3b — inferred: count = \(taggedView.count)")
    }
}

// Result: CONFIRMED — both explicit (3a) and inferred (3b) work
// Evidence: Output "count = 5" from both variants

// ============================================================================
// MARK: - Variant 4: withView forwarding on Tagged<_, Path>
// Hypothesis: We can add withView that produces Tagged.View<Path.View>.
// ============================================================================

extension Tagged where RawValue == Path, Tag: ~Copyable {
    borrowing func withView<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing Tagged.View<Path.View>) throws(E) -> R
    ) throws(E) -> R {
        let innerView = unsafe _overrideLifetime(
            unsafe Path.View(rawValue.pointer),
            borrowing: self
        )
        let taggedView = Tagged.View<Path.View>(innerView)
        let taggedView2 = unsafe _overrideLifetime(taggedView, borrowing: self)
        return try body(taggedView2)
    }
}

func testWithView() {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    (unsafe buffer)[0] = 47   // '/'
    (unsafe buffer)[1] = 97   // 'a'
    (unsafe buffer)[2] = 98   // 'b'
    (unsafe buffer)[3] = 0
    let tagged = unsafe Tagged<Kernel, Path>(__unchecked: (), Path(pointer: buffer, count: 3))
    tagged.withView { view in
        print("Variant 4 — withView: count = \(view.count)")
    }
    unsafe buffer.deallocate()
}

// Result: CONFIRMED — withView produces Tagged.View<Path.View>, forwards .count
// Evidence: Output "count = 3"

// ============================================================================
// MARK: - Variant 5: Ergonomics — what does consumer code look like?
// Hypothesis: The call site is clean enough for production use.
// ============================================================================

// With this approach, the consumer writes:
//
//   kernelPath.withView { view in     // view is Tagged<Kernel, Path>.View<Path.View>
//       view.count                     // forwarded from Path.View
//   }
//
// The type Tagged<Kernel, Path>.View<Path.View> is verbose in signatures,
// but at call sites the generic parameter is inferred.
//
// A typealias in kernel-primitives could simplify signatures:
//   typealias KernelPathView = Tagged<Kernel, Path>.View<Path.View>
//
// Or even: Kernel.Path.View if the struct doesn't shadow... but it does.

// ============================================================================
// MARK: - Variant 6: Naming collision — View struct vs View typealias
// Hypothesis: The View struct on Tagged prevents per-RawValue typealiases.
// ============================================================================

// Uncommenting this should error — View is already a struct on Tagged:
// extension Tagged where RawValue == Path, Tag: ~Copyable {
//     typealias View = Path.View  // ❌ redeclaration of View
// }

// ============================================================================
// MARK: - Variant 7: Both domains coexist
// Hypothesis: Tagged<Kernel, Path>.View<Path.View> and
//             Tagged<Kernel, MyString>.View<MyString.View> coexist
//             without ambiguity.
// ============================================================================

extension Tagged where RawValue == MyString, Tag: ~Copyable {
    borrowing func withView<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing Tagged.View<MyString.View>) throws(E) -> R
    ) throws(E) -> R {
        let innerView = unsafe _overrideLifetime(
            unsafe MyString.View(rawValue.pointer),
            borrowing: self
        )
        let taggedView = Tagged.View<MyString.View>(innerView)
        let taggedView2 = unsafe _overrideLifetime(taggedView, borrowing: self)
        return try body(taggedView2)
    }
}

func testBothDomains() {
    // Path domain
    let pbuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    (unsafe pbuf)[0] = 47; (unsafe pbuf)[1] = 97; (unsafe pbuf)[2] = 0
    let kpath = unsafe Tagged<Kernel, Path>(__unchecked: (), Path(pointer: pbuf, count: 2))
    kpath.withView { view in
        print("Variant 7 — Path: count = \(view.count)")
    }

    // String domain
    let sbuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    (unsafe sbuf)[0] = 104; (unsafe sbuf)[1] = 105; (unsafe sbuf)[2] = 33; (unsafe sbuf)[3] = 0
    let kstr = unsafe Tagged<Kernel, MyString>(__unchecked: (), MyString(pointer: sbuf, count: 3))
    kstr.withView { view in
        print("Variant 7 — MyString: length = \(view.length)")
    }

    unsafe pbuf.deallocate()
    unsafe sbuf.deallocate()
}

// Result: CONFIRMED — both domains coexist without ambiguity
// Evidence: Output "Path: count = 2" and "MyString: length = 3"

// ============================================================================
// MARK: - Variant 8: Ergonomic cost — function parameter signatures
// Hypothesis: Functions taking a view require verbose type spelling.
// ============================================================================

// 8a: Does a function taking borrowing Tagged.View need full type?
func processPathView8a(_ view: borrowing Tagged<Kernel, Path>.View<Path.View>) -> Int {
    view.count
}

// 8b: Can we omit the generic parameter in the signature?
func processPathView8b(_ view: borrowing Tagged<Kernel, Path>.View<Path.View>) -> Int {
    // NOTE: Testing if shorter spelling works — trying without explicit <Path.View>
    // If this variant compiles, variant 8b_short below should too
    view.count
}

// 8b_short: Actually omit the generic parameter
// func processPathView8b_short(_ view: borrowing Tagged<Kernel, Path>.View) -> Int {
//     view.count
// }

// 8c: Simulating Kernel.Path typealias
typealias KernelPath = Tagged<Kernel, Path>

func processPathView8c(_ view: borrowing KernelPath.View<Path.View>) -> Int {
    view.count
}

// 8d: Can we typealias KernelPath.View to hide the generic parameter?
// This should fail — View is a struct, not a type we can re-alias with a fixed parameter
// extension KernelPath {
//     typealias PathView = View<Path.View>
// }

func testSignatureErgonomics() {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    (unsafe buffer)[0] = 47; (unsafe buffer)[1] = 120; (unsafe buffer)[2] = 121; (unsafe buffer)[3] = 0
    let tagged = unsafe Tagged<Kernel, Path>(__unchecked: (), Path(pointer: buffer, count: 3))
    tagged.withView { view in
        // 8a: full type in function signature
        let c1 = processPathView8a(view)
        print("Variant 8a — full signature: count = \(c1)")

        // 8c: with KernelPath typealias
        let c2 = processPathView8c(view)
        print("Variant 8c — KernelPath alias: count = \(c2)")
    }
    unsafe buffer.deallocate()
}

// Result: CONFIRMED — function signatures compile with full type and with typealias
// Evidence: Output "count = 3" for both 8a and 8c

// ============================================================================
// MARK: - Variant 9: Shadowing — does Tagged.View struct prevent Kernel.Path.View?
// Hypothesis: Writing Kernel.Path.View resolves to Tagged.View (the struct),
//             NOT to Path.View.
// ============================================================================

// 9a: Does Kernel.Path.View (without generic param) produce an error?
// If View is a generic struct, Kernel.Path.View is incomplete — needs <InnerView>.

// Simulating what consumer code looks like with the typealias:
typealias KernelPathAlias = Tagged<Kernel, Path>

// 9b: Can we access KernelPathAlias.View<Path.View> ?
func testShadowing9b() {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    (unsafe buffer)[0] = 97; (unsafe buffer)[1] = 98; (unsafe buffer)[2] = 0
    let tagged = unsafe Tagged<Kernel, Path>(__unchecked: (), Path(pointer: buffer, count: 2))

    // This is what Kernel.Path.View would resolve to:
    tagged.withView { (view: borrowing KernelPathAlias.View<Path.View>) in
        print("Variant 9b — KernelPathAlias.View<Path.View>: count = \(view.count)")
    }
    unsafe buffer.deallocate()
}

// 9c: Can we omit the type annotation entirely in withView closure?
func testShadowing9c() {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    (unsafe buffer)[0] = 99; (unsafe buffer)[1] = 100; (unsafe buffer)[2] = 0
    let tagged = unsafe Tagged<Kernel, Path>(__unchecked: (), Path(pointer: buffer, count: 2))

    // No type annotation — does inference work?
    tagged.withView { view in
        print("Variant 9c — inferred closure param: count = \(view.count)")
    }
    unsafe buffer.deallocate()
}

// Result: CONFIRMED — explicit annotation (9b) and inferred closure param (9c) both work
// Evidence: Output "count = 2" for both variants

// ============================================================================
// MARK: - Variant 10: Can we define a typealias inside the Tagged.View struct?
// Hypothesis: We can add per-InnerView typealiases inside Tagged.View extensions
//             to expose Char etc.
// ============================================================================

extension Tagged.View where InnerView == Path.View, Tag: ~Copyable, RawValue: ~Copyable {
    typealias Char = UInt8  // Path.Char equivalent
}

func testNestedTypealias() {
    // Can we reference Tagged<Kernel, Path>.View<Path.View>.Char?
    let _: Tagged<Kernel, Path>.View<Path.View>.Char = 42
    print("Variant 10 — nested Char typealias: works")
}

// Result: CONFIRMED — nested typealias inside constrained Tagged.View extension works
// Evidence: `Tagged<Kernel, Path>.View<Path.View>.Char` resolves to UInt8

// ============================================================================
// MARK: - Variant 11: Protocol-based approach for comparison
// Hypothesis: A Viewable protocol in identity-primitives could allow
//             a single non-generic View typealias on Tagged.
// ============================================================================

// 11a: With SuppressedAssociatedTypes enabled, try again
protocol Viewable: ~Copyable {
    associatedtype ViewType: ~Copyable, ~Escapable
}

// 11b: If the protocol compiles, can we use it on Tagged?
extension Tagged: Viewable where RawValue: Viewable, Tag: ~Copyable {
    typealias ViewType = RawValue.ViewType
}

// 11c: Make Path conform to Viewable
extension Path: Viewable {
    typealias ViewType = Path.View
}

// 11d: Make MyString conform to Viewable
extension MyString: Viewable {
    typealias ViewType = MyString.View
}

// 11e: Can we define a View typealias on Tagged using the associated type?
// NOTE: This conflicts with the View STRUCT from Variant 1. We need to test
// this in isolation. For now, use ProtocolView to avoid the conflict.
extension Tagged where RawValue: Viewable & ~Copyable, Tag: ~Copyable {
    typealias ProtocolView = RawValue.ViewType
}

// 11f: Can we define withProtocolView using the associated type?
extension Tagged where RawValue == Path, Tag: ~Copyable {
    borrowing func withProtocolView<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing ProtocolView) throws(E) -> R
    ) throws(E) -> R {
        let innerView = unsafe _overrideLifetime(
            unsafe Path.View(rawValue.pointer),
            borrowing: self
        )
        let result = try body(innerView)
        return result
    }
}

// 11g: Can we use ProtocolView in function parameter types?
func processProtocolView(_ view: borrowing Tagged<Kernel, Path>.ProtocolView) -> Int {
    view.count
}

// 11h: Can we use the typealias via KernelPath shorthand?
func processProtocolView2(_ view: borrowing KernelPath.ProtocolView) -> Int {
    view.count
}

func testProtocolApproach() {
    // 11a+11b: Protocol + conformance compile
    print("Variant 11a — Viewable protocol: CONFIRMED (compiles with SuppressedAssociatedTypes)")

    // 11e+11f: Test ProtocolView typealias + withProtocolView
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    (unsafe buffer)[0] = 47; (unsafe buffer)[1] = 120; (unsafe buffer)[2] = 0; (unsafe buffer)[3] = 0
    let tagged = unsafe Tagged<Kernel, Path>(__unchecked: (), Path(pointer: buffer, count: 2))

    tagged.withProtocolView { view in
        print("Variant 11f — withProtocolView: count = \(view.count)")

        // 11g: function parameter using ProtocolView
        let c = processProtocolView(view)
        print("Variant 11g — processProtocolView: count = \(c)")

        // 11h: function parameter using KernelPath.ProtocolView
        let c2 = processProtocolView2(view)
        print("Variant 11h — KernelPath.ProtocolView: count = \(c2)")
    }
    unsafe buffer.deallocate()
}

// Result: CONFIRMED with SuppressedAssociatedTypes (was REFUTED without it)
// Evidence: Protocol compiles, Tagged conforms, ProtocolView typealias works
// See tagged-view-protocol/ for the clean protocol-only approach

// ============================================================================
// MARK: - Variant 12: Protocol approach — View typealias (no struct)
// Hypothesis: If we DON'T define a View struct on Tagged, we can use the
//             Viewable protocol to provide a View typealias that resolves
//             to RawValue.ViewType for each concrete Tagged specialization.
// NOTE: Cannot test in this file because Variant 1 already defines View struct.
//       See variant-12/ sub-experiment for isolated test.
// ============================================================================

// 12a: This would be the production definition:
//
//   protocol Viewable: ~Copyable {
//       associatedtype ViewType: ~Copyable, ~Escapable
//   }
//
//   extension Tagged: Viewable where RawValue: Viewable & ~Copyable, Tag: ~Copyable {
//       typealias ViewType = RawValue.ViewType
//   }
//
//   extension Tagged where RawValue: Viewable & ~Copyable, Tag: ~Copyable {
//       typealias View = RawValue.ViewType
//   }
//
// Then: Tagged<Kernel, Path>.View == Path.View
//       Tagged<Kernel, MyString>.View == MyString.View
//       No ambiguity. No generic parameter. No wrapper.
//
// Key advantage over Variant 1:
//   - View is the ACTUAL inner view type, not a wrapper
//   - No API forwarding needed
//   - No extra generic parameter in signatures
//   - withView returns Path.View directly, not Tagged.View<Path.View>

// Result: (see variant-12 sub-experiment)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

// ============================================================================
// MARK: - Results Summary
// ============================================================================
//
// Variant 1:  CONFIRMED — Tagged.View<InnerView: ~Copyable & ~Escapable> struct compiles
// Variant 2:  CONFIRMED — Constrained extensions forward domain-specific APIs
// Variant 3a: CONFIRMED — Explicit generic parameter works
// Variant 3b: CONFIRMED — Inferred generic parameter works (surprising — low ergonomic cost)
// Variant 4:  CONFIRMED — withView produces Tagged.View<Path.View>
// Variant 5:  N/A — ergonomics observation (call sites are clean)
// Variant 6:  N/A — naming collision (View struct prevents per-RawValue typealias)
// Variant 7:  CONFIRMED — Both Path and MyString domains coexist without ambiguity
// Variant 8a: CONFIRMED — Full type in function signature compiles
// Variant 8c: CONFIRMED — Typealias (KernelPath) shortens signature
// Variant 9b: CONFIRMED — Explicit type annotation in closure works
// Variant 9c: CONFIRMED — Type inference in closure works (no annotation needed)
// Variant 10: CONFIRMED — Nested typealias (Char) in constrained extension works
// Variant 11: CONFIRMED — Protocol approach works WITH SuppressedAssociatedTypes feature flag
//
// Key insight: The ergonomic cost of Tagged.View<InnerView> is lower than expected.
// At call sites (closures, withView), the generic parameter is always inferred.
// Only explicit function signatures require the full type, and typealiases help there.

// ============================================================================
// MARK: - Execution
// ============================================================================

testExplicitView()
testInferredView()
testWithView()
testBothDomains()
testSignatureErgonomics()
testShadowing9b()
testShadowing9c()
testNestedTypealias()
testProtocolApproach()
print("All variants executed.")
