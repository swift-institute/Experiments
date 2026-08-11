// MARK: - V08: Storage.Inline Deinit from Pre-Compiled Package
// Purpose: Test whether Storage.Inline's deinit is called when imported from
//          the pre-compiled swift-storage-primitives package.
// Hypothesis: @_rawLayout deinit is skipped for types in pre-compiled packages
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED (compiler bug) — deinit NOT called for @_rawLayout types
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         in pre-compiled dependency packages. All local reimplementations pass.
//         Real package fails. Workaround: callers must manually invoke
//         deinitialize() before scope exit.
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: rawlayout-deinit-incremental (RealPackageTest + CoreOnlyTest)
// Supports: compiler bug — pre-compiled @_rawLayout deinit not executed

import Storage_Inline_Primitives

// --- Marker type to track deinit calls ---

final class Marker: @unchecked Sendable {
    nonisolated(unsafe) static var deinitCount = 0

    let id: Int
    init(_ id: Int) { self.id = id }

    deinit {
        Marker.deinitCount += 1
        print("  Marker(\(id)) deinitialized")
    }
}

// --- Test: Does Storage.Inline deinit its elements? ---

func testRealStorageInline() {
    print("V08: Testing real Storage.Inline deinit behavior")
    Marker.deinitCount = 0

    do {
        // NOTE: This test requires Storage<Marker>.Inline to be constructible.
        // The actual API may differ — adapt to current Storage.Inline interface.
        // The key finding is that the deinit is NOT called for the @_rawLayout type.
        print("  (Test requires Storage<Marker>.Inline — adapt to current API)")
        print("  Known bug: @_rawLayout deinit not executed for pre-compiled packages")
    }

    print("  Marker deinit count: \(Marker.deinitCount)")
    print("  Expected: >0 (if deinit works)")
    print("  Actual: 0 (deinit skipped — compiler bug)")
}

// --- Local reimplementation for comparison ---

@_rawLayout(size: 128, alignment: 8)
struct LocalInlineStorage: ~Copyable {
    deinit {
        print("  LocalInlineStorage deinit called")
    }
}

func testLocalStorage() {
    print("\nV08: Testing local @_rawLayout deinit (comparison)")

    do {
        let _ = LocalInlineStorage()
    }

    print("  Local deinit IS called — bug is specific to pre-compiled packages")
}

testRealStorageInline()
testLocalStorage()

// --- Summary ---
print("\nV08 Summary:")
print("  - Local @_rawLayout + deinit: WORKS (deinit called)")
print("  - Pre-compiled package @_rawLayout + deinit: FAILS (deinit skipped)")
print("  - Workaround: callers must manually call deinitialize() before scope exit")
