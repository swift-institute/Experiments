// MARK: - with-spi driver — exercises every variant with @_spi(Unchecked) import
//
// Purpose: Cross-module driver per [EXP-017]. Imports Definitions WITH the
//          `@_spi(Unchecked)` access path. Exercises V2 (empty-tuple control)
//          and V5 (proposed migration shape). V1/V3/V4 do not produce code
//          surfaces (they are commented out as REFUTED evidence in
//          Definitions.swift).
//
// Toolchain: swift-6.3
// Platform:  macOS 26 (arm64)
// Date:      2026-05-02
// Result:    Build success + expected runtime output is the evidence that
//            V2 and V5 both work as overload-resolved cross-module surfaces.

@_spi(Unchecked) import Definitions

// MARK: - V2 (empty-tuple control)

let v2Plain = V2(__unchecked: (), 11)
print("V2 plain (empty-tuple bypass):", v2Plain.value)

do {
    let v2Validated = try V2(11)
    print("V2 validated (throwing, success):", v2Validated.value)
} catch {
    print("V2 validated (throwing, unexpected error):", error)
}

do {
    _ = try V2(0)
    print("V2 validated (throwing, unexpected success)")
} catch {
    print("V2 validated (throwing, expected error):", error)
}

// MARK: - V5 (SPI + empty-tuple, fixed shape via @usableFromInline internal)
//
// With `@_spi(Unchecked) import Definitions`, the empty-tuple unchecked init
// is callable. Without the SPI import (see without-spi target) it would not
// be visible.

let v5Plain = V5(__unchecked: (), 17)
print("V5 plain (SPI + empty-tuple bypass):", v5Plain.value)

do {
    let v5Validated = try V5(17)
    print("V5 validated (throwing, success):", v5Validated.value)
} catch {
    print("V5 validated (throwing, unexpected error):", error)
}

do {
    _ = try V5(0)
    print("V5 validated (throwing, unexpected success)")
} catch {
    print("V5 validated (throwing, expected error):", error)
}

print("with-spi: V2 + V5 exercised cross-module under SPI import")
