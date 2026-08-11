// MARK: - ~Copyable Path in Composed Write Operations
// Purpose: Verify that Kernel.File.Write.Atomic's internal flow can work with
//          ~Copyable owned Path instead of Swift.String.
// Hypothesis: ~Copyable Path can replace String in the atomic write pipeline.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 5 variants compile and produce correct output
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-03-31

// =============================================================================
// Minimal types mirroring the real ecosystem
// =============================================================================

@safe
struct OwnedPath: ~Copyable {
    let pointer: UnsafeMutablePointer<UInt8>
    let count: Int

    init(_ string: Swift.String) {
        let utf8 = Array(string.utf8)
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: utf8.count + 1)
        for i in 0..<utf8.count {
            unsafe (ptr[i] = utf8[i])
        }
        unsafe (ptr[utf8.count] = 0)
        unsafe (self.pointer = ptr)
        self.count = utf8.count
    }

    init(copying source: Span<UInt8>) {
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: source.count + 1)
        for i in 0..<source.count {
            unsafe (ptr[i] = source[i])
        }
        unsafe (ptr[source.count] = 0)
        unsafe (self.pointer = ptr)
        self.count = source.count
    }

    deinit {
        unsafe pointer.deallocate()
    }

    var view: PathView {
        @_lifetime(borrow self)
        borrowing get {
            let v = unsafe PathView(pointer: UnsafePointer(pointer), count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }

    var string: Swift.String {
        unsafe Swift.String(cString: UnsafePointer<CChar>(OpaquePointer(pointer)))
    }
}

@safe
struct PathView: ~Copyable, ~Escapable {
    let pointer: UnsafePointer<UInt8>
    let count: Int

    @_lifetime(borrow pointer)
    init(pointer: UnsafePointer<UInt8>, count: Int) {
        unsafe (self.pointer = pointer)
        self.count = count
    }

    var parentBytes: Span<UInt8>? {
        @_lifetime(copy self)
        borrowing get {
            var lastSep = -1
            for i in 0..<count {
                if unsafe pointer[i] == 0x2F { lastSep = i }
            }
            guard lastSep > 0 else { return nil }
            let s = unsafe Span(_unsafeStart: pointer, count: lastSep)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }

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

struct Descriptor: ~Copyable {
    let fd: Int32
    init(_ fd: Int32) { self.fd = fd }
    deinit { print("  [descriptor \(fd) closed via deinit]") }
}

// =============================================================================
// Simulated syscall functions (borrowing parameters)
// =============================================================================

func fakeStat(path: borrowing PathView) -> Bool {
    print("  stat(\(path.count) bytes)")
    return true
}

func fakeOpen(path: borrowing PathView) -> Descriptor {
    print("  open(\(path.count) bytes)")
    return Descriptor(99)
}

func fakeWrite(to fd: borrowing Descriptor) {
    print("  write(fd: \(fd.fd))")
}

func fakeSync(path: borrowing PathView) {
    print("  sync(\(path.count) bytes)")
}

func fakeDelete(path: borrowing PathView) {
    print("  delete(\(path.count) bytes)")
}

func fakeRename(from: borrowing PathView, to: borrowing PathView) {
    print("  rename(\(from.count) bytes → \(to.count) bytes)")
}

// =============================================================================
// MARK: - Variant 1: Sequential borrows of owned ~Copyable Path
// Hypothesis: An owned Path can be borrowed for stat, open, and sync sequentially
// =============================================================================

func testVariant1() {
    print("V1 — Sequential borrows:")
    let parent = OwnedPath("/usr/bin")

    let exists = fakeStat(path: parent.view)
    print("  exists: \(exists)")

    let fd = fakeOpen(path: parent.view)
    fakeWrite(to: fd)

    fakeSync(path: parent.view)

    print("  V1 — CONFIRMED")
    _ = consume fd
}

// =============================================================================
// MARK: - Variant 2: defer block with ~Copyable Path
// Hypothesis: Can borrow a ~Copyable Path in a defer block
// =============================================================================

func testVariant2() {
    print("V2 — defer with ~Copyable Path:")
    let tempPath = OwnedPath("/tmp/.file.atomic.xyz.tmp")

    defer {
        fakeDelete(path: tempPath.view)
        print("  defer executed")
    }

    print("  writing...")
    print("  V2 — CONFIRMED")
}

// =============================================================================
// MARK: - Variant 3: TempFile struct with Optional Descriptor + .take()
// Hypothesis: The var Optional + .take()! pattern works for Descriptor extraction
// =============================================================================

struct TempFile: ~Copyable {
    var descriptor: Descriptor?
    let path: OwnedPath
}

func testVariant3() {
    print("V3 — TempFile with .take()! pattern:")
    var tempFile = TempFile(
        descriptor: Descriptor(42),
        path: OwnedPath("/tmp/.file.tmp")
    )

    // Borrow descriptor for write (pass to borrowing function)
    fakeWrite(to: tempFile.descriptor!)

    // Extract descriptor for close (consuming)
    let fd = tempFile.descriptor.take()!
    print("  Took fd: \(fd.fd)")
    _ = consume fd // explicit drop → deinit closes

    // Path still alive (borrow after descriptor extracted)
    print("  Path still accessible: \(tempFile.path.string)")
    print("  V3 — CONFIRMED")
}

// =============================================================================
// MARK: - Variant 4: Full atomic write mock
// Hypothesis: Complete flow works with ~Copyable paths end-to-end
// =============================================================================

func testVariant4() {
    print("V4 — Full atomic write mock:")

    let destPath = OwnedPath("/usr/local/etc/config.json")

    // Step 1: Decompose
    guard let parentSpan = destPath.view.parentBytes else {
        print("  V4 — FAILED: no parent")
        return
    }
    let parent = OwnedPath(copying: parentSpan)
    print("  Parent: \(parent.string)")

    // Step 2: Check parent
    guard fakeStat(path: parent.view) else {
        print("  V4 — FAILED: parent not found")
        return
    }

    // Step 3: Construct temp path
    let tempPathStr = "\(parent.string)/.config.json.atomic.1234.tmp"
    var tempFile = TempFile(
        descriptor: Descriptor(77),
        path: OwnedPath(tempPathStr)
    )
    print("  Temp: \(tempFile.path.string)")

    // Step 4: defer cleanup
    var committed = false
    defer {
        if !committed {
            fakeDelete(path: tempFile.path.view)
        }
    }

    // Step 5: Write
    fakeWrite(to: tempFile.descriptor!)

    // Step 6: Close before rename
    let fd = tempFile.descriptor.take()!
    _ = consume fd

    // Step 7: Rename
    fakeRename(from: tempFile.path.view, to: destPath.view)

    // Step 8: Sync parent
    fakeSync(path: parent.view)

    committed = true
    print("  V4 — CONFIRMED")
}

// =============================================================================
// MARK: - Variant 5: Simultaneous Spans from same View
// Hypothesis: parentBytes and lastComponentBytes coexist
// =============================================================================

func testVariant5() {
    print("V5 — Simultaneous decomposition:")
    let path = OwnedPath("/usr/bin/ls")
    let view = path.view

    if let parent = view.parentBytes {
        let component = view.lastComponentBytes
        var pStr = ""
        for i in 0..<parent.count { pStr.append(Character(UnicodeScalar(parent[i]))) }
        var cStr = ""
        for i in 0..<component.count { cStr.append(Character(UnicodeScalar(component[i]))) }
        print("  Parent: \(pStr), Component: \(cStr)")
        print("  V5 — CONFIRMED")
    }
}

// =============================================================================
// MARK: - Run All
// =============================================================================

print("=== Experiment: noncopyable-path-composed-ops ===")
testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5()
print("=== Done ===")

// MARK: - Results Summary
// V1: CONFIRMED — Sequential borrows of owned Path
// V2: CONFIRMED — defer borrowing ~Copyable Path
// V3: CONFIRMED — TempFile with Optional Descriptor + .take()
// V4: CONFIRMED — Full atomic write mock (decompose → stat → temp → write → close → rename → sync)
// V5: CONFIRMED — Simultaneous Spans from same View
//
// FINDING: `if let fd = tempFile.descriptor` on ~Copyable struct CONSUMES tempFile.
// Use `tempFile.descriptor!` for borrowing access (pass to `borrowing` parameters).
// Use `tempFile.descriptor.take()!` for consuming extraction.
// Do NOT use `if let` for Optional properties of ~Copyable structs unless consuming is intended.
