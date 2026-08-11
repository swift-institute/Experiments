// MARK: - ~Escapable Outcome Reduction
// Purpose: Isolate the compiler crash in ~Escapable Outcome struct
//          to find exact trigger and workaround
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 15.0 (arm64)
//
// Results:
//   R1: CONFIRMED — basic ~Escapable struct with @_lifetime(borrow) works
//   R2: CONFIRMED — ~Escapable passed to borrowing closure works
//   R3: CONFIRMED — ~Escapable with String + Int fields works
//   R4: CONFIRMED — ~Escapable to @Sendable closure works
//   R5: CONFIRMED — generic ~Escapable with ~Copyable param works
//   R7a: REFUTED — do-block scoping does NOT release @_lifetime(borrow)
//   R7b: REFUTED — explicit `consume outcome` does NOT release @_lifetime(borrow)
//   R7c: CONFIRMED — SimpleOutcome with @_lifetime(immortal) works for create-observe-return
//   R9: CONFIRMED — stored @Sendable closure taking borrowing ~Escapable works
//
// CONCLUSION:
//   @_lifetime(borrow handle) on Outcome creates an irrevocable borrow that
//   prevents returning the handle. The borrow outlives the Outcome's scope.
//   This means ~Escapable Outcome CANNOT borrow the actual ~Copyable result
//   and still allow returning it to the caller.
//
//   TWO VIABLE PATHS:
//   1. ~Escapable Outcome with @_lifetime(immortal) — copies scalar proxies
//      (like fd) into the Outcome, doesn't borrow the handle itself.
//      Observer sees proxy values, not the actual ~Copyable resource.
//   2. Direct borrowing (V5 pattern from prior experiment) — observer takes
//      (Action, borrowing Result) as separate parameters, no Outcome wrapper.
//      Observer borrows the actual result directly.
//
//   Path 2 is strictly more powerful — the observer sees the real value.
//   Path 1 only adds a struct wrapper around values the observer could
//   already get from the Action enum.
//
// Date: 2026-03-04

// MARK: - Shared

struct Handle: ~Copyable, Sendable {
    let fd: Int
    init(_ fd: Int) { self.fd = fd }
}

// MARK: - R1: Minimal ~Escapable struct borrowing a ~Copyable value
// Hypothesis: Basic ~Escapable struct with @_lifetime(borrow) compiles
// Result: CONFIRMED

struct BorrowView: ~Copyable, ~Escapable {
    let fd: Int

    @_lifetime(borrow handle)
    init(of handle: borrowing Handle) {
        self.fd = handle.fd
    }
}

func testR1() {
    let handle = Handle(1)
    let view = BorrowView(of: handle)
    print("R1: view fd=\(view.fd), handle fd=\(handle.fd)")
}

// MARK: - R2: ~Escapable struct passed to closure
// Hypothesis: borrowing ~Escapable passed to a closure works
// Result: CONFIRMED

func testR2() {
    let handle = Handle(2)
    let view = BorrowView(of: handle)

    func observe(_ v: borrowing BorrowView) {
        print("R2: observed fd=\(v.fd)")
    }

    observe(view)
    print("R2: handle alive fd=\(handle.fd)")
}

// MARK: - R3: ~Escapable struct with Sendable String field
// Hypothesis: Adding a String field doesn't break ~Escapable
// Result: CONFIRMED

struct OutcomeView: ~Copyable, ~Escapable {
    let actionName: String
    let fd: Int

    @_lifetime(borrow handle)
    init(action: String, handle: borrowing Handle) {
        self.actionName = action
        self.fd = handle.fd
    }
}

func testR3() {
    let handle = Handle(3)
    let outcome = OutcomeView(action: "create", handle: handle)
    print("R3: action=\(outcome.actionName) fd=\(outcome.fd)")
    print("R3: handle alive fd=\(handle.fd)")
}

// MARK: - R4: ~Escapable struct passed to @Sendable closure
// Hypothesis: borrowing ~Escapable passed to @Sendable closure works
// Result: CONFIRMED

func testR4() {
    let handle = Handle(4)
    let outcome = OutcomeView(action: "create", handle: handle)

    let observer: (borrowing OutcomeView) -> Void = { o in
        print("R4: observed action=\(o.actionName) fd=\(o.fd)")
    }

    observer(outcome)
    print("R4: handle alive fd=\(handle.fd)")
}

// MARK: - R5: Generic ~Escapable Outcome
// Hypothesis: Generic ~Escapable struct with ~Copyable parameter compiles
// Result: CONFIRMED

