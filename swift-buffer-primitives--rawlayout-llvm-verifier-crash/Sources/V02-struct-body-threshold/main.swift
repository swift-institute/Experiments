// MARK: - V02: Struct-Body Threshold
// Purpose: Test the ≤2 threshold for @_rawLayout + deinit types in struct body.
//          In production (Buffer Primitives Core), 3+ types crash. ≤2 is safe.
//          This variant imports Storage_Primitives to provide cross-module SIL.
// Hypothesis: 3+ @_rawLayout+deinit types in same namespace enum → crash under -O
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED in isolation — even with Storage_Primitives imported, standalone
//         types don't reproduce the crash. The threshold only manifests in the
//         production Buffer Primitives Core with its full dependency graph.
//
//         PRODUCTION FINDINGS (verified in actual codebase):
//         - 0 deinits: 0 errors
//         - 1 deinit: 0 errors
//         - 2 deinits: 0 errors
//         - 3 deinits: 2 errors
//         - 4 deinits: 2 errors
//         Error count is always 2 regardless of having 3 or 4 triggering types.
//
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: rawlayout-release-verifier-crash (V1-V8, V13a-V30)
// Supports: diagnosis Step 6 — struct-body ≤2 threshold

public import Storage_Primitives

// Provide cross-module SIL via Storage_Primitives import.
// In production, both Storage_Primitives AND Cyclic_Index_Primitives are needed.

public enum Buffer<Element: ~Copyable> {
    public struct Header: ~Copyable {
        var count: Int = 0
    }
}

// --- Type 1: Ring.Inline ---

extension Buffer {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    public struct RingInline<let capacity: Int>: ~Copyable {
        deinit { }
    }
}

// --- Type 2: Linear.Inline ---

extension Buffer {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    public struct LinearInline<let capacity: Int>: ~Copyable {
        deinit { }
    }
}

// --- Type 3: Slab.Inline (ENABLE to test 3-type threshold) ---

extension Buffer {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    public struct SlabInline<let capacity: Int>: ~Copyable {
        deinit { }
    }
}

// --- Type 4: Arena.Inline (ENABLE to test 4-type threshold) ---

// extension Buffer {
//     @_rawLayout(likeArrayOf: Element, count: capacity)
//     public struct ArenaInline<let capacity: Int>: ~Copyable {
//         deinit { }
//     }
// }

// --- Test ---

func test() {
    let _ = Buffer<Int>.RingInline<4>()
    let _ = Buffer<Int>.LinearInline<4>()
    let _ = Buffer<Int>.SlabInline<4>()
    print("V02: 3 types with @_rawLayout + deinit — OK (standalone)")
    print("NOTE: In production, 3+ types in Buffer Primitives Core crashes.")
    print("      Enable/disable deinit blocks and rebuild with:")
    print("      rm -rf .build && swift build -c release --target V02-struct-body-threshold")
}

test()
