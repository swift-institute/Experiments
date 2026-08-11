// MARK: - V04: Cross-Module Type Declaration
// Purpose: Test types defined in a separate module extending a parent namespace.
//          In production, cross-module boundary nullifies the struct-body threshold.
// Hypothesis: Cross-module @_rawLayout+deinit always crashes regardless of count
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED in isolation — does not crash standalone.
//
//         PRODUCTION FINDING (verified in actual codebase):
//         When types extend Buffer from a DIFFERENT module (any per-variant Core,
//         any split), even 1 @_rawLayout+deinit type in struct-body pattern
//         triggers the crash. The struct-body threshold only holds within the
//         defining module. This invalidated the v3.0 per-variant-family Core
//         approach (diagnosis Step 8).
//
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: cross-module-type-declaration, rawlayout-deinit-crossmodule
// Supports: diagnosis Step 8 — cross-module boundary effect

import V04_cross_module_core

func test() {
    let ring = Container<Int>.Ring()
    print("V04: Cross-module type — count: \(ring.header.count)")
    let _ = Container<Int>.Ring.Inline<4>()
    print("V04: Cross-module @_rawLayout+deinit — OK (standalone)")
    print("NOTE: In production, cross-module boundary nullifies struct-body threshold.")
}

test()
