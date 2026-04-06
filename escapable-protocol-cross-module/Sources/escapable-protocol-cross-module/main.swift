// MARK: - Cross-Module ~Escapable Protocol: Static Requirements + Instance Defaults
// Purpose: Verify that Path.`Protocol` with STATIC requirements defined in module A
//          can be conformed to by Path.View (also from module A) in module B, and that
//          protocol extension defaults provide the instance API correctly.
// This validates the double lifetime transfer:
//   self → view parameter → static return → property return
// Hypothesis: Static protocol requirements with @_lifetime(copy view) compose correctly
//             with protocol extension defaults using @_lifetime(copy self).
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)

import PathPrimitives

// =============================================================================
// MARK: - Variant 1: Cross-module conformance (POSIX separator logic)
// Hypothesis: Path.View conforms to Path.`Protocol` via static methods
// =============================================================================

extension Path.View: Path.`Protocol` {
    public typealias Char = UInt8

    @inlinable
    @_lifetime(copy view)
    public static func parent(of view: borrowing Path.View) -> Span<UInt8>? {
        let separator: UInt8 = 0x2F // '/'
        var lastSep = -1
        for i in 0..<view.count {
            if unsafe view.pointer[i] == separator { lastSep = i }
        }
        guard lastSep >= 0 else { return nil }
        // Root "/"
        if lastSep == 0 && view.count == 1 { return nil }
        // Separator at start → parent is root (1 byte)
        let parentCount = lastSep == 0 ? 1 : lastSep
        let span = unsafe Span(_unsafeStart: view.pointer, count: parentCount)
        return unsafe _overrideLifetime(span, copying: view)
    }

    @inlinable
    @_lifetime(copy view)
    public static func component(of view: borrowing Path.View) -> Span<UInt8> {
        let separator: UInt8 = 0x2F
        var lastSep = -1
        for i in 0..<view.count {
            if unsafe view.pointer[i] == separator { lastSep = i }
        }
        guard lastSep >= 0 else {
            let s = unsafe Span(_unsafeStart: view.pointer, count: view.count)
            return unsafe _overrideLifetime(s, copying: view)
        }
        let offset = lastSep + 1
        let s = unsafe Span(_unsafeStart: view.pointer + offset, count: view.count - offset)
        return unsafe _overrideLifetime(s, copying: view)
    }

    @inlinable
    public static func appending(_ view: borrowing Path.View, _ other: borrowing Path.View) -> Path {
        let separator: UInt8 = 0x2F
        let selfEndsWithSep: Bool = if view.count > 0 { unsafe view.pointer[view.count - 1] == separator } else { false }
        let separatorSize = selfEndsWithSep ? 0 : 1
        let totalCount = view.count + separatorSize + other.count

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalCount + 1)
        unsafe buffer.initialize(from: view.pointer, count: view.count)
        var offset = view.count
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
// MARK: - Variant 2: Instance API via protocol extension defaults
// Hypothesis: .parent and .component (from protocol extension) work on Path.View
// =============================================================================

func testVariant2() {
    let path = Path("/usr/bin/ls")
    let view = path.view

    if let parent = view.parent {
        var str = ""
        for i in 0..<parent.count { str.append(Character(UnicodeScalar(parent[i]))) }
        print("V2 — parent: \(str)")
    }

    let comp = view.component
    var cStr = ""
    for i in 0..<comp.count { cStr.append(Character(UnicodeScalar(comp[i]))) }
    print("V2 — component: \(cStr)")
}

// =============================================================================
// MARK: - Variant 3: appending via protocol extension default
// Hypothesis: Instance appending (from protocol extension) allocates correctly
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
// Hypothesis: Protocol extension defaults work through generic constraints
// =============================================================================

func decompose<V: Path.`Protocol` & ~Copyable & ~Escapable>(
    _ view: borrowing V
) where V.Char == UInt8 {
    if let parent = view.parent {
        print("V4 — Generic parent count: \(parent.count)")
    } else {
        print("V4 — Generic: no parent")
    }
    print("V4 — Generic component count: \(view.component.count)")
}

func testVariant4() {
    let path = Path("/usr/bin/ls")
    decompose(path.view)
}

// =============================================================================
// MARK: - Variant 5: Edge cases (root, bare filename, trailing separator)
// Hypothesis: POSIX edge cases work through static→instance default chain
// =============================================================================

func testVariant5() {
    // Root "/"
    let root = Path("/")
    let rootParent = root.view.parent
    print("V5 — Root parent is nil: \(rootParent == nil)")

    // Bare filename
    let bare = Path("foo.txt")
    let bareParent = bare.view.parent
    print("V5 — Bare parent is nil: \(bareParent == nil)")
    let bareComp = bare.view.component
    print("V5 — Bare component count: \(bareComp.count)")

    // "/foo" → parent is "/"
    let slashFoo = Path("/foo")
    if let parent = slashFoo.view.parent {
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
// Hypothesis: static parent + static appending roundtrip via instance defaults
// =============================================================================

func testVariant6() {
    let path = Path("/usr/local/etc/config.json")
    let view = path.view

    guard let parentSpan = view.parent else {
        print("V6 — FAILED: no parent")
        return
    }
    let parent = Path(parentSpan)

    let componentSpan = view.component
    let reconstructed = parent.view.appending(
        Path(componentSpan).view
    )
    var str = ""
    for i in 0..<reconstructed.count { str.append(Character(UnicodeScalar(reconstructed.byte(at: i)))) }
    print("V6 — Roundtrip: \(str)")
}

// =============================================================================
// MARK: - Variant 7: Static methods callable directly
// Hypothesis: Conformer's static methods are also directly callable
// =============================================================================

func testVariant7() {
    let path = Path("/var/log/syslog")
    let view = path.view

    if let parent = Path.View.parent(of: view) {
        var str = ""
        for i in 0..<parent.count { str.append(Character(UnicodeScalar(parent[i]))) }
        print("V7 — Static parent: \(str)")
    }

    let comp = Path.View.component(of: view)
    var cStr = ""
    for i in 0..<comp.count { cStr.append(Character(UnicodeScalar(comp[i]))) }
    print("V7 — Static component: \(cStr)")
}

// =============================================================================
// MARK: - Run All
// =============================================================================

print("=== Experiment: escapable-protocol-cross-module (static requirements) ===")
testVariant2()
testVariant3()
testVariant4()
testVariant5()
testVariant6()
testVariant7()
print("=== Done ===")
