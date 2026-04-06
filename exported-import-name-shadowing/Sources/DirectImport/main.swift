// MARK: - Scenario 2: Direct import of Core
// Purpose: Test whether bare `Array` resolves to Core.Array when Core
//          is imported directly (no @_exported intermediary).
// Hypothesis: Direct import should give Core.Array precedence over Swift.Array.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Direct import gives Core.Array precedence
// Date: 2026-04-04

import Core

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
