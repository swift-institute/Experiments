// MARK: - V3 — Twin Roots (Win32.Kernel.X at L2 + Windows.Kernel.X at L3)
// Purpose: Verify that defining the L2 spec surface under a parallel root
//          (`Win32`) — distinct from the L3 unifier root (`Windows`) — gives
//          the strongest namespace-level separation, and mirrors the POSIX
//          ISO_9945 / POSIX shape where the spec root and policy root are
//          syntactically distinct top-level namespaces.
// Hypothesis: `Win32.Kernel.X` and `Windows.Kernel.X` are entirely disjoint
//             namespace trees; the typealiased L3 alias (`Kernel = Windows.Kernel`)
//             cannot leak through to L2 even by typealias chain because the
//             L2 root is lexically different.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
// Status: CONFIRMED — disjoint namespace trees; cleanest spec/policy split.
// Result: CONFIRMED — debug + release + cross-module builds clean; runtime
//         output is `V3 typed close (L3 policy at Windows.Kernel): true`
//         and `V3 raw close (L2 spec at Win32.Kernel): true`.
//         Receipts: Outputs/V3-{debug,release,cross-module,runtime}.txt
// Date: 2026-04-30

import V3_L3
import SharedHandle

// Stand-in for the L3 cross-platform unifier alias.
typealias Kernel = Windows.Kernel

let handle = FakeHandle(0xCAFE_BABE)
let typed = Kernel.Close.close(handle)
print("V3 typed close (L3 policy at Windows.Kernel):", typed)

// L2 raw form lives under a disjoint root.
let raw = Win32.Kernel.Close.close(handle.value)
print("V3 raw close (L2 spec at Win32.Kernel):", raw)

// Architectural observation:
// Twin roots match the POSIX-side architecture: `ISO_9945` (IEEE spec root) /
// `POSIX` (L3-policy / unifier root) on POSIX; `Win32` (Microsoft spec root) /
// `Windows` (L3-policy / unifier root) on Windows. The pattern symmetry makes
// audits straightforward — `import Win32_Kernel_*` flags spec consumers and
// `import Windows_Kernel_*` flags policy/unifier consumers. The shape only
// composes cleanly with POSIX symmetry if `POSIX` and `ISO_9945` are
// genuinely distinct types (today they are typealiased: `POSIX = ISO_9945`).
// See the recommendation document's open question.
