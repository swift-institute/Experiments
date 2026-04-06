// MARK: - Scenario 6: Edge cases — sugar syntax, conformances, literals
// Purpose: Test edge cases that may break bare Array resolution:
//          - [T] sugar always means Swift.Array — does this cause type conflicts?
//          - Protocol conformances that Swift.Array also has
//          - Array literal syntax ([1, 2, 3])
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — [T] sugar remains Swift.Array; Array<T> resolves to Core.Array; conformances work
// Date: 2026-04-04

import Umbrella

// MARK: - V1: [T] sugar is always Swift.Array
// Hypothesis: [Int] remains Swift.Array even when bare Array is Core.Array
// Result: CONFIRMED

let v1_sugar: [Int] = [1, 2, 3]
let v1_bare = Array<Int>()
print("V1 sugar type: \(type(of: v1_sugar))")  // Should be Swift.Array
print("V1 bare type: \(type(of: v1_bare))")    // Should be Core.Array

// MARK: - V2: Explicit Swift.Array access
// Hypothesis: Swift.Array still accessible with qualification
// Result: CONFIRMED

let v2: Swift.Array<Int> = [1, 2, 3]
print("V2 Swift.Array: \(type(of: v2))")

// MARK: - V3: CustomStringConvertible conformance on Core.Array
// Hypothesis: Can add conformance to Core.Array that Swift.Array also has
// Result: CONFIRMED

extension Array: CustomStringConvertible {
    public var description: String { "Core.Array(count: \(count))" }
}
let v3 = Array<Int>()
print("V3 description: \(v3.description)")

// MARK: - V4: Equatable conformance (when elements are Equatable)
// Hypothesis: Can add Equatable to Core.Array without conflicting with Swift.Array's Equatable
// Result: CONFIRMED

extension Array: Equatable where Element: Equatable {
    public static func == (lhs: Array, rhs: Array) -> Bool {
        lhs.count == rhs.count
    }
}
let v4a = Array<Int>()
let v4b = Array<Int>()
print("V4 equatable: \(v4a == v4b)")

// MARK: - V5: Function that returns [T] — does [T] in return type mean Swift.Array?
// Hypothesis: [T] in return type is Swift.Array, Array<T> in return type is Core.Array
// Result: CONFIRMED

func returnSugar() -> [Int] { [1, 2, 3] }
func returnBare() -> Array<Int> { Array<Int>() }
print("V5 sugar return: \(type(of: returnSugar()))")
print("V5 bare return: \(type(of: returnBare()))")

// MARK: - Results Summary
// V1: CONFIRMED
// V2: CONFIRMED
// V3: CONFIRMED
// V4: CONFIRMED
// V5: CONFIRMED
