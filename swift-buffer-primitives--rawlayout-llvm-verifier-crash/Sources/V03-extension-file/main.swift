// MARK: - V03: Extension-File Pattern
// Purpose: Test types defined via `extension` in separate files (or same file).
//          In production, even 1 type via extension triggers the crash.
// Hypothesis: Extension-file pattern is strictly worse than struct-body pattern
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED in isolation — does not crash standalone.
//
//         PRODUCTION FINDINGS (verified in actual codebase):
//         - 1 Inline type via extension (deinit enabled): 2 errors
//         - 1 Inline type via extension (deinit disabled): 0 errors
//         - 4 Inline types via extension (all deinits): 2 errors
//         - Same-file extension = extension-file: defining Ring.Inline via
//           `extension Buffer.Ring { }` in Buffer.swift (same file as Buffer)
//           still crashes. Compiler treats ALL extensions identically.
//
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: rawlayout-release-verifier-crash extension-file tests
// Supports: diagnosis Step 6 — extension-file pattern

public import Storage_Primitives

// --- Namespace ---

public enum Buffer<Element: ~Copyable> { }

// --- Type defined via extension (matches production pattern) ---
// NOTE: In production, this extension (even in the SAME file) triggers the crash.
// The compiler treats extension-defined nested types differently from struct-body types.

extension Buffer {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    public struct Inline<let capacity: Int>: ~Copyable {
        deinit { }
    }
}

// --- Test ---

func test() {
    let _ = Buffer<Int>.Inline<4>()
    print("V03: Extension-file pattern — OK (standalone)")
    print("NOTE: In production, even 1 extension-defined @_rawLayout+deinit type crashes.")
    print("      Same-file or separate-file makes no difference — all extensions crash.")
}

test()
