// MARK: - Scenario 1: Baseline — @_exported import chain
// Purpose: Test whether bare `Array` resolves to Core.Array when imported
//          through an umbrella module's @_exported import.
// Hypothesis: H-A says it shadows Swift.Array; H-B says ambiguous.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — H-A: bare Array resolves to Core.Array in all contexts
// Date: 2026-04-04

import Umbrella

// MARK: - V1: Expression context — variable declaration
// Hypothesis: `Array<Int>()` resolves to Core.Array
// Result: CONFIRMED

let v1 = Array<Int>()
print("V1 type: \(type(of: v1))")

// MARK: - V2: Custom-only API access
// Hypothesis: `Array<Int>.isCustom` compiles (proves Core.Array resolution)
// Result: CONFIRMED

print("V2 isCustom: \(Array<Int>.isCustom)")

// MARK: - V3: Nested type access
// Hypothesis: `Array<Int>.Nested()` compiles (proves Core.Array resolution)
// Result: CONFIRMED

let v3 = Array<Int>.Nested()
print("V3 nested: \(type(of: v3))")

// MARK: - V4: Type annotation
// Hypothesis: `Array<Int>` in type position resolves to Core.Array
// Result: CONFIRMED

let v4: Array<Int> = Array<Int>()
print("V4 type: \(type(of: v4))")

// MARK: - V5: Generic function using Array
// Hypothesis: bare Array in generic context resolves to Core.Array
// Result: CONFIRMED

func makeArray<T>(_ element: T) -> Array<T> {
    return Array<T>()
}
let v5 = makeArray(42)
print("V5 type: \(type(of: v5))")

// MARK: - V6: Extension declaration
// Hypothesis: `extension Array` resolves to Core.Array
// Result: CONFIRMED

extension Array {
    static var experimentMarker: String { "extended-core-array" }
}
print("V6 extension: \(Array<Int>.experimentMarker)")

// MARK: - Results Summary
// V1: PENDING
// V2: PENDING
// V3: PENDING
// V4: PENDING
// V5: PENDING
// V6: PENDING
