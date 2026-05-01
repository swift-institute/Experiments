// MARK: - V2 — Sub-Namespace (Windows.ABI.Kernel.X at L2 + Windows.Kernel.X at L3)
// Purpose: Verify that pushing the L2 spec surface into a `Windows.ABI.Kernel`
//          sub-namespace frees the `Windows.Kernel` slot for the L3 policy
//          tier. The two extension namespace paths are disjoint, so future
//          typed-only L2 declarations cannot collide with typed L3 wrappers.
// Hypothesis: `Windows.ABI.Kernel.X` and `Windows.Kernel.X` are syntactically
//             disjoint extension paths; both compile cleanly and the L2 raw
//             form remains reachable through its native sub-namespace.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
// Status: CONFIRMED — disjoint namespace paths under one `Windows` root.
// Result: CONFIRMED — debug + release + cross-module builds clean; runtime
//         output is `V2 typed close (L3 policy at Windows.Kernel): true`
//         and `V2 raw close (L2 spec at Windows.ABI.Kernel): true`.
//         Receipts: Outputs/V2-{debug,release,cross-module,runtime}.txt
// Date: 2026-04-30

import V2_L3
import SharedHandle

// Stand-in for the L3 cross-platform unifier alias.
typealias Kernel = Windows.Kernel

let handle = FakeHandle(0xCAFE_BABE)
let typed = Kernel.Close.close(handle)
print("V2 typed close (L3 policy at Windows.Kernel):", typed)

// L2 raw form remains reachable through `Windows.ABI.Kernel`.
let raw = Windows.ABI.Kernel.Close.close(handle.value)
print("V2 raw close (L2 spec at Windows.ABI.Kernel):", raw)

// Architectural observation:
// L2 and L3 occupy distinct namespace paths under one `Windows` root. The L3
// unifier slot (`Windows.Kernel`) is a clean syntactic carve-out for typed
// policy wrappers; future typed-only L2 declarations (per [PLAT-ARCH-005])
// stay at `Windows.ABI.Kernel` and cannot collide. The "ABI" sub-namespace
// name carries semantic intent — the binary contract layer — and reads
// naturally to consumers familiar with Microsoft's own Win32 ABI vocabulary.
