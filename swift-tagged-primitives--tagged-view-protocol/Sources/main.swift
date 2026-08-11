// MARK: - Tagged.View via Viewable Protocol Experiment
// Purpose: Can we define a Viewable protocol with ~Copyable ~Escapable associated type,
//          then use it to provide a View TYPEALIAS (not struct) on Tagged?
// Hypothesis: With SuppressedAssociatedTypes, the protocol approach works and
//             Tagged<Kernel, Path>.View resolves directly to Path.View.
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT-2026-02-13-a
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all variants compile and run correctly
// Date: 2026-02-28

// ============================================================================
// MARK: - Setup: Minimal Tagged + two domain types
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

// --- Domain: "Path" ---

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

// --- Domain: "MyString" ---

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

        var length: Int {
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
// MARK: - Variant 1: Viewable protocol with ~Copyable ~Escapable associatedtype
// Hypothesis: SuppressedAssociatedTypes allows this.
// ============================================================================

protocol Viewable: ~Copyable {
    associatedtype View: ~Copyable, ~Escapable
}

// Result: CONFIRMED

// ============================================================================
// MARK: - Variant 2: Concrete types conform to Viewable
// Hypothesis: Path and MyString can conform, mapping View to their inner View.
// ============================================================================

extension Path: Viewable {
    // View is already defined as Path.View — does the compiler pick it up?
}

extension MyString: Viewable {
    // View is already defined as MyString.View — compiler picks it up implicitly
}

// Result: CONFIRMED

// ============================================================================
// MARK: - Variant 3: Tagged conforms to Viewable, forwarding ViewType
// Hypothesis: Tagged<Tag, RawValue>.View == RawValue.View when RawValue: Viewable
// ============================================================================

extension Tagged: Viewable where RawValue: Viewable & ~Copyable, Tag: ~Copyable {
    typealias View = RawValue.View
}

// Result: CONFIRMED

// ============================================================================
// MARK: - Variant 4: Tagged.View resolves correctly per-RawValue
// Hypothesis: Tagged<Kernel, Path>.View == Path.View,
//             Tagged<Kernel, MyString>.View == MyString.View
// ============================================================================

func testViewResolution() {
    // Does the type system resolve correctly?
    let _: Tagged<Kernel, Path>.View.Type = Path.View.self
    let _: Tagged<Kernel, MyString>.View.Type = MyString.View.self
    print("Variant 4 — View type resolution: CONFIRMED")
}

// Result: CONFIRMED

// ============================================================================
// MARK: - Variant 5: withView returning the actual View type
// Hypothesis: withView on Tagged<_, Path> returns Path.View (not a wrapper).
// ============================================================================

extension Tagged where RawValue == Path, Tag: ~Copyable {
    borrowing func withView<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing View) throws(E) -> R
    ) throws(E) -> R {
        let innerView = unsafe _overrideLifetime(
            unsafe Path.View(rawValue.pointer),
            borrowing: self
        )
        return try body(innerView)
    }
}

extension Tagged where RawValue == MyString, Tag: ~Copyable {
    borrowing func withView<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing View) throws(E) -> R
    ) throws(E) -> R {
        let innerView = unsafe _overrideLifetime(
            unsafe MyString.View(rawValue.pointer),
            borrowing: self
        )
        return try body(innerView)
    }
}

func testWithView() {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    (unsafe buffer)[0] = 47; (unsafe buffer)[1] = 97; (unsafe buffer)[2] = 98; (unsafe buffer)[3] = 0
    let tagged = unsafe Tagged<Kernel, Path>(__unchecked: (), Path(pointer: buffer, count: 3))

    tagged.withView { view in
        // Is `view` of type Path.View? Can we call .count directly?
        print("Variant 5a — Path withView: count = \(view.count)")
    }

    let sbuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    (unsafe sbuf)[0] = 104; (unsafe sbuf)[1] = 105; (unsafe sbuf)[2] = 33; (unsafe sbuf)[3] = 0
    let kstr = unsafe Tagged<Kernel, MyString>(__unchecked: (), MyString(pointer: sbuf, count: 3))

    kstr.withView { view in
        print("Variant 5b — MyString withView: length = \(view.length)")
    }

    unsafe buffer.deallocate()
    unsafe sbuf.deallocate()
}

