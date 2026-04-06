// MARK: - Scenario 4: Deep @_exported chain (3 levels)
// Purpose: Test whether Array still resolves through a deeper chain:
//          DeepChain → MiddleLayer → Umbrella → Core
//          (mirrors: Consumer → Graph_Primitives_Core → Array_Primitives → Array_Primitives_Core)
// Hypothesis: Deeper @_exported chains still give Core.Array precedence.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — 3 levels of @_exported still resolves correctly
// Date: 2026-04-04

import MiddleLayer

// MARK: - V1: Expression context
// Result: CONFIRMED

let v1 = Array<Int>()
print("V1 type: \(type(of: v1))")

// MARK: - V2: Custom-only API access
// Result: CONFIRMED

print("V2 isCustom: \(Array<Int>.isCustom)")

// MARK: - V3: Nested type access
// Result: CONFIRMED

let v3 = Array<Int>.Nested()
print("V3 nested: \(type(of: v3))")

// MARK: - V4: Extension declaration
// Result: CONFIRMED

extension Array {
    static var experimentMarker: String { "extended-core-array" }
}
print("V4 extension: \(Array<Int>.experimentMarker)")

// MARK: - Results Summary
// V1: CONFIRMED
// V2: CONFIRMED
// V3: CONFIRMED
// V4: CONFIRMED
