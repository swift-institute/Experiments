// MARK: - without-spi driver — exercises every variant WITHOUT @_spi import
//
// Purpose: Cross-module driver per [EXP-017]. Imports Definitions WITHOUT
//          the `@_spi(Unchecked)` access path. The SPI-gated unchecked init
//          on V5 MUST be invisible (compile error if referenced). The
//          throwing init on V5 remains visible (plain `public`).
//          V2 has no SPI annotations so both its inits remain visible.
//
// Toolchain: swift-6.3
// Platform:  macOS 26 (arm64)
// Date:      2026-05-02
// Result:    Build success = the SPI-gated init on V5 is correctly hidden
//            when not imported under SPI.

import Definitions

// MARK: - V2 (no SPI annotations — both inits visible)

let v2Plain = V2(__unchecked: (), 11)
print("V2 plain (empty-tuple visible without SPI import):", v2Plain.value)

do {
    let v2Validated = try V2(11)
    print("V2 validated:", v2Validated.value)
} catch {
    print("V2 validated (unexpected error):", error)
}

// MARK: - V5 (SPI'd unchecked init INVISIBLE without SPI import)
//
// Without `@_spi(Unchecked) import Definitions`, the unchecked init is
// hidden. ONLY the throwing init is callable here.
//
// Visibility evidence: if the next line WERE uncommented, the compiler
// MUST reject it (the SPI'd init is unimported):
//
//     let v5Plain = V5(__unchecked: (), 17)
//
// Probe (since reverted) verified the SPI gating empirically — uncommenting
//
//     let v5SpiProbe = V5(__unchecked: (), 17)
//
// produced the diagnostic (Swift 6.3, 2026-05-02):
//
//     error: extra argument in call
//     error: cannot convert value of type '()' to expected argument type 'UInt64'
//
// The compiler attempted to resolve the call against the ONLY visible init
// `init(_ value: UInt64) throws(V5Error)`, surfacing two errors when the
// arguments did not match. The SPI'd `init(__unchecked: (), _:)` was not
// even a candidate, confirming `@_spi(Unchecked)` correctly hides the
// declaration when not imported under SPI.
//
// See `Outputs/probe-spi-invisibility.txt` for the captured diagnostic.

do {
    let v5Validated = try V5(17)
    print("V5 validated (throwing-only path, no SPI):", v5Validated.value)
} catch {
    print("V5 validated (unexpected error):", error)
}

print("without-spi: V2 + V5 throwing-only paths exercised")
