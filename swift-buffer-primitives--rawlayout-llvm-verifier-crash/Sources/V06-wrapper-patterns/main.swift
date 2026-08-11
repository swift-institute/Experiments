// MARK: - V06: Wrapper Patterns
// Purpose: Test whether wrapping @_rawLayout fields in a single-field struct
//          (_Fields pattern) or other indirection avoids the crash.
// Hypothesis: Reducing field count to 1 via wrapper might avoid the crash
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — wrapper compiles fine standalone.
//
//         PRODUCTION FINDING (diagnosis Step 6):
//         The _Fields single-field wrapper does NOT help when the type is defined
//         via extension. The crash is not sensitive to stored field count in the
//         extension-file pattern. The wrapper approach was eliminated.
//
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: rawlayout-wrapper-validation
// Supports: diagnosis Step 6 — field count irrelevant in extension-file

// --- Approach A: Direct @_rawLayout (baseline) ---

@_rawLayout(size: 32, alignment: 8)
struct RawStorageDirect: ~Copyable {
    deinit { }
}

// --- Approach B: _Fields wrapper (single stored field) ---

@_rawLayout(size: 32, alignment: 8)
struct _RawStorage: ~Copyable { }

struct WrappedStorage: ~Copyable {
    struct _Fields: ~Copyable {
        var header: Int
        var storage: _RawStorage
    }

    var _fields: _Fields

    init() {
        self._fields = _Fields(header: 0, storage: _RawStorage())
    }

    deinit {
        // Single field in WrappedStorage (the _Fields struct)
        // header + storage are in the nested struct
    }
}

// --- Approach C: Enum wrapper (indirection) ---

enum StorageRepr: ~Copyable {
    case inline(RawStorageDirect)
}

struct EnumWrapped: ~Copyable {
    var repr: StorageRepr

    init() {
        self.repr = .inline(RawStorageDirect())
    }

    deinit { }
}

// --- Size analysis ---

func test() {
    print("V06: Wrapper patterns")
    print("  Direct @_rawLayout size: \(MemoryLayout<RawStorageDirect>.size)")
    print("  _Fields wrapper size:    \(MemoryLayout<WrappedStorage>.size)")
    print("  Enum wrapper size:       \(MemoryLayout<EnumWrapped>.size)")
    let _ = RawStorageDirect()
    let _ = WrappedStorage()
    let _ = EnumWrapped()
    print("  All wrapper patterns compile — OK")
    print("NOTE: In production, _Fields wrapper does NOT help in extension-file pattern.")
    print("      The crash is not sensitive to stored field count.")
}

test()
