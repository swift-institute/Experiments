// MARK: - V4 — Org-Prefix (Microsoft.Kernel.X at L2 + Windows.Kernel.X at L3)
// Purpose: Verify that rooting the L2 spec surface at `Microsoft` (the
//          publishing organization) and the L3 policy / unifier at `Windows`
//          (the platform identity) gives clean disjoint namespace trees.
// Hypothesis: `Microsoft.Kernel.X` and `Windows.Kernel.X` are entirely
//             disjoint; both compile and the L2 raw form remains reachable
//             through the Microsoft root.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
// Status: CONFIRMED (mechanically) — see Research recommendation for the
//         architectural critique that nominates V4 as sub-optimal because the
//         org-prefix root conflicts with [API-NAME-003] specification-mirroring
//         naming (the ecosystem already roots specs at the spec name —
//         `ISO_9945`, `RFC_4122` — not the publisher).
// Result: CONFIRMED — debug + release + cross-module builds clean; runtime
//         output is `V4 typed close (L3 policy at Windows.Kernel): true`
//         and `V4 raw close (L2 spec at Microsoft.Kernel): true`.
//         Receipts: Outputs/V4-{debug,release,cross-module,runtime}.txt
// Date: 2026-04-30

import V4_L3
import SharedHandle

// Stand-in for the L3 cross-platform unifier alias.
typealias Kernel = Windows.Kernel

let handle = FakeHandle(0xCAFE_BABE)
let typed = Kernel.Close.close(handle)
print("V4 typed close (L3 policy at Windows.Kernel):", typed)

// L2 raw form lives under the Microsoft root.
let raw = Microsoft.Kernel.Close.close(handle.value)
print("V4 raw close (L2 spec at Microsoft.Kernel):", raw)

// Architectural observation:
// Org-prefix scopes by publisher. Cross-vendor consistency would extend the
// pattern (Apple.Kernel.X for Darwin spec, IEEE.Kernel.X for POSIX) but the
// existing ecosystem already uses spec-name roots (`ISO_9945` not `IEEE`),
// breaking parity. The pattern conflicts with [API-NAME-003] specification-
// mirroring naming, which prefers the literal spec identity (`ISO_9945`,
// `RFC_4122`, `Win32`) over the publishing organization.
