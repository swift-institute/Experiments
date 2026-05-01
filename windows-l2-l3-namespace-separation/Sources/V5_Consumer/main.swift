// MARK: - V5 — Literal-Spec (WinSDK.Kernel.X at L2 + Windows.Kernel.X at L3)
// Purpose: Verify that rooting the L2 spec surface at `WinSDK` (the literal
//          Swift module name Microsoft publishes for Windows SDK headers)
//          and the L3 policy / unifier at `Windows` gives clean disjoint
//          namespace trees, with the additional property that the L2 root
//          name lines up with the C-shim module already in use on Windows.
// Hypothesis: `WinSDK.Kernel.X` and `Windows.Kernel.X` are entirely disjoint;
//             both compile mechanically. On real Windows, the user's
//             `import WinSDK` (the C module) and the Swift namespace
//             `enum WinSDK` collide on a single identifier — modules and
//             top-level types share a name space — so this variant has a
//             latent collision risk surfaceable only on the Windows host.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
// Status: CONFIRMED (mechanically on macOS) — see Research recommendation
//         for the architectural critique that nominates V5 as sub-optimal
//         because of latent module-vs-type identifier collision on Windows
//         (the consumer's `import WinSDK` and the Swift `enum WinSDK` share
//         a name space at qualified-reference sites). The collision cannot
//         fire on macOS or Linux CI; cross-platform CI alone cannot rule out
//         the latent risk.
// Result: CONFIRMED — debug + release + cross-module builds clean; runtime
//         output is `V5 typed close (L3 policy at Windows.Kernel): true`
//         and `V5 raw close (L2 spec at WinSDK.Kernel): true`.
//         Receipts: Outputs/V5-{debug,release,cross-module,runtime}.txt
// Date: 2026-04-30

import V5_L3
import SharedHandle

// Stand-in for the L3 cross-platform unifier alias.
typealias Kernel = Windows.Kernel

let handle = FakeHandle(0xCAFE_BABE)
let typed = Kernel.Close.close(handle)
print("V5 typed close (L3 policy at Windows.Kernel):", typed)

// L2 raw form lives under the WinSDK root.
let raw = WinSDK.Kernel.Close.close(handle.value)
print("V5 raw close (L2 spec at WinSDK.Kernel):", raw)

// Architectural observation:
// `WinSDK` already names the Swift-side facade for the Windows C SDK
// headers (the `import WinSDK` consumers write to reach `CloseHandle` and
// friends). Defining a Swift `enum WinSDK` at the platform spec layer
// reuses the identifier in the SAME name space — Swift modules and
// top-level types share a single namespace at use sites. The collision
// cannot fire on macOS (no WinSDK module to import) but is structurally
// guaranteed on Windows whenever a consumer reaches for the raw C surface.
// The variant therefore ships a latent identifier-overload tax that's
// invisible to any cross-platform CI on macOS or Linux.