// Result: CONFIRMED

// ============================================================================
// MARK: - Variant 6: Function signatures using Tagged.View
// Hypothesis: Functions can take `borrowing Tagged<Kernel, Path>.View`
//             which resolves to `borrowing Path.View`.
// ============================================================================

func processPathView(_ view: borrowing Tagged<Kernel, Path>.View) -> Int {
    view.count
}

func processStringView(_ view: borrowing Tagged<Kernel, MyString>.View) -> Int {
    view.length
}

typealias KernelPath = Tagged<Kernel, Path>
typealias KernelString = Tagged<Kernel, MyString>

func processPathView2(_ view: borrowing KernelPath.View) -> Int {
    view.count
}

func testSignatures() {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
    (unsafe buffer)[0] = 47; (unsafe buffer)[1] = 120; (unsafe buffer)[2] = 121; (unsafe buffer)[3] = 0
    let tagged = unsafe Tagged<Kernel, Path>(__unchecked: (), Path(pointer: buffer, count: 3))

    tagged.withView { view in
        let c1 = processPathView(view)
        print("Variant 6a — Tagged<Kernel, Path>.View in signature: count = \(c1)")

        let c2 = processPathView2(view)
        print("Variant 6b — KernelPath.View in signature: count = \(c2)")
    }

    unsafe buffer.deallocate()
}

// Result: CONFIRMED

// ============================================================================
// MARK: - Variant 7: Char typealias via protocol
// Hypothesis: We can add a Char associated type or a conditional typealias
//             that resolves per-RawValue.
// ============================================================================

// 7a: Char as a per-RawValue typealias (no protocol needed)
extension Tagged where RawValue == Path, Tag: ~Copyable {
    typealias Char = UInt8
}

extension Tagged where RawValue == MyString, Tag: ~Copyable {
    typealias Char = UInt8
}

func testChar() {
    let _: Tagged<Kernel, Path>.Char = 42
    let _: KernelPath.Char = 42
    print("Variant 7 — Char typealias: works")
}

// Result: CONFIRMED

// ============================================================================
// MARK: - Variant 8: Cross-module simulation
// Hypothesis: If Path and MyString are in different modules, both defining
//             Viewable conformances, Tagged.View still resolves without ambiguity.
// NOTE: Cannot truly test cross-module in a single file, but the type resolution
//       through the protocol chain should work identically.
// ============================================================================

// With the protocol approach, there is NO typealias on Tagged for View that is
// conditional per-RawValue. Instead, the Viewable conformance provides a single
// typealias View = RawValue.View. No ambiguity is possible because there's only
// ONE conformance of Tagged to Viewable, parameterized by RawValue.

func testNoAmbiguity() {
    // Both resolve without conflict
    let _: Tagged<Kernel, Path>.View.Type = Path.View.self
    let _: Tagged<Kernel, MyString>.View.Type = MyString.View.self
    let _: Tagged<Filesystem, Path>.View.Type = Path.View.self
    print("Variant 8 — no ambiguity across tags and raw values: CONFIRMED")
}

// Result: CONFIRMED

// ============================================================================
// MARK: - Variant 9: Does Kernel.Path.View == Path.View? (identity check)
// Hypothesis: The typealias chain preserves type identity.
// ============================================================================

func testTypeIdentity() {
    // Tagged<Kernel, Path>.View should be EXACTLY Path.View
    func acceptPathView(_ view: borrowing Path.View) -> Int {
        view.count
    }

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    (unsafe buffer)[0] = 97; (unsafe buffer)[1] = 98; (unsafe buffer)[2] = 0
    let tagged = unsafe Tagged<Kernel, Path>(__unchecked: (), Path(pointer: buffer, count: 2))

    tagged.withView { view in
        // Can we pass Tagged<Kernel, Path>.View to a function expecting Path.View?
        let c = acceptPathView(view)
        print("Variant 9 — type identity (pass to Path.View param): count = \(c)")
    }

    unsafe buffer.deallocate()
}

// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

// ============================================================================
// MARK: - Execution
// ============================================================================

testViewResolution()
testWithView()
testSignatures()
testChar()
testNoAmbiguity()
testTypeIdentity()
print("All variants executed.")
