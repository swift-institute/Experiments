// MARK: - Scenario 7: Type identity — [T] vs Array<T> vs Swift.Array<T>
// Purpose: Verify that [T] remains Swift.Array and bare Array<T> is Core.Array,
//          and that these are truly distinct types.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — [T] is Swift.Array, bare Array is Core.Array, they are distinct types
// Date: 2026-04-04

import Umbrella

// MARK: - V1: Module-qualified type identity
// Result: CONFIRMED

func isCoreArray<T>(_ value: Core.Array<T>) -> Bool { true }
func isSwiftArray<T>(_ value: Swift.Array<T>) -> Bool { true }

let bare = Array<Int>()
let sugar: [Int] = [1, 2, 3]
let explicit: Swift.Array<Int> = [4, 5, 6]

// If bare `Array` is Core.Array, this compiles:
print("V1 bare is Core.Array: \(isCoreArray(bare))")
// If [T] sugar is Swift.Array, this compiles:
print("V1 sugar is Swift.Array: \(isSwiftArray(sugar))")
print("V1 explicit is Swift.Array: \(isSwiftArray(explicit))")

// MARK: - V2: [T] sugar and Swift.Array are the same type
// Result: CONFIRMED

let v2_sugar: [Int] = [1, 2, 3]
let v2_explicit: Swift.Array<Int> = v2_sugar  // Same type — should compile
print("V2 [T] == Swift.Array<T>: true (compiled)")

// MARK: - V3: Core.Array and Swift.Array are distinct
// Result: CONFIRMED
// NOTE: Uncomment the following to verify type error:
// let typeError: Array<Int> = sugar  // Should fail: Swift.Array<Int> != Core.Array<Int>

// MARK: - V4: Module-qualified printing
// Result: CONFIRMED

print("V4 bare module: \(Swift.Array<Int>.self == type(of: sugar))")
print("V4 bare module: \(Core.Array<Int>.self == type(of: bare))")

// MARK: - Results Summary
// V1: CONFIRMED — bare is Core.Array, sugar is Swift.Array
// V2: CONFIRMED — [T] and Swift.Array<T> are the same type
// V3: CONFIRMED — Core.Array and Swift.Array are distinct (type error)
// V4: CONFIRMED — metatype comparison
