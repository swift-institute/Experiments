// nonescapable-gap-revalidation-624
//
// Re-testing Gap A and Gap B on Swift 6.2.4.
// These gaps were tested on Swift 6.2.3 (Feb 25, 2026) and FAILED.
// Purpose: determine if 6.2.4 has fixed them.
// Result: BUG REPRODUCED — Gap A (@_lifetime on Escapable closure) and Gap B (~Escapable in non-escaping closure) still blocked in 6.2.4; @_lifetime(immortal) workaround confirmed

// MARK: - GAP A: @_lifetime depends on Escapable closure parameter
// STILL BLOCKED on 6.2.4
// Error (line 12, col 21): "invalid lifetime dependence on an Escapable value with consuming ownership"
//
// struct NELifetimeClosure: ~Escapable {
//     let action: @Sendable () -> Void
//     @_lifetime(copy action)
//     init(action: @escaping @Sendable () -> Void) {
//         self.action = action
//     }
// }

// MARK: - GAP A variant: async closure
// STILL BLOCKED on 6.2.4
// Error (line 22, col 21): "invalid lifetime dependence on an Escapable value with consuming ownership"
//
// struct NEAsyncClosure: ~Escapable {
//     let action: @Sendable () async -> Int?
//     @_lifetime(copy action)
//     init(action: @escaping @Sendable () async -> Int?) {
//         self.action = action
//     }
// }

// MARK: - GAP B: Borrow-lifetime ~Escapable captured in non-escaping closure
// STILL BLOCKED on 6.2.4
// Error (line 44, col 13): "lifetime-dependent variable 'ne' escapes its scope"
// Note: "it depends on the lifetime of argument 'ptr'"
// Note: "this use causes the lifetime-dependent value to escape"
//
// func testGapB() {
//     var x = 42
//     unsafe withUnsafePointer(to: &x) { ptr in
//         let ne = unsafe NEBorrowed(ptr: ptr)
//         let fn = { unsafe print(ne.ptr.pointee) }
//         fn()
//     }
// }

@unsafe
struct NEBorrowed: ~Escapable {
    let ptr: UnsafePointer<Int>
    @_lifetime(borrow ptr)
    init(ptr: UnsafePointer<Int>) { unsafe self.ptr = ptr }
}

// MARK: - GAP B+: withLock-style pattern

func testGapBLock() {
    var x = 42
    unsafe withUnsafePointer(to: &x) { ptr in
        let ne = unsafe NEBorrowed(ptr: ptr)
        let result = { () -> Int in unsafe ne.ptr.pointee }()
        print(result)
    }
}

// MARK: - GAP B++: Immortal ~Escapable in closure (control case — known PASS)

struct NEImmortal: ~Escapable {
    let value: Int
    @_lifetime(immortal)
    init(_ value: Int) { self.value = value }
}

func testGapBImmortal() {
    let ne = NEImmortal(42)
    let fn = { print(ne.value) }
    fn()
}

// MARK: - NEW: @_lifetime(immortal) as workaround for Gap A

struct NEImmortalClosure: ~Escapable {
    let action: @Sendable () -> Void
    @_lifetime(immortal)
    init(action: @escaping @Sendable () -> Void) {
        self.action = action
    }
    consuming func execute() { action() }
}

// MARK: - Run all tests

print("=== nonescapable-gap-revalidation-624 ===")
print()

// GAP A: COMMENTED OUT — STILL BLOCKED
// GAP A (async): COMMENTED OUT — STILL BLOCKED
// GAP B: COMMENTED OUT — STILL BLOCKED

print("GAP B+: withLock-style pattern")
testGapBLock()

print("GAP B++: Immortal control case")
testGapBImmortal()

print("@_lifetime(immortal) workaround for Gap A")
let workaround = NEImmortalClosure(action: { print("  immortal workaround fired") })
workaround.execute()

print()
print("=== All tests passed ===")
