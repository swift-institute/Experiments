// MARK: - async let Typed Throws Verification
// Purpose: Verify whether async let preserves typed throws or erases to any Error
// Hypothesis: async let erases to any Error — try await on async let binding
//   throws `any Error` regardless of the child expression's typed throw.
//
// Toolchain: Swift 6.3
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — async let and withThrowingTaskGroup both erase to any Error (Swift 6.3)
// Evidence: V1/V2 — "thrown expression type 'any Error' cannot be converted to error type 'MyError'"
//           V4 — "cannot convert value of type '(inout ThrowingTaskGroup<Void, MyError>)...'"
//           V5 — Result wrapper workaround: CONFIRMED (Build Succeeded, Output: "failure failed")
// Date: 2026-04-06

enum MyError: Error, Equatable {
    case failed
    case other
}

// MARK: - V1: async let erases throws(MyError) to any Error
// Hypothesis: do throws(MyError) { try await asyncLetResult } fails to compile
// Result: CONFIRMED — "thrown expression type 'any Error' cannot be converted to error type 'MyError'"

func throwsTyped() async throws(MyError) -> Int {
    throw .failed
}

func testV1() async {
    async let result = throwsTyped()
    // do throws(MyError) { try await result }  // DOES NOT COMPILE
    // Error: thrown expression type 'any Error' cannot be converted to error type 'MyError'
    do {
        let _ = try await result
        print("V1: unexpected success")
    } catch {
        print("V1: caught \(error), type = \(type(of: error))")
        // error is `any Error` at compile time, MyError at runtime
    }
}

// MARK: - V2: inline closure same behavior
// Hypothesis: async let with inline throws(MyError) closure also erases
// Result: CONFIRMED — same error as V1

func testV2() async {
    async let result: Int = {
        throw MyError.failed
    }()
    // do throws(MyError) { try await result }  // DOES NOT COMPILE — same error
    do {
        let _ = try await result
        print("V2: unexpected success")
    } catch {
        print("V2: caught \(error), type = \(type(of: error))")
    }
}

// MARK: - V3: non-throwing baseline
// Result: CONFIRMED — works

func noThrow() async -> Int { 42 }

func testV3() async {
    async let result = noThrow()
    let value = await result
    print("V3: value = \(value)")
}

// MARK: - V4: withThrowingTaskGroup hardcodes Failure = any Error
// Hypothesis: ThrowingTaskGroup<T, MyError> can be requested via type annotation
// Result: REFUTED — withThrowingTaskGroup only accepts ThrowingTaskGroup<T, any Error>
//   Error: "cannot convert value of type '(inout ThrowingTaskGroup<Void, MyError>)...'
//          to expected argument type '(inout ThrowingTaskGroup<Void, any Error>)...'"

func testV4() async {
    do {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                throw MyError.failed
            }
            try await group.waitForAll()
        }
        print("V4: unexpected success")
    } catch {
        print("V4: caught \(error), type = \(type(of: error))")
    }
}

// MARK: - V5: Result wrapper — typed throws workaround
// Hypothesis: Capturing error in Result<T, MyError> inside async let avoids the
//   erased throw path entirely. await is non-throwing; error is typed in the Result.
// Result: CONFIRMED — Build Succeeded, Output: "failure failed, type = MyError"

func testV5() async {
    async let writeResult: Result<Int, MyError> = {
        do throws(MyError) {
            return .success(try await throwsTyped())
        } catch {
            return .failure(error)
        }
    }()

    // Non-throwing await — error is inside the Result
    let wr = await writeResult
    switch wr {
    case .success(let v):
        print("V5: success \(v)")
    case .failure(let e):
        print("V5: failure \(e), type = \(type(of: e))")
    }
}

// MARK: - Run

await testV1()
await testV2()
await testV3()
await testV4()
await testV5()

// MARK: - Results Summary
// V1: CONFIRMED — async let + throws(MyError) erases to any Error
// V2: CONFIRMED — async let + inline closure same erasure
// V3: CONFIRMED — non-throwing baseline works
// V4: REFUTED  — withThrowingTaskGroup Failure is always any Error; typed Failure not available
// V5: CONFIRMED — Result wrapper avoids erased throw (Output: "failure failed, type = MyError")
