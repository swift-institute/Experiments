// MARK: - Scenario 5: Multiple independent imports both re-exporting Core
// Purpose: Test whether importing two separate modules that both @_exported
//          import Core creates ambiguity for bare `Array`.
//          (mirrors: importing both Array_Primitives AND Array_Bounded_Primitives)
// Hypothesis: Same type from same module through different paths is NOT ambiguous.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Multiple re-export paths do not create ambiguity
// Date: 2026-04-04

import SiblingA
import SiblingB

// MARK: - V1: Expression context
// Result: CONFIRMED

let v1 = Array<Int>()
print("V1 type: \(type(of: v1))")

// MARK: - V2: Custom-only API access
// Result: CONFIRMED

print("V2 isCustom: \(Array<Int>.isCustom)")

// MARK: - V3: Extension declaration
// Result: CONFIRMED

extension Array {
    static var experimentMarker: String { "extended-core-array" }
}
print("V3 extension: \(Array<Int>.experimentMarker)")

// MARK: - Results Summary
// V1: CONFIRMED
// V2: CONFIRMED
// V3: CONFIRMED
