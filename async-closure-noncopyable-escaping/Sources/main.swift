// MARK: - ~Copyable consume in closures: what works, what doesn't?
// Purpose: The compiler rejects consuming ~Copyable values inside closures
//   with "noncopyable captured by an escaping closure" — even for closures
//   that appear non-escaping. Determine the exact boundary.
// Hypothesis (revised): ~Copyable values can be BORROWED in closures but
//   never CONSUMED, because closures can be called multiple times and
//   consume invalidates the value. This is a language constraint, not
//   a bug specific to withTaskGroup or async.
//
// Toolchain: Xcode 26.0 beta / Swift 6.3
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — language constraint, not a bug. ~Copyable values can
//   be BORROWED but never CONSUMED across any closure boundary (sync or async,
//   escaping or non-escaping). The error message "captured by an escaping
//   closure" is misleading — it triggers for non-escaping closures too.
//   Transfer.Cell is the permanent pattern for ~Copyable closure crossing.
//   No consuming capture syntax exists in Swift 6.3.
// Date: 2026-04-06

struct Resource: ~Copyable {
    let id: Int
    consuming func use() -> Int { id }
}

// MARK: - V1: Borrow ~Copyable in sync non-escaping closure
// Hypothesis: Borrowing (reading properties) works in any closure.
// Result: CONFIRMED — Output: "V1: 1"

func acceptSync(_ body: () -> Void) { body() }

func v1_borrowInClosure() {
    let r = Resource(id: 1)
    acceptSync {
        print("V1: \(r.id)")  // borrow only
    }
}

// MARK: - V2: Consume ~Copyable in sync non-escaping closure
// Hypothesis: Consuming fails even in non-escaping closures.
// Result: CONFIRMED — fails with "noncopyable captured by escaping closure"
//   even though the closure is NOT @escaping. Misleading error message.
// DISABLED — confirmed failure.
// Error: "noncopyable 'r' cannot be consumed when captured by an escaping
//   closure or borrowed by a non-Escapable type"
// Note: closure IS non-escaping (no @escaping). Error message is misleading.
#if false
func v2_consumeInNonEscaping() {
    let r = Resource(id: 2)
    acceptSync {
        let _ = r.use()  // consume — fails even in sync non-escaping
    }
}
#endif

// MARK: - V3: Consume ~Copyable at function scope (baseline)
// Hypothesis: Consuming at function scope works — no closure involved.
// Result: CONFIRMED — Output: "V3: 3"

func v3_consumeAtFunctionScope() {
    let r = Resource(id: 3)
    let value = r.use()
    print("V3: \(value)")
}

// MARK: - V4: Create ~Copyable INSIDE closure (not captured)
// Hypothesis: If the ~Copyable value is created inside the closure,
//   it's not captured — consume should work.
// Result: CONFIRMED — Output: "V4: 4"

func v4_createInsideClosure() {
    acceptSync {
        let r = Resource(id: 4)
        let value = r.use()
        print("V4: \(value)")
    }
}

// MARK: - V5: Create inside async closure
// Hypothesis: Same as V4 but async. Should still work — value is local.
// Result: CONFIRMED — Output: "V5: 5"

func acceptAsync(_ body: () async -> Void) async { await body() }

func v5_createInsideAsyncClosure() async {
    await acceptAsync {
        let r = Resource(id: 5)
        let value = r.use()
        print("V5: \(value)")
    }
}

// MARK: - V6: Create inside withTaskGroup body
// Hypothesis: Creating and consuming within the body works — the value
//   never crosses the closure boundary.
// Result: CONFIRMED — Output: "V6: 6"

func v6_createInsideTaskGroup() async {
    await withTaskGroup(of: Void.self) { group in
        let r = Resource(id: 6)
        let value = r.use()
        print("V6: \(value)")
    }
}

// MARK: - V7: Borrow in async closure
// Hypothesis: Borrowing works in async closures (same as sync).
// Result: CONFIRMED — Output: "V7: 7"

func v7_borrowInAsyncClosure() async {
    let r = Resource(id: 7)
    await acceptAsync {
        print("V7: \(r.id)")  // borrow only
    }
}

// MARK: - V8: Borrow in withTaskGroup body
// Hypothesis: Borrowing works in withTaskGroup body.
// Already confirmed in prior experiment — included for completeness.
// Result: CONFIRMED — Output: "V8: 8"

func v8_borrowInTaskGroup() async {
    let r = Resource(id: 8)
    await withTaskGroup(of: Void.self) { group in
        print("V8: \(r.id)")  // borrow only
    }
}

// MARK: - V9: Consume via explicit `consume` capture
// Hypothesis: `[consume r]` capture list syntax moves ownership.
// Result: REFUTED — `[consume r]` is a parse error in Swift 6.3.
//   Capture lists only accept `weak`, `unowned`, or no specifier.
//   No consuming capture mechanism exists.
//   Error: "expected 'weak', 'unowned', or no specifier in capture list"
//   (Caught even inside #if false — parse-level rejection)

