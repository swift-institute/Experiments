// MARK: - V1 — Status Quo (Windows.Kernel.X at L2 + L3)
// Purpose: Verify whether co-locating L2 raw and L3 policy at the same
//          namespace path `Windows.Kernel.Close.close(_:)` compiles cleanly,
//          preserves L3 typed-handle resolution at the consumer site, and
//          leaves the L2 raw form reachable for power-user override.
// Hypothesis: With raw-shape parameter at L2 (`UInt`) and typed-shape at L3
//             (`FakeHandle`), overload resolution on parameter type lets both
//             coexist mechanically. The architectural critique is forward-
//             looking: when L2 phases out raw forms ([PLAT-ARCH-005] direction),
//             typed-at-L2 will collide with typed-at-L3 at the same namespace.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
// Status: CONFIRMED (mechanically) — see Research recommendation for the
//         architectural critique that nominates V1 as REFUTED on
//         spec/policy-separation grounds.
// Result: CONFIRMED — debug + release + cross-module builds clean; runtime
//         output is `V1 typed close (L3 policy): true` and
//         `V1 raw close (L2 reachable via UInt overload): true`.
//         Receipts: Outputs/V1-{debug,release,cross-module,runtime}.txt
// Date: 2026-04-30

import V1_L3
import SharedHandle

// Stand-in for the L3 cross-platform unifier alias provided by `swift-kernel`.
// On the real Windows platform, `swift-kernel/Sources/Kernel/Exports.swift`
// would `#if os(Windows)` guard a `public typealias Kernel = Windows.Kernel`
// declaration. The experiment runs on macOS, so we declare it unconditionally
// at the consumer site.
typealias Kernel = Windows.Kernel

// Typed call (L3 policy) — should resolve to L3.
let handle = FakeHandle(0xCAFE_BABE)
let typed = Kernel.Close.close(handle)
print("V1 typed close (L3 policy):", typed)

// Raw call — should remain reachable through the same namespace via UInt overload.
let raw = Kernel.Close.close(handle.value)
print("V1 raw close (L2 reachable via UInt overload):", raw)

// Architectural observation:
// Both L2 (`close(UInt)`) and L3 (`close(FakeHandle)`) share namespace
// `Windows.Kernel.Close`. The two are distinguished only by parameter type;
// there is no namespace-level audit boundary between spec and policy. If L2
// later loses the `UInt` overload and adopts `FakeHandle`, both methods
// occupy the same syntactic slot and the variant fails by namespace-occupancy
// collision per [PLAT-ARCH-008e].
