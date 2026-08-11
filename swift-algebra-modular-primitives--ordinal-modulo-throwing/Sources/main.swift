// MARK: - Ordinal Modulo Throwing Investigation
// Purpose: Isolate why `Ordinal(.one) % Tag.capacity` requires `try`
// Hypothesis: Affine_Primitives introduces a throwing Ordinal.init(_ vector:)
//             that competes with the non-throwing Ordinal.init(_ count: Cardinal)
//             when resolving `.one`
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Affine_Primitives defines `Ordinal.init(_ vector: Affine.Discrete.Vector) throws(Error)`
//         in Ordinal+Affine.swift:21. Since `Affine.Discrete.Vector` also has `.one`,
//         `Ordinal(.one)` becomes ambiguous between:
//           1. Ordinal(Cardinal.one)                — non-throwing
//           2. Ordinal(Affine.Discrete.Vector.one)  — throws(Ordinal.Error)
//         The compiler selects the throwing overload.
//         Fix: disambiguate with `Ordinal(Cardinal.one)`.
// Date: 2026-02-11

import Ordinal_Primitives
import Cardinal_Primitives
import Affine_Primitives

// MARK: - Reproduction: Ordinal(.one) throws with Affine_Primitives imported
// Result: CONFIRMED — error: call can throw, but it is not marked with 'try'

// func reproduction() {
//     let _ = Ordinal(.one)  // ❌ Ambiguous .one
// }

// MARK: - Fix: Explicit Cardinal.one disambiguates
// Result: CONFIRMED — Build Succeeded
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

func fix() {
    let _ = Ordinal(Cardinal.one) % Cardinal(7)
}

fix()
print("Done")