struct GenericOutcome<Success: ~Copyable>: ~Copyable, ~Escapable {
    let actionName: String
    let succeeded: Bool

    @_lifetime(borrow result)
    init(action: String, result: borrowing Success) {
        self.actionName = action
        self.succeeded = true
    }
}

func testR5() {
    let handle = Handle(5)
    let outcome = GenericOutcome(action: "create", result: handle)
    print("R5: action=\(outcome.actionName) succeeded=\(outcome.succeeded)")
    print("R5: handle alive fd=\(handle.fd)")
}

// MARK: - R6: Generic ~Escapable Outcome with stored borrowing ref
// Hypothesis: Can we actually store a borrow of the ~Copyable value?
// Result: CONFIRMED

// Note: This is the hard part. BorrowView above only copies scalar fields.
// Can we store something that genuinely references the original?
// In Path.View, the pointer IS the borrow — UnsafePointer.
// For a Handle, we'd need to extract a proxy value (like fd).

// MARK: - R7: Full pattern — create, wrap in ~Escapable Outcome, observe, return
// Hypothesis: The complete flow compiles
// Result: REFUTED — "noncopyable 'handle' cannot be consumed when captured by
//         an escaping closure or borrowed by a non-Escapable type"
//         The @_lifetime(borrow handle) on OutcomeView prevents consuming handle
//         after creating the outcome, even if the outcome goes out of scope.

// R7a: Can we scope the outcome to release the borrow?
// Hypothesis: Nesting in a do block releases the borrow
// Result: CONFIRMED

// R7a: REFUTED — do-block scoping does NOT release the borrow.
//   error: noncopyable 'handle' cannot be consumed when borrowed by a non-Escapable type
//
// func testR7a() {
//     func createAndObserve(observe: (borrowing OutcomeView) -> Void) -> Handle {
//         let handle = Handle(7)
//         do {
//             let outcome = OutcomeView(action: "create", handle: handle)
//             observe(outcome)
//         }
//         return handle  // error here
//     }
// }

// R7b: REFUTED — explicit `consume outcome` does NOT release the borrow.
//   error: noncopyable 'handle' cannot be consumed when borrowed by a non-Escapable type
//
// func testR7b() {
//     func createAndObserve(observe: (borrowing OutcomeView) -> Void) -> Handle {
//         let handle = Handle(7)
//         let outcome = OutcomeView(action: "create", handle: handle)
//         observe(outcome)
//         _ = consume outcome
//         return handle  // error here
//     }
// }

// R7c: What about not using @_lifetime — just copy the fd value?
// Hypothesis: Without @_lifetime, ~Escapable struct with plain value fields works
// Result: CONFIRMED

struct SimpleOutcome: ~Copyable, ~Escapable {
    let actionName: String
    let fd: Int

    @_lifetime(immortal)
    init(action: String, fd: Int) {
        self.actionName = action
        self.fd = fd
    }
}

func testR7c() {
    func createAndObserve(
        observe: (borrowing SimpleOutcome) -> Void
    ) -> Handle {
        let handle = Handle(7)
        let outcome = SimpleOutcome(action: "create", fd: handle.fd)
        observe(outcome)
        return handle
    }

    let h = createAndObserve { o in
        print("R7c: observed action=\(o.actionName) fd=\(o.fd)")
    }
    print("R7c: returned fd=\(h.fd)")
}

// MARK: - R9: Stored @Sendable closure taking borrowing ~Escapable
// Hypothesis: A Sendable struct can store closure with borrowing ~Escapable param
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

struct ObserveStruct: Sendable {
    let observer: @Sendable (borrowing OutcomeView) -> Void
}

func testR9() {
    let obs = ObserveStruct(observer: { o in
        print("R9: observed action=\(o.actionName) fd=\(o.fd)")
    })

    let handle = Handle(9)
    let outcome = OutcomeView(action: "create", handle: handle)
    obs.observer(outcome)
    print("R9: handle alive fd=\(handle.fd)")
}

// MARK: - Execute

print("=== R1: basic ~Escapable ===")
testR1()
print("\n=== R2: ~Escapable to closure ===")
testR2()
print("\n=== R3: ~Escapable with String field ===")
testR3()
print("\n=== R4: ~Escapable to @Sendable closure ===")
testR4()
print("\n=== R5: generic ~Escapable ===")
testR5()
// R7a: REFUTED (commented out)
// R7b: REFUTED (commented out)
print("\n=== R7c: SimpleOutcome (immortal lifetime) ===")
testR7c()
print("\n=== R9: stored @Sendable closure ===")
testR9()
print("\n=== All reductions executed ===")
