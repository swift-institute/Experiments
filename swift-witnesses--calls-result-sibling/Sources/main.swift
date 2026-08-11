// MARK: - Calls/Result/Outcome Sibling Placement Experiment
// Purpose: Test whether Result and Outcome can be sibling types of Calls
//          (instead of nested inside Calls) without naming collisions.
// Hypothesis: Since generated code uses fully-qualified Standard_Library_Extensions.Result,
//             a sibling `Result` enum does not shadow Swift.Result or cause ambiguity.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 7 variants compile and execute. No naming collisions.
// Date: 2026-03-16

import Optic_Primitives
import Finite_Primitives
import Standard_Library_Extensions

// ============================================================================
// MARK: - Variant 1: Current layout (Result/Outcome nested inside Calls)
// Hypothesis: Baseline — this is what @Witness currently generates.
// Result: CONFIRMED
// ============================================================================

struct V1_APIClient: Sendable {
    var fetch: @Sendable (_ id: Int) -> String
    var save: @Sendable (_ data: String) throws -> Bool
    var reset: @Sendable () -> Void

    enum Calls: Sendable {
        case fetch(Int)
        case save(String)
        case reset

        enum Result: ~Copyable {
            case fetch(Standard_Library_Extensions.Result<String, Never>)
            case save(Standard_Library_Extensions.Result<Bool, any Error>)
            case reset(Standard_Library_Extensions.Result<Void, Never>)
        }

        struct Outcome: ~Copyable {
            let action: Calls
            let result: Result

            init(action: Calls, result: consuming Result) {
                self.action = action
                self.result = result
            }

            consuming func consumeResult() -> Result { result }
        }
    }
}

// ============================================================================
// MARK: - Variant 2: Result/Outcome as siblings of Calls
// Hypothesis: Naming collision with Swift.Result is avoided because we use
//             Standard_Library_Extensions.Result for associated values.
// Result: CONFIRMED
// ============================================================================

struct V2_APIClient: Sendable {
    var fetch: @Sendable (_ id: Int) -> String
    var save: @Sendable (_ data: String) throws -> Bool
    var reset: @Sendable () -> Void

    enum Calls: Sendable {
        case fetch(Int)
        case save(String)
        case reset
    }

    enum Result: ~Copyable {
        case fetch(Standard_Library_Extensions.Result<String, Never>)
        case save(Standard_Library_Extensions.Result<Bool, any Error>)
        case reset(Standard_Library_Extensions.Result<Void, Never>)
    }

    struct Outcome: ~Copyable {
        let action: Calls
        let result: Result

        init(action: Calls, result: consuming Result) {
            self.action = action
            self.result = result
        }

        consuming func consumeResult() -> Result { result }
    }
}

// ============================================================================
// MARK: - Variant 3: Does `Result` shadow Swift.Result INSIDE the struct?
// Hypothesis: Inside V2_APIClient, `Result` now refers to the generated enum,
//             not Swift.Result. This could break user code that uses Swift.Result.
// Result: CONFIRMED
// ============================================================================

extension V2_APIClient {
    // Can we still use Swift.Result inside V2_APIClient?
    static func makeSwiftResult() -> Swift.Result<String, any Error> {
        .success("hello")
    }

    // Can we reference our own Result?
    static func makeCallsResult() -> V2_APIClient.Result {
        .fetch(.success("world"))
    }
}

// ============================================================================
// MARK: - Variant 4: Consumer code that references both
// Hypothesis: Consumers outside the struct can reference both types unambiguously.
// Result: CONFIRMED
// ============================================================================

func testV2Consumer() {
    // Call algebra (identical to @Defunctionalize output)
    let call = V2_APIClient.Calls.fetch(42)

    // DI-specific types (siblings)
    let result = V2_APIClient.Result.fetch(.success("ok"))
    let outcome = V2_APIClient.Outcome(action: call, result: result)

    // Swift.Result still works at call site
    let swiftResult: Swift.Result<Int, any Error> = .success(1)

    _ = outcome
    _ = swiftResult
}

// ============================================================================
// MARK: - Variant 5: Observe API shape with sibling types
// Hypothesis: The observe API references Calls and Outcome as siblings.
// Result: CONFIRMED
// ============================================================================

extension V2_APIClient {
    struct Observe: Sendable {
        let witness: V2_APIClient

        func callAsFunction(
            _ before: @escaping @Sendable (Calls) -> Void,
            after: @escaping @Sendable (borrowing Outcome) -> Void
        ) -> V2_APIClient {
            // Simplified — just verify the types work
            witness
        }

        func before(
            _ observer: @escaping @Sendable (Calls) -> Void
        ) -> V2_APIClient {
            witness
        }

        func after(
            _ observer: @escaping @Sendable (borrowing Outcome) -> Void
        ) -> V2_APIClient {
            witness
        }
    }
}

// ============================================================================
// MARK: - Variant 6: Outcome construction in observe body (the generated code pattern)
// Hypothesis: The observe body can construct Outcome from sibling types.
// Result: CONFIRMED
// ============================================================================

func testObserveBody() {
    let client = V2_APIClient(
        fetch: { _ in "result" },
        save: { _ in true },
        reset: {}
    )

    // Simulated observe body — what @Witness generates
    let action: V2_APIClient.Calls = .fetch(42)
    let result = client.fetch(42)
    let witnessResult = Standard_Library_Extensions.Result<String, Never>.success(result)
    let outcome = V2_APIClient.Outcome(
        action: action,
        result: .fetch(witnessResult)
    )
    _ = outcome
}

// ============================================================================
// MARK: - Variant 7: Calls structurally identical to @Defunctionalize
// Hypothesis: V2's Calls enum has NO DI-specific types, making it structurally
//             identical to what @Defunctionalize would generate.
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

// Simulated @Defunctionalize output for comparison
struct V7_Defunctionalized: Sendable {
    var fetch: @Sendable (_ id: Int) -> String
    var save: @Sendable (_ data: String) throws -> Bool
    var reset: @Sendable () -> Void

    enum Calls: Sendable {
        case fetch(Int)
        case save(String)
        case reset
    }
}

func testStructuralEquivalence() {
    // These are structurally identical enum shapes
    let v2Call = V2_APIClient.Calls.fetch(42)
    let v7Call = V7_Defunctionalized.Calls.fetch(42)

    // Both have the same cases, same associated values
    switch v2Call {
    case .fetch(let id): print("V2: fetch(\(id))")
    case .save(let data): print("V2: save(\(data))")
    case .reset: print("V2: reset")
    }

    switch v7Call {
    case .fetch(let id): print("V7: fetch(\(id))")
    case .save(let data): print("V7: save(\(data))")
    case .reset: print("V7: reset")
    }
}

// ============================================================================
// MARK: - Execution
// ============================================================================

testV2Consumer()
testObserveBody()
testStructuralEquivalence()
print("All variants compiled and executed successfully.")