// MARK: - V10: Mutex<Optional<T>> in @Sendable @escaping closure (addTask)
// Hypothesis: Mutex is Sendable + borrowable. withLock receives inout Optional.
//   take() extracts the ~Copyable value inside the lock. This replaces
//   Transfer.Cell using stdlib types.
// Pattern from Apple's swift-http-api-proposal.
// Result: REFUTED — Mutex<Optional<T>> is ~Copyable + fails data race check.
//   For @Sendable closures, Copyable+Sendable wrapper (Transfer.Cell) is required.

import Synchronization

// DISABLED — Mutex<Optional<T>> is ~Copyable itself. Cannot be captured
//   by addTask's @Sendable sending closure. Also fails data race check:
//   "closure captures reference to mutable let 'cell' which is accessible
//   to code in the current task"
// Apple's Mutex pattern works in non-@Sendable closures, not in addTask.
// For @Sendable closures, a Copyable+Sendable wrapper (Transfer.Cell) is
// still needed.
#if false
func v10_mutexInAddTask() async {
    let r = Resource(id: 10)
    let cell = Mutex(Optional(r))

    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            let value = cell.withLock { $0.take()! }
            print("V10: \(value.id)")
        }
    }
}
#endif

// MARK: - V11: var Optional.take() in non-Sendable async closure
// Hypothesis: var Optional<~Copyable> captured by reference in
//   non-escaping async closure. take() mutates the var.
// Result: CONFIRMED — Output: "V11: 11". Zero overhead alternative to
//   Transfer.Cell for non-@Sendable closures.

func v11_varOptionalTake() async {
    let r = Resource(id: 11)
    var cell = Optional(r)
    await acceptAsync {
        let value = cell.take()!
        print("V11: \(value.id)")
    }
}

// MARK: - V12: var Optional.take() in withTaskGroup body
// Hypothesis: Same as V11 but in withTaskGroup body.
// Result: CONFIRMED — Output: "V12: 12"

func v12_varOptionalInTaskGroup() async {
    let r = Resource(id: 12)
    var cell = Optional(r)
    await withTaskGroup(of: Void.self) { group in
        let value = cell.take()!
        print("V12: \(value.id)")
    }
}

// MARK: - Run

v1_borrowInClosure()
v3_consumeAtFunctionScope()
v4_createInsideClosure()
await v5_createInsideAsyncClosure()
await v6_createInsideTaskGroup()
await v7_borrowInAsyncClosure()
await v8_borrowInTaskGroup()
// v10 disabled
await v11_varOptionalTake()
await v12_varOptionalInTaskGroup()

// MARK: - Results Summary
// V1: CONFIRMED — borrow in sync closure
// V2: CONFIRMED — consume in sync non-escaping FAILS (misleading error)
// V3: CONFIRMED — consume at function scope works
// V4: CONFIRMED — create+consume inside sync closure works
// V5: CONFIRMED — create+consume inside async closure works
// V6: CONFIRMED — create+consume inside withTaskGroup body works
// V7: CONFIRMED — borrow in async closure works
// V8: CONFIRMED — borrow in withTaskGroup body works
// V9: REFUTED  — [consume r] capture list syntax does not exist
//
// The rules:
//
//   Borrow across closure boundary: ALWAYS works (V1, V7, V8)
//   Consume across closure boundary: NEVER works (V2) — any closure
//   Create+consume inside closure: ALWAYS works (V4, V5, V6)
//   Consume at function scope: works (V3)
//   Consuming capture [consume r]: no syntax exists (V9)
//   var Optional.take() in non-@Sendable: works (V11, V12)
//   Mutex in @Sendable closure: fails — ~Copyable + data race (V10)
//
// Two patterns for ~Copyable across closure boundaries:
//
//   | Context              | Pattern                          | Cost         |
//   |----------------------|----------------------------------|--------------|
//   | Non-@Sendable closure | var Optional(value) + take()    | zero (stack) |
//   | @Sendable closure     | Transfer.Cell (Box/class)       | heap + ARC   |
//
// Apple's swift-http-api-proposal uses both:
//   - Optional.take() for scoped closures (non-Sendable)
//   - Mutex(Optional(value)) for shared state (but not in @Sendable closures)
//   - Comments: "Needed since we are lacking call-once closures" (20+ times)
//
// Conclusion: NOT a bug. Language constraint. Closures can be called multiple
//   times, so consuming a captured ~Copyable value is universally rejected.
//   The error message "captured by an escaping closure" is misleading — it
//   triggers for non-escaping closures too (V2).
//
//   The eventual language fix is call-once closures (acknowledged by Apple).
//   Until then:
//   - For non-@Sendable closures: var Optional.take() (zero cost)
//   - For @Sendable closures: Transfer.Cell (one heap allocation)
//   - Design APIs where closures RECEIVE ~Copyable values as `consuming
//     sending` parameters rather than capturing them
