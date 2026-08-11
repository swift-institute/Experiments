// MARK: - Typed Throws Autoclosure E Inference
// Purpose: Find minimal fix for E = Never inference failure in
//          @autoclosure () throws(E) -> Value where E: Swift.Error.
//          100% typed throws throughout. No existentials, no untyped throws.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — @autoclosure () throws(E) -> Value has a fundamental
//         E inference bug in Swift 6.2. E cannot be inferred in ANY context:
//         not from non-throwing expressions, not even from typed-throwing
//         expressions like `try f()` where `f: () throws(MyError) -> T`.
//
//         Solution: Replace the @autoclosure signature with a plain Value
//         parameter. The `assertSnapshot` function evaluates the value at the
//         call site (eager evaluation), which is acceptable because snapshot
//         testing doesn't need lazy evaluation semantics. The `capturing:`
//         label distinguishes this from any future autoclosure overload.
//
//         When Swift fixes the E inference bug, the autoclosure version can
//         be reinstated.
//
// Date: 2026-02-28

// MARK: - Setup

struct Expectation: CustomStringConvertible {
    let isPassing: Bool
    var description: String { isPassing ? "PASS" : "FAIL" }
}

struct Strategy<Value, Format> {}

// MARK: - Core logic (shared)

private func _verify<Value, Format>(
    of capturedValue: Value,
    as strategy: Strategy<Value, Format>
) -> Expectation {
    Expectation(isPassing: true)
}

// MARK: - Phase 1: Confirm E inference failure is total
//
// func autoclosureCheck<Value, Format, E: Error>(
//     of value: @autoclosure () throws(E) -> Value,
//     as strategy: Strategy<Value, Format>
// ) -> Expectation { ... }
//
// enum TestError: Error { case boom }
// func mayThrow() throws(TestError) -> Int { 42 }
//
// autoclosureCheck(of: 42, as: s)              // ERROR: E could not be inferred
// autoclosureCheck(of: try mayThrow(), as: s)  // ERROR: E could not be inferred
//
// E cannot be inferred even from explicitly typed-throwing expressions.
// Result: CONFIRMED — @autoclosure typed throws E inference is totally broken.

// MARK: - Phase 2: Captured-value entry point (the fix)
// Hypothesis: Replace @autoclosure with plain Value. The function catches
//             errors at the call site (eager evaluation). No E inference needed.
//             Typed throws preserved: if caller has a throwing expression, they
//             use `try` at the call site and pass the result.
// Result: CONFIRMED — Build Succeeded, all variants pass.

func check<Value, Format>(
    capturing value: Value,
    as strategy: Strategy<Value, Format>
) -> Expectation {
    _verify(of: value, as: strategy)
}

// MARK: - Phase 3: Bridge wrapper (simulates __expectSnapshot -> assertSnapshot)
// Hypothesis: Bridge takes plain Value, calls `capturing:` entry point.
// Result: CONFIRMED — Build Succeeded

func bridge<Value, Format>(
    _ value: Value,
    as strategy: Strategy<Value, Format>
) -> Expectation {
    check(capturing: value, as: strategy)
}

// MARK: - Phase 4: Typed throws at call site (caller handles try)
// Hypothesis: When the value expression throws, the caller uses `try` and
//             the typed error propagates. The function takes the result Value.
// Result: CONFIRMED — Build Succeeded
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

enum TestError: Error { case boom }
func mayThrow() throws(TestError) -> Int { 42 }

func callerHandlesTry() throws(TestError) -> Expectation {
    check(capturing: try mayThrow(), as: Strategy<Int, String>())
}

// MARK: - Execution

let s = Strategy<Int, String>()

let p1 = check(capturing: 42, as: s)
print("Phase 2 (capturing, direct):        \(p1)")  // Output: PASS

let p2 = bridge(42, as: s)
print("Phase 3 (bridge -> capturing):      \(p2)")  // Output: PASS

func genericBridge<Value, Format>(
    _ value: Value,
    as strategy: Strategy<Value, Format>
) -> Expectation {
    check(capturing: value, as: strategy)
}

let p3 = genericBridge(42, as: s)
print("Phase 3b (generic bridge):          \(p3)")  // Output: PASS

let p4 = try callerHandlesTry()
print("Phase 4 (caller try, typed throws): \(p4)")  // Output: PASS

// MARK: - Results Summary
// Phase 1: CONFIRMED — E inference totally broken on @autoclosure () throws(E)
// Phase 2: CONFIRMED — captured-value entry point works
// Phase 3: CONFIRMED — bridge pattern works
// Phase 3b: CONFIRMED — generic bridge works
// Phase 4: CONFIRMED — typed throws preserved at caller's try site
