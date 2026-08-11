// MARK: - Ternary Operator E:Error Inference in Non-Throwing Context
// Purpose: Verify Bool? && Bool? and Bool? || Bool? compile in non-throwing contexts
// Hypothesis: Compiler should infer E = Never for typed-throws operators in non-throwing code
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — compiler cannot infer E = Never for `<E: Error>` typed-throws operators.
//         Non-throwing overloads or `throws(Never)` explicit signatures are required.
//         error: generic parameter 'E' could not be inferred
//         Command: swift build
//         Runtime (V7-V9): V7: Optional(false), V8: nil, V9: Optional(true)
//         All passing variants produce correct ternary logic output.
// Date: 2026-03-02

import Logic_Ternary_Primitives

// ============================================================
// FAILING VARIANTS — all use the throws(E) generic operators
// ============================================================

// MARK: - Variant 1: Top-level let binding
// Hypothesis: Bool? && Bool? works at top level
// Result: REFUTED — generic parameter 'E' could not be inferred

//let a: Bool? = true
//let b: Bool? = false
//let v1_and = a && b
//let v1_or = a || b

// MARK: - Variant 2: Computed property on struct
// Hypothesis: Bool? && Bool? works in a non-throwing computed property
// Result: REFUTED — generic parameter 'E' could not be inferred

//struct V2 {
//    let x: Bool?
//    let y: Bool?
//    var combined_and: Bool? { x && y }
//    var combined_or: Bool? { x || y }
//}

// MARK: - Variant 3: Non-throwing init
// Hypothesis: Bool? && Bool? works inside a non-throwing initializer
// Result: REFUTED — generic parameter 'E' could not be inferred

//struct V3 {
//    let result: Bool?
//    init(a: Bool?, b: Bool?) {
//        self.result = a && b
//    }
//}

// MARK: - Variant 4: Failable init (init?)
// Hypothesis: Bool? && Bool? works inside init?
// Result: REFUTED — generic parameter 'E' could not be inferred

//struct V4 {
//    let result: Bool?
//    init?(a: Bool?, b: Bool?) {
//        self.result = a || b
//    }
//}

// MARK: - Variant 5: Chained operators
// Hypothesis: Bool? && Bool? && Bool? chains work
// Result: REFUTED — generic parameter 'E' could not be inferred

//struct V5 {
//    let x: Bool?
//    let y: Bool?
//    let z: Bool?
//    var all: Bool? { x && y && z }
//    var any: Bool? { x || y || z }
//    var mixed: Bool? { (x && y) || z }
//}

// MARK: - Variant 6: Matches Boek2.Artikel7 pattern exactly
// Hypothesis: The exact pattern from the failing production code compiles
// Result: REFUTED — generic parameter 'E' could not be inferred

//struct Artikel7: Sendable, Hashable, Codable {
//    let prop_a: Bool?
//    let prop_b: Bool?
//}
//extension Artikel7 {
//    var combined: Bool? { prop_a && prop_b }
//}

// ============================================================
// PASSING VARIANTS — alternative operator signatures
// ============================================================

// MARK: - Variant 7: Non-throwing free function (control)
// Hypothesis: A non-throwing function for Bool? works in computed properties
// Result: CONFIRMED — Build Succeeded

func ternaryAnd(_ lhs: Bool?, _ rhs: Bool?) -> Bool? {
    if lhs == false { return false }
    if rhs == false { return false }
    if lhs == nil || rhs == nil { return nil }
    return true
}

struct V7 {
    let x: Bool?
    let y: Bool?
    var combined: Bool? { ternaryAnd(x, y) }
}

let v7 = V7(x: true, y: false)
print("V7: \(String(describing: v7.combined))")

// MARK: - Variant 8: Non-throwing operator (no generics)
// Hypothesis: A non-throwing operator without generic E works
// Result: CONFIRMED — Build Succeeded

infix operator &&! : LogicalConjunctionPrecedence
func &&! (lhs: Bool?, rhs: @autoclosure () -> Bool?) -> Bool? {
    if lhs == false { return false }
    let r = rhs()
    if r == false { return false }
    if lhs == nil || r == nil { return nil }
    return true
}

struct V8 {
    let x: Bool?
    let y: Bool?
    var combined: Bool? { x &&! y }
}

let v8 = V8(x: true, y: nil)
print("V8: \(String(describing: v8.combined))")

// MARK: - Variant 9: throws(Never) explicit (with generic T)
// Hypothesis: Using throws(Never) explicitly instead of generic E compiles
// Result: CONFIRMED — Build Succeeded
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

infix operator &&? : LogicalConjunctionPrecedence
func &&? <T: Logic.Ternary.`Protocol`>(
    lhs: T,
    rhs: @autoclosure () throws(Never) -> T
) -> T {
    if T.from(lhs) == false { return .false }
    let rhsValue = rhs()
    if T.from(rhsValue) == false { return .false }
    if T.from(lhs) == nil || T.from(rhsValue) == nil { return .unknown }
    return .true
}

struct V9 {
    let x: Bool?
    let y: Bool?
    var combined: Bool? { x &&? y }
}

let v9 = V9(x: true, y: true)
print("V9: \(String(describing: v9.combined))")

// MARK: - Results Summary
// V1: REFUTED — top-level let, E not inferred
// V2: REFUTED — computed property, E not inferred
// V3: REFUTED — init body, E not inferred
// V4: REFUTED — init? body, E not inferred
// V5: REFUTED — chained, E not inferred
// V6: REFUTED — production replica, E not inferred
// V7: CONFIRMED — non-throwing free function works
// V8: CONFIRMED — non-throwing operator (no generic E) works
// V9: CONFIRMED — throws(Never) explicit works
//
// Conclusion: The `<E: Error>` generic parameter on the && and || operators
// prevents the compiler from inferring E = Never in non-throwing contexts.
// This is a Swift compiler limitation with typed throws inference on operators.
//
// Fix: Add non-throwing overloads to Logic.Ternary.swift that shadow the
// throwing variants, OR replace `<E: Error>` with concrete `throws(Never)`.
// V9 proves the generic T constraint works fine — only the E parameter is
// the problem.
