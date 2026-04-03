// MARK: - ~Escapable Closure Storage
// Purpose: Determine whether ~Escapable types can store closures, and find
//          the precise boundaries of ~Escapable + closure support.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Results Summary:
//   V1  — CONFIRMED: ~Escapable with @_lifetime(immortal) works (baseline)
//   V2  — CONFIRMED: ~Escapable CAN store @escaping @Sendable closures (immortal lifetime)
//   V3  — CONFIRMED: Scoped consuming resumption pattern works
//   V4  — CONFIRMED: Borrow-lifetime ~Escapable CANNOT be captured in closures
//   V5  — (commented) Borrow-lifetime ~Escapable prevented from escaping via closure
//   V6  — CONFIRMED: Immortal ~Escapable survives across await
//   V7  — CONFIRMED: ~Escapable + Sendable can be passed to Task
//   V8  — (commented) @_lifetime CANNOT depend on Escapable closure params
//   B4a — NOT A BLOCKER: ~Escapable CAN store closures (with immortal lifetime)
//   B4b — CONFIRMED: ~Escapable + Sendable work together (orthogonal)
//
// Date: 2026-02-25
//
// Origin: nonescapable-closure-storage

enum V02_ClosureStorage {

    // ========================================================================
    // MARK: - V1: ~Escapable with @_lifetime(immortal) — works (baseline)
    // Result: CONFIRMED
    // ========================================================================

    struct NEImmortal: ~Escapable {
        let value: Int
        @_lifetime(immortal)
        init(value: Int) { self.value = value }
    }

    // ========================================================================
    // MARK: - V2: ~Escapable storing @escaping closure (with immortal lifetime)
    // Question: Can ~Escapable type store an @escaping closure?
    // Result: CONFIRMED
    // ========================================================================

    struct NEWithClosure: ~Escapable {
        let action: @Sendable () -> Void

        @_lifetime(immortal)
        init(action: @escaping @Sendable () -> Void) {
            self.action = action
        }
    }

    static func testV2() {
        let ne = NEWithClosure(action: { print("V2: stored closure fired") })
        ne.action()
    }

    // ========================================================================
    // MARK: - V3: ~Escapable as Resumption pattern (scoped, consuming)
    // Mirrors Async.Waiter.Resumption: store closure, consume exactly once.
    // Result: CONFIRMED
    // ========================================================================

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

    static func testV3() {
        let r = ScopedResumption { print("V3: resumed") }
        r.execute()
    }

    // ========================================================================
    // MARK: - V4: ~Escapable with borrow lifetime — closure capture
    // Question: Can a lifetime-dependent ~Escapable be captured in a closure?
    // Result: CONFIRMED — compiler prevents capture (lifetime-dependent escapes scope)
    // ========================================================================

    struct NEBorrowed: ~Escapable {
        let ptr: UnsafePointer<Int>

        @_lifetime(borrow ptr)
        init(ptr: UnsafePointer<Int>) {
            self.ptr = ptr
        }
    }

    static func testV4() {
        var x = 42
        withUnsafePointer(to: &x) { ptr in
            let ne = NEBorrowed(ptr: ptr)
            // Cannot capture `ne` in a closure — even non-escaping:
            //   error: lifetime-dependent variable 'ne' escapes its scope
            //   note: this use causes the lifetime-dependent value to escape
            // let fn = { print("V4-capture: \(ne.ptr.pointee)") }
            // fn()
            print("V4: \(unsafe ne.ptr.pointee) (direct access, no closure)")
        }
    }

    // ========================================================================
    // MARK: - V5: ~Escapable value ESCAPING via closure (should it be prevented?)
    // Question: Does the compiler prevent a borrow-lifetime ~Escapable from
    //           escaping beyond its scope via an escaping closure?
    // Result: CONFIRMED — compiler prevents (see commented code)
    // ========================================================================

    // COMPILE ERROR (expected): compiler prevents borrow-lifetime ~Escapable from escaping
    // var escaped: (() -> Void)? = nil
    // static func testV5() {
    //     var x = 42
    //     withUnsafePointer(to: &x) { ptr in
    //         let ne = NEBorrowed(ptr: ptr)
    //         escaped = { print("V5-escape: \(ne.ptr.pointee)") }
    //     }
    //     escaped?()  // use-after-scope if allowed
    // }

    // ========================================================================
    // MARK: - V6: ~Escapable survives across await (immortal)
    // Result: CONFIRMED
    // ========================================================================

    static func testV6() async {
        let ne = NEImmortal(value: 99)
        await Task.yield()
        print("V6-async: \(ne.value)")
    }

    // ========================================================================
    // MARK: - V7: ~Escapable + Sendable passed to Task
    // Result: CONFIRMED
    // ========================================================================

    struct NESendable: ~Escapable, Sendable {
        let value: Int
        @_lifetime(immortal)
        init(value: Int) { self.value = value }
    }

    static func testV7() async {
        let ne = NESendable(value: 77)
        let result = await Task {
            ne.value
        }.value
        print("V7-task: \(result)")
    }

    // ========================================================================
    // MARK: - V8: Key finding — @_lifetime CANNOT depend on Escapable closure
    // This is the precise blocker: you cannot tie a ~Escapable type's lifetime
    // to a closure parameter, because closures are Escapable.
    // Uncomment to see the exact error.
    // Result: CONFIRMED — error: invalid lifetime dependence on Escapable value
    // ========================================================================

    // COMPILE ERROR (expected): invalid lifetime dependence on Escapable value
    // struct NELifetimeClosure: ~Escapable {
    //     let action: @Sendable () -> Void
    //     @_lifetime(copy action)  // error: invalid lifetime dependence on Escapable value
    //     init(action: @escaping @Sendable () -> Void) {
    //         self.action = action
    //     }
    // }

    // ========================================================================
    // MARK: - B4b: ~Escapable + Sendable (orthogonal features)
    // Hypothesis: ~Escapable types CAN conform to Sendable.
    // Result: CONFIRMED — Output: B4b-sendable-nonescapable: 42
    // ========================================================================

    struct SendableNonEscapable: ~Escapable, Sendable {
        let value: Int

        @_lifetime(immortal)
        init(value: Int) {
            self.value = value
        }
    }

    static func testB4b() {
        let sne = SendableNonEscapable(value: 42)
        print("B4b-sendable-nonescapable: \(sne.value)")  // Expected: 42
    }

    // ========================================================================
    // MARK: - Runner
    // ========================================================================

    static func run() {
        print("=== ~Escapable Closure Storage ===")
        print()

        print("--- V1: Baseline (immortal) ---")
        let ne = NEImmortal(value: 42)
        print("V1: \(ne.value)")
        print()

        print("--- V2: Stored closure (immortal) ---")
        testV2()
        print()

        print("--- V3: Scoped consuming resumption ---")
        testV3()
        print()

        print("--- V4: Borrow-lifetime closure capture (prevented) ---")
        testV4()
        print()

        print("--- B4b: ~Escapable + Sendable ---")
        testB4b()
        print()

        print("=== V02 tests complete ===")
    }
}
