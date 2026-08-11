// Status: SUPERSEDED -- borrow-then-consume-extract pattern shipped in Witness.Result + Action.Outcome. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// Experiment: Validate borrow-then-consume-extract pattern
//
// Tests the critical pattern where an observer borrows an Outcome,
// then after the borrow ends, the Outcome is consumed to extract the result.

// MARK: - Types

struct Handle: ~Copyable, Sendable { let fd: Int }

enum CustomError: Error, Sendable { case failed }

// Simulates Witness.Result — ~Copyable-aware
enum WResult<T: ~Copyable & Sendable, E: Error & Sendable>: ~Copyable, Sendable {
    case success(T)
    case failure(E)
}
extension WResult: Copyable where T: Copyable {}

// Simulates Action.Result (heterogeneous, concrete)
enum Result: ~Copyable, Sendable {
    case fetch(WResult<String, any Error>)
    case create(WResult<Handle, any Error>)
    case close(WResult<Void, Never>)
}

// Simulates Action.Outcome
struct Outcome: ~Copyable, Sendable {
    let action: String
    let result: Result

    consuming func __consumeResult() -> Result { result }
}

// MARK: - Test 1: Non-Void ~Copyable return (the critical pattern)

func testBorrowThenConsumeNoncopyable() -> Handle {
    let handle = Handle(fd: 1)
    let outcome = Outcome(action: "create", result: .create(.success(handle)))

    let observer: (borrowing Outcome) -> Void = { o in
        print("  observed: \(o.action)")
    }
    observer(outcome)

    let __result = outcome.__consumeResult()
    switch consume __result {
    case .create(.success(let value)): return value
    default: fatalError("unreachable")
    }
}

// MARK: - Test 2: Copyable return

func testBorrowThenConsumeCopyable() -> String {
    let outcome = Outcome(action: "fetch", result: .fetch(.success("hello")))

    let observer: (borrowing Outcome) -> Void = { o in
        print("  observed: \(o.action)")
    }
    observer(outcome)

    let __result = outcome.__consumeResult()
    switch consume __result {
    case .fetch(.success(let value)): return value
    default: fatalError("unreachable")
    }
}

// MARK: - Test 3: Void return

func testBorrowThenConsumeVoid() {
    let outcome = Outcome(action: "close", result: .close(.success(())))

    let observer: (borrowing Outcome) -> Void = { o in
        print("  observed: \(o.action)")
    }
    observer(outcome)
    // No extraction needed for Void — outcome is dropped
}

// MARK: - Test 4: Throwing (error path)

func testBorrowThenConsumeThrowingSuccess() throws -> String {
    let outcome = Outcome(action: "fetch", result: .fetch(.success("ok")))

    let observer: (borrowing Outcome) -> Void = { o in
        print("  observed: \(o.action)")
    }
    observer(outcome)

    let __result = outcome.__consumeResult()
    switch consume __result {
    case .fetch(.success(let value)): return value
    default: fatalError("unreachable")
    }
}

func testBorrowThenConsumeThrowingFailure() throws -> String {
    let error = CustomError.failed
    let outcome = Outcome(action: "fetch", result: .fetch(.failure(error)))

    let observer: (borrowing Outcome) -> Void = { o in
        print("  observed: \(o.action)")
    }
    observer(outcome)
    // In the real macro, we throw error directly (errors are Copyable)
    throw error
}

// MARK: - Test 5: Multiple observer closures

func testMultipleObservers() -> Handle {
    let handle = Handle(fd: 42)
    let outcome = Outcome(action: "create", result: .create(.success(handle)))

    let before: (String) -> Void = { action in
        print("  before: \(action)")
    }
    let after: (borrowing Outcome) -> Void = { o in
        print("  after: \(o.action)")
    }

    before(outcome.action)  // reading action is fine (String is Copyable)
    after(outcome)          // borrow the whole outcome

    let __result = outcome.__consumeResult()
    switch consume __result {
    case .create(.success(let value)): return value
    default: fatalError("unreachable")
    }
}

// MARK: - Run all tests

print("Test 1: Non-Void ~Copyable return")
let h1 = testBorrowThenConsumeNoncopyable()
print("  result: fd=\(h1.fd)")
assert(h1.fd == 1)

print("Test 2: Copyable return")
let s1 = testBorrowThenConsumeCopyable()
print("  result: \(s1)")
assert(s1 == "hello")

print("Test 3: Void return")
testBorrowThenConsumeVoid()
print("  result: ok")

print("Test 4a: Throwing (success path)")
let s2 = try testBorrowThenConsumeThrowingSuccess()
print("  result: \(s2)")
assert(s2 == "ok")

print("Test 4b: Throwing (failure path)")
do {
    _ = try testBorrowThenConsumeThrowingFailure()
    fatalError("expected error")
} catch {
    print("  caught: \(error)")
}

print("Test 5: Multiple observers")
let h2 = testMultipleObservers()
print("  result: fd=\(h2.fd)")
assert(h2.fd == 42)

// MARK: - Test 6: do throws(E) for typed error in catch blocks
// Discovery: `error` in catch blocks inside closures is always `any Error`
// even with typed throws. `do throws(E) { ... } catch { ... }` fixes this.

enum TypedError: Error, Sendable { case boom }

func throwsTyped() throws(TypedError) -> String { throw .boom }

func testDoThrowsTypedCatch() {
    let f = { () throws(TypedError) -> String in
        do throws(TypedError) {
            return try throwsTyped()
        } catch {
            // `error` is TypedError here (not any Error) thanks to do throws(E)
            let r = WResult<String, TypedError>.failure(error)
            print("  do throws(E) catch: \(r)")
            throw error
        }
    }
    do { _ = try f() } catch { print("  caught: \(error)") }
}

print("Test 6: do throws(E) typed catch")
testDoThrowsTypedCatch()

print("\nAll tests passed!")
