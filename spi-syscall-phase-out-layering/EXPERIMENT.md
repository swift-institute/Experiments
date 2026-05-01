# spi-syscall-phase-out-layering

**Purpose**: Empirically determine which access-control mechanism supports legitimate raw-FFI use cases without exposing raw shape at any L2 public surface, after Path X closes (`@_spi(Syscall)` to be phased out entirely).

**Hypothesis**: A typed-only L2 (V6) is structurally clean but cannot serve all production raw-FFI use cases. The right pattern is one that contains raw access to the platform-stack package author's own callable surface (their own benchmarks, ABI shims, etc.) without leaking it to general consumers, AND survives across SPM-package boundaries the way our ecosystem topology demands.

**Toolchain**: Apple Swift 6.3.1 (Xcode 26.4.1)
**Platform**: macOS 26.0 (arm64)
**Date**: 2026-04-30

## Variants (6)

| Variant | Mechanism | Raw access reachable from… |
|---|---|---|
| V1 | `@_spi(Syscall) public func close(Int32)` alongside typed | Any consumer with `@_spi(Syscall) import V1_L2` |
| V2 | file-scope `private func` raw helper | Nowhere outside the L2 source file |
| V3 | `internal func` + sibling target via `@testable import` | Any sibling target, only when L2 ships with `-enable-testing` |
| V4 | `package func` raw form | Same SPM package only — does NOT cross `Package.swift` boundaries |
| V5 | typed-only L2; consumer writes its own C-shim | Anywhere the consumer can re-bind to platform C |
| V6 | typed-only at every layer | Nowhere |

## Each variant ships 3 targets

| Target | Role |
|---|---|
| `Vk_L2` | Spec wrapper holding typed `Close.close(consuming Descriptor) throws(Close.Error)` and (per variant) a raw form |
| `Vk_L3` | Policy wrapper that delegates to the typed L2 form |
| `Vk_Consumer` | Executable that exercises (a) typed via L3, (b) raw if available, (c) cross-module via the import chain |

## Build matrix

Per [EXP-017]: each variant validates in debug mode AND release mode AND across module boundaries. Cross-module is implicit because `Vk_Consumer` imports both `Vk_L2` and `Vk_L3`; running each consumer captures both link-time and runtime cross-module behavior.

| Receipt | Captures |
|---|---|
| `Outputs/Vk-debug.txt` | `swift build --target Vk_Consumer` (debug) |
| `Outputs/Vk-release.txt` | `swift build -c release --target Vk_Consumer` |
| `Outputs/Vk-cross-module.txt` | `swift run Vk_Consumer` — link + execute |

## Results summary

All 18 builds GREEN; all 6 runs print expected output. The differential signal is in the **architectural reachability** each variant provides, not in any compile failure.

| Variant | Build (debug) | Build (release) | Cross-module run | Raw use case (b) |
|---|---|---|---|---|
| V1 | GREEN | GREEN | GREEN — raw rc=0 | CONFIRMED — reachable via `@_spi(Syscall) import` |
| V2 | GREEN | GREEN | GREEN — typed only | REFUTED for cross-module raw access (private is module-private and additionally file-private at top scope) |
| V3 | GREEN | GREEN | GREEN — raw rc=0 | CONFIRMED in this sandbox; PRACTICALLY REFUTED at ecosystem scale (requires `-enable-testing` on every L2 module shipped to consumers) |
| V4 | GREEN | GREEN | GREEN — raw rc=0 | CONFIRMED within one Package.swift; PROVEN to NOT cross SPM-package boundaries by Swift's `package` access semantics (SE-0386) — fatal for our cross-package-stack consumer topology |
| V5 | GREEN | GREEN | GREEN — raw rc=0 | CONFIRMED — but every consumer needing raw must duplicate the FFI binding AND violates [PLAT-ARCH-008a] |
| V6 | GREEN | GREEN | GREEN — typed only | REFUTED — production raw-required use cases (posix_spawn_file_actions, setrlimit fd-table manipulation, ABI shims, benchmark bypass) cannot be served |

## Verdicts per [EXP-006]

- **V1**: CONFIRMED working. Production verdict: blocked by user direction (Path X close, 2026-04-30 — `@_spi(Syscall)` to be phased out entirely).
- **V2**: REFUTED for the use case "expose raw FFI to consumers who legitimately need it". CONFIRMED for the (orthogonal) use case "L2 author keeps raw call site contained inside one source file".
- **V3**: CONFIRMED mechanically. PRACTICALLY REFUTED for ecosystem-wide adoption — `-enable-testing` is a module-wide compile flag with optimization implications; not acceptable for production-shipped L2 modules.
- **V4**: CONFIRMED within one Package.swift. STRUCTURALLY REFUTED for our cross-stack consumer topology where each layer is its own SPM package — `package` does not span sibling Package.swift files.
- **V5**: CONFIRMED mechanically. STRUCTURALLY REFUTED by [PLAT-ARCH-008a] (consumers must not bypass the platform stack to import platform C).
- **V6**: REFUTED — typed-only at every layer cannot cover the enumerated raw-required use cases without unbounded growth of the typed surface.

## Recommendation

See `swift-institute/Research/spi-syscall-phase-out-layering.md`.
