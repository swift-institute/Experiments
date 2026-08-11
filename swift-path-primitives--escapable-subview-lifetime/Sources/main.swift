// MARK: - ~Escapable Sub-View Lifetime Chains for Path Decomposition
// Purpose: Verify that Path.View-style decomposition (parent, lastComponent)
//          can return Span<UInt8> sub-views with correct lifetime tracking.
// Hypothesis: Three-level lifetime chains (owned buffer → View → Span),
//             Optional<Span>, and simultaneous sub-views all compile and run.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 6 variants compile and produce correct output
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-03-31

// =============================================================================
// Minimal Path-like types mirroring string-primitives pattern
// =============================================================================

/// Owned buffer (~Copyable) — mirrors Path_Primitives.Path
struct OwnedBuffer: ~Copyable {
    let pointer: UnsafeMutablePointer<UInt8>
    let count: Int

    init(_ string: Swift.String) {
        let utf8 = Array(string.utf8)
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: utf8.count + 1)
        for i in 0..<utf8.count {
            unsafe (ptr[i] = utf8[i])
        }
        unsafe (ptr[utf8.count] = 0) // null terminator
        self.pointer = ptr
        self.count = utf8.count
    }

    deinit {
        pointer.deallocate()
    }

    var view: BufferView {
        @_lifetime(borrow self)
        borrowing get {
            let v = unsafe BufferView(pointer: UnsafePointer(pointer), count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}

/// Borrowed view (~Copyable, ~Escapable) — mirrors Path_Primitives.Path.View
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
// MARK: - Variant 1: Span from View (three-level lifetime chain)
// Hypothesis: View can return Span<UInt8> that borrows from View's pointer
// =============================================================================

extension BufferView {
    var span: Span<UInt8> {
        @_lifetime(copy self)
        borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}

func testVariant1() {
    let buffer = OwnedBuffer("/usr/bin/ls")
    let view = buffer.view
    let s = view.span
    print("V1 — Span count: \(s.count)")
    // Verify bytes
    var result = ""
    for i in 0..<s.count {
        result.append(Character(UnicodeScalar(s[i])))
    }
    print("V1 — Content: \(result)")
}

// =============================================================================
// MARK: - Variant 2: Sub-view via Span (parentBytes — NOT null-terminated)
// Hypothesis: Can scan for separator and return Span of parent portion
// =============================================================================

extension BufferView {
    /// Returns Span of bytes up to (not including) the last separator.
    /// NOT null-terminated — for reading only, not syscall use.
    var parentBytes: Span<UInt8>? {
        @_lifetime(copy self)
        borrowing get {
            let separator: UInt8 = 0x2F // '/'
            var lastSep = -1
            for i in 0..<count {
                if unsafe pointer[i] == separator {
                    lastSep = i
                }
            }
            guard lastSep >= 0 else { return nil }
            // Root "/" → parent count is 1 (just the slash)
            let parentCount = lastSep == 0 ? 1 : lastSep
            let s = unsafe Span(_unsafeStart: pointer, count: parentCount)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}

func testVariant2() {
    let buffer = OwnedBuffer("/usr/bin/ls")
    let view = buffer.view
    if let parent = view.parentBytes {
        var result = ""
        for i in 0..<parent.count {
            result.append(Character(UnicodeScalar(parent[i])))
        }
        print("V2 — Parent bytes: \(result)")
    } else {
        print("V2 — No parent")
    }

    // Edge case: root
    let root = OwnedBuffer("/")
    let rootView = root.view
    if let rootParent = rootView.parentBytes {
        print("V2 — Root parent count: \(rootParent.count)")
    } else {
        print("V2 — Root has no parent")
    }

    // Edge case: bare filename
    let bare = OwnedBuffer("foo")
    let bareView = bare.view
    if let _ = bareView.parentBytes {
        print("V2 — bare has parent (unexpected)")
    } else {
        print("V2 — bare has no parent (correct)")
    }
}

// =============================================================================
// MARK: - Variant 3: lastComponent as sub-view (IS null-terminated)
// Hypothesis: Last component borrows from end of buffer, shares null terminator
// =============================================================================

extension BufferView {
    /// Returns Span of bytes after the last separator.
    /// This IS effectively null-terminated (shares the original buffer's terminator).
    var lastComponentBytes: Span<UInt8> {
        @_lifetime(copy self)
        borrowing get {
            let separator: UInt8 = 0x2F // '/'
            var lastSep = -1
            for i in 0..<count {
                if unsafe pointer[i] == separator {
                    lastSep = i
                }
            }
            guard lastSep >= 0 else {
                // No separator — whole thing is the component
                let s = unsafe Span(_unsafeStart: pointer, count: count)
                return unsafe _overrideLifetime(s, copying: self)
            }
            let offset = lastSep + 1
            let componentCount = count - offset
            let s = unsafe Span(_unsafeStart: pointer + offset, count: componentCount)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}

func testVariant3() {
    let buffer = OwnedBuffer("/usr/bin/ls")
    let view = buffer.view
    let component = view.lastComponentBytes
    var result = ""
    for i in 0..<component.count {
        result.append(Character(UnicodeScalar(component[i])))
    }
    print("V3 — Last component: \(result)")

    // Verify null termination: byte after the Span should be \0
    // (This is the key property that makes lastComponent syscall-safe)
    let afterSpan = unsafe view.pointer[view.count - component.count + component.count]
    print("V3 — Byte after component: \(afterSpan) (expect 0)")
}

// =============================================================================
// MARK: - Variant 4: Two simultaneous Spans from same View
// Hypothesis: Can hold parentBytes AND lastComponentBytes alive simultaneously
// =============================================================================

func testVariant4() {
    let buffer = OwnedBuffer("/usr/bin/ls")
    let view = buffer.view
    let parent = view.parentBytes
    let component = view.lastComponentBytes

    var parentStr = ""
    if let parent {
        for i in 0..<parent.count {
            parentStr.append(Character(UnicodeScalar(parent[i])))
        }
    }
    var compStr = ""
    for i in 0..<component.count {
        compStr.append(Character(UnicodeScalar(component[i])))
    }
    print("V4 — Parent: \(parentStr), Component: \(compStr)")
}

// =============================================================================
// MARK: - Variant 5: Optional<Span<UInt8>> with ~Escapable
// Hypothesis: Optional wrapping a ~Escapable Span compiles and pattern-matches
// =============================================================================

func testVariant5() {
    let buffer = OwnedBuffer("/usr/bin/ls")
    let view = buffer.view

    // Optional binding
    if let parent = view.parentBytes {
        print("V5 — Optional parent count: \(parent.count)")
    }

    // Nil case
    let bare = OwnedBuffer("noSlash")
    let bareView = bare.view
    let noParent = bareView.parentBytes
    print("V5 — Bare filename parent is nil: \(noParent == nil)")
}

// =============================================================================
// MARK: - Variant 6: Constructing owned buffer from Span (parent → owned Path)
// Hypothesis: Can allocate a new null-terminated buffer from a Span<UInt8>
// =============================================================================

extension OwnedBuffer {
    /// Creates an owned buffer by copying bytes from a Span and adding null terminator.
    init(copying source: Span<UInt8>) {
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: source.count + 1)
        for i in 0..<source.count {
            unsafe (ptr[i] = source[i])
        }
        unsafe (ptr[source.count] = 0)
        self.pointer = ptr
        self.count = source.count
    }
}

func testVariant6() {
    let buffer = OwnedBuffer("/usr/bin/ls")
    let view = buffer.view

    if let parentSpan = view.parentBytes {
        let parentOwned = OwnedBuffer(copying: parentSpan)
        let parentView = parentOwned.view
        var result = ""
        for i in 0..<parentView.count {
            result.append(Character(UnicodeScalar(unsafe parentView.pointer[i])))
        }
        // Verify null-terminated
        let terminator = unsafe parentView.pointer[parentView.count]
        print("V6 — Owned parent: \(result), null-terminated: \(terminator == 0)")
    }
}

// =============================================================================
// MARK: - Run All
// =============================================================================

print("=== Experiment: escapable-subview-lifetime ===")
testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5()
testVariant6()
print("=== Done ===")

// MARK: - Results Summary
// V1: CONFIRMED — Span from View (three-level lifetime chain)
// V2: CONFIRMED — parentBytes as Optional<Span> (zero-alloc, NOT null-terminated)
// V3: CONFIRMED — lastComponentBytes as Span (zero-alloc, IS null-terminated)
// V4: CONFIRMED — Two simultaneous Spans from same View
// V5: CONFIRMED — Optional<Span<UInt8>> pattern-matches correctly
// V6: CONFIRMED — OwnedBuffer from Span (allocates, adds null terminator)
