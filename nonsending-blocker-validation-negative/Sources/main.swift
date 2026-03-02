// MARK: - Nonsending Blocker Validation — ~Escapable Edge Cases
// Purpose: Find the precise boundary of ~Escapable + closure support.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Date: 2026-02-25

// ============================================================================
// MARK: - V1: ~Escapable with @_lifetime(immortal) — works (baseline)
// Result: CONFIRMED
// ============================================================================

struct NEImmortal: ~Escapable {
    let value: Int
    @_lifetime(immortal)
    init(value: Int) { self.value = value }
}

// ============================================================================
// MARK: - V2: ~Escapable storing @escaping closure (with immortal lifetime)
// Question: Can ~Escapable type store an @escaping closure?
// Result: <PENDING>
// ============================================================================

struct NEWithClosure: ~Escapable {
    let action: @Sendable () -> Void

    @_lifetime(immortal)
    init(action: @escaping @Sendable () -> Void) {
        self.action = action
    }
}

func testV2() {
    let ne = NEWithClosure(action: { print("V2: stored closure fired") })
    ne.action()
}

// ============================================================================
// MARK: - V3: ~Escapable as Resumption pattern (scoped, consuming)
// Mirrors Async.Waiter.Resumption: store closure, consume exactly once.
// Result: <PENDING>
// ============================================================================

struct ScopedResumption: ~Escapable {
    let thunk: @Sendable () -> Void

    @_lifetime(immortal)
    init(_ action: @escaping @Sendable () -> Void) {
        self.thunk = action
    }

    consuming func execute() {
        thunk()
    }
}

func testV3() {
    let r = ScopedResumption { print("V3: resumed") }
    r.execute()
}

// ============================================================================
// MARK: - V4: ~Escapable with borrow lifetime — closure capture
// Question: Can a lifetime-dependent ~Escapable be captured in a closure?
// Result: <PENDING>
// ============================================================================

struct NEBorrowed: ~Escapable {
    let ptr: UnsafePointer<Int>

    @_lifetime(borrow ptr)
    init(ptr: UnsafePointer<Int>) {
        self.ptr = ptr
    }
}

func testV4() {
    var x = 42
    withUnsafePointer(to: &x) { ptr in
        let ne = NEBorrowed(ptr: ptr)
        // Cannot capture `ne` in a closure — even non-escaping:
        //   error: lifetime-dependent variable 'ne' escapes its scope
        //   note: this use causes the lifetime-dependent value to escape
        // let fn = { print("V4-capture: \(ne.ptr.pointee)") }
        // fn()
        print("V4: \(ne.ptr.pointee) (direct access, no closure)")
    }
}

// ============================================================================
// MARK: - V5: ~Escapable value ESCAPING via closure (should it be prevented?)
// Question: Does the compiler prevent a borrow-lifetime ~Escapable from
//           escaping beyond its scope via an escaping closure?
// Result: <PENDING>
// ============================================================================

// Uncomment to test — expected: compiler error preventing escape
// var escaped: (() -> Void)? = nil
// func testV5() {
//     var x = 42
//     withUnsafePointer(to: &x) { ptr in
//         let ne = NEBorrowed(ptr: ptr)
//         escaped = { print("V5-escape: \(ne.ptr.pointee)") }
//     }
//     escaped?()  // use-after-scope if allowed
// }

// ============================================================================
// MARK: - V6: ~Escapable survives across await (immortal)
// Result: <PENDING>
// ============================================================================

func testV6() async {
    let ne = NEImmortal(value: 99)
    await Task.yield()
    print("V6-async: \(ne.value)")
}

// ============================================================================
// MARK: - V7: ~Escapable + Sendable passed to Task
// Result: <PENDING>
// ============================================================================

struct NESendable: ~Escapable, Sendable {
    let value: Int
    @_lifetime(immortal)
    init(value: Int) { self.value = value }
}

func testV7() async {
    let ne = NESendable(value: 77)
    let result = await Task {
        ne.value
    }.value
    print("V7-task: \(result)")
}

// ============================================================================
// MARK: - V8: Key finding — @_lifetime CANNOT depend on Escapable closure
// This is the precise blocker: you cannot tie a ~Escapable type's lifetime
// to a closure parameter, because closures are Escapable.
// Uncomment to see the exact error.
// Result: <PENDING>
// ============================================================================

// struct NELifetimeClosure: ~Escapable {
//     let action: @Sendable () -> Void
//     @_lifetime(copy action)  // error: invalid lifetime dependence on Escapable value
//     init(action: @escaping @Sendable () -> Void) {
//         self.action = action
//     }
// }

// ============================================================================
// MARK: - Runner
// ============================================================================

print("=== ~Escapable Edge Cases ===")
print()
testV2()
testV3()
testV4()
await testV6()
await testV7()
print()
print("=== All edge case tests complete ===")
