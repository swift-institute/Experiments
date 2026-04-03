// SUPERSEDED: See nonescapable-patterns
// MARK: - Cross-Module ~Escapable Protocol Conformance
// Purpose: Verify that Path.`Protocol` defined in module A can be conformed to
//          by Path.View (also from module A) in module B. This is the exact
//          architecture for path decomposition: path-primitives defines the
//          protocol, platform packages (iso-9945, windows-primitives) conform.
// Hypothesis: Cross-module conformance of ~Copyable, ~Escapable type to a
//             protocol with @_lifetime requirements, Span returns, and owned
//             ~Copyable returns compiles and runs correctly.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 6 variants compile and produce correct output
// Date: 2026-04-01

import PathPrimitives

// =============================================================================
// MARK: - Variant 1: Cross-module conformance (POSIX separator logic)
// Hypothesis: Path.View conforms to Path.`Protocol` from a consuming module
// =============================================================================

extension Path.View: Path.`Protocol` {
    public typealias Char = UInt8

    @inlinable
    public var parentBytes: Span<UInt8>? {
        @_lifetime(copy self)
        borrowing get {
            let separator: UInt8 = 0x2F // '/'
            var lastSep = -1
            for i in 0..<count {
                if unsafe pointer[i] == separator { lastSep = i }
            }
            guard lastSep >= 0 else { return nil }
            // Root "/"
            if lastSep == 0 && count == 1 { return nil }
            // Separator at start → parent is root (1 byte)
            let parentCount = lastSep == 0 ? 1 : lastSep
            let span = unsafe Span(_unsafeStart: pointer, count: parentCount)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }

    @inlinable
    public var lastComponentBytes: Span<UInt8> {
        @_lifetime(copy self)
        borrowing get {
            let separator: UInt8 = 0x2F
            var lastSep = -1
            for i in 0..<count {
                if unsafe pointer[i] == separator { lastSep = i }
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

    @inlinable
    public borrowing func appending(_ other: borrowing Path.View) -> Path {
        let separator: UInt8 = 0x2F
        let selfEndsWithSep: Bool = if count > 0 { unsafe pointer[count - 1] == separator } else { false }
        let separatorSize = selfEndsWithSep ? 0 : 1
        let totalCount = count + separatorSize + other.count

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalCount + 1)
        unsafe buffer.initialize(from: pointer, count: count)
        var offset = count
        if !selfEndsWithSep {
            (unsafe buffer)[offset] = separator
            offset += 1
        }
        unsafe (buffer + offset).initialize(from: other.pointer, count: other.count)
        (unsafe buffer)[totalCount] = 0

        return unsafe Path(adopting: buffer, count: totalCount)
    }
}

// =============================================================================
// MARK: - Variant 2: Use conformance directly
// Hypothesis: Protocol methods are callable on Path.View after cross-module conformance
// =============================================================================

func testVariant2() {
    let path = Path("/usr/bin/ls")
    let view = path.view

    if let parent = view.parentBytes {
        var str = ""
        for i in 0..<parent.count { str.append(Character(UnicodeScalar(parent[i]))) }
        print("V2 — parentBytes: \(str)")
    }

    let comp = view.lastComponentBytes
    var cStr = ""
    for i in 0..<comp.count { cStr.append(Character(UnicodeScalar(comp[i]))) }
    print("V2 — lastComponentBytes: \(cStr)")
}

// =============================================================================
// MARK: - Variant 3: appending produces correct result
// Hypothesis: Cross-module appending allocates correctly
// =============================================================================

func testVariant3() {
    let a = Path("usr")
    let b = Path("local")
    let result = a.view.appending(b.view)
    var str = ""
    for i in 0..<result.count { str.append(Character(UnicodeScalar(result.byte(at: i)))) }
    print("V3 — appending: \(str)")
}

// =============================================================================
// MARK: - Variant 4: Generic function constrained by Path.`Protocol`
// Hypothesis: Generic code works across module boundary
// =============================================================================

func decompose<V: Path.`Protocol` & ~Copyable & ~Escapable>(
    _ view: borrowing V
) where V.Char == UInt8 {
    if let parent = view.parentBytes {
        print("V4 — Generic parent count: \(parent.count)")
    } else {
        print("V4 — Generic: no parent")
    }
    print("V4 — Generic component count: \(view.lastComponentBytes.count)")
}

func testVariant4() {
    let path = Path("/usr/bin/ls")
    decompose(path.view)
}

// =============================================================================
// MARK: - Variant 5: Edge cases (root, bare filename, trailing separator)
// Hypothesis: POSIX edge cases work through cross-module protocol conformance
// =============================================================================

func testVariant5() {
    // Root "/"
    let root = Path("/")
    let rootParent = root.view.parentBytes
    print("V5 — Root parent is nil: \(rootParent == nil)")

    // Bare filename
    let bare = Path("foo.txt")
    let bareParent = bare.view.parentBytes
    print("V5 — Bare parent is nil: \(bareParent == nil)")
    let bareComp = bare.view.lastComponentBytes
    print("V5 — Bare lastComponent count: \(bareComp.count)")

    // "/foo" → parent is "/"
    let slashFoo = Path("/foo")
    if let parent = slashFoo.view.parentBytes {
        print("V5 — /foo parent count: \(parent.count) (expect 1)")
    }

    // Trailing separator: appending to path ending with /
    let trailing = Path("/usr/")
    let comp = Path("bin")
    let joined = trailing.view.appending(comp.view)
    var jStr = ""
    for i in 0..<joined.count { jStr.append(Character(UnicodeScalar(joined.byte(at: i)))) }
    print("V5 — Trailing sep append: \(jStr)")
}

// =============================================================================
// MARK: - Variant 6: Full decompose → reconstruct cycle
// Hypothesis: parentBytes + appending roundtrips correctly
// =============================================================================

func testVariant6() {
    let path = Path("/usr/local/etc/config.json")
    let view = path.view

    guard let parentSpan = view.parentBytes else {
        print("V6 — FAILED: no parent")
        return
    }
    let parent = Path(parentSpan)

    let componentSpan = view.lastComponentBytes
    let reconstructed = parent.view.appending(
        Path(componentSpan).view
    )
    var str = ""
    for i in 0..<reconstructed.count { str.append(Character(UnicodeScalar(reconstructed.byte(at: i)))) }
    print("V6 — Roundtrip: \(str)")
}

// =============================================================================
// MARK: - Run All
// =============================================================================

print("=== Experiment: escapable-protocol-cross-module ===")
testVariant2()
testVariant3()
testVariant4()
testVariant5()
testVariant6()
print("=== Done ===")

// MARK: - Results Summary
// V1: CONFIRMED — Cross-module conformance compiles (Path.View: Path.`Protocol` in consuming module)
// V2: CONFIRMED — Protocol methods callable on Path.View across module boundary
// V3: CONFIRMED — appending allocates correctly (usr + local → usr/local)
// V4: CONFIRMED — Generic function with Path.`Protocol` constraint works cross-module
// V5: CONFIRMED — POSIX edge cases: root→nil, bare→nil, /foo→"/" (1 byte), trailing sep no double
// V6: CONFIRMED — Full decompose → reconstruct roundtrip preserves path exactly
