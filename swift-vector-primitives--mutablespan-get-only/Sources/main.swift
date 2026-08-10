// MARK: - MutableSpan "get-only property" Investigation
// Purpose: Isolate why v.mutableSpan[0] = x fails with
//          "cannot assign through subscript: 'mutableSpan' is a get-only property"
//
// Hypothesis: The `mutating get` accessor returning ~Escapable (MutableSpan)
//             does not support subscript assignment through the property.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — this is a Swift 6.2.3 compiler limitation, not a
//         Vector.Inline issue. Even stdlib Array.mutableSpan[0] = x fails.
//         Workaround: capture mutableSpan in a local var, then subscript-assign.
// Date: 2026-02-06

// MARK: - Variant 1: Direct assignment FAILS (even stdlib Array)
// Hypothesis: a.mutableSpan[0] = x fails for ALL types
// Result: CONFIRMED — error: "cannot assign through subscript: 'mutableSpan' is a get-only property"
//
// func test_direct_fails() {
//     var a = [1, 2, 3]
//     a.mutableSpan[0] = 100  // ❌ get-only property
// }

// MARK: - Variant 2: Local var capture WORKS
// Hypothesis: Binding mutableSpan to a local var allows subscript assignment
// Result: CONFIRMED — compiles and writes are visible through original
// Output: V2: 100

func test_local_var() {
    var a = [1, 2, 3]
    var span = a.mutableSpan
    span[0] = 100
    print("V2: \(a[0])")  // Output: V2: 100
}

// MARK: - Variant 3: Scoped multi-write via do block
// Hypothesis: do { var span = a.mutableSpan; span[i] = x } scopes lifetime correctly
// Result: CONFIRMED — all writes visible after do block exits
// Output: V3: 100, 200, 300

func test_scoped_writes() {
    var a = [1, 2, 3]
    do {
        var span = a.mutableSpan
        span[0] = 100
        span[1] = 200
        span[2] = 300
    }
    print("V3: \(a[0]), \(a[1]), \(a[2])")  // Output: V3: 100, 200, 300
}

// MARK: - Variant 4: User-defined wrapper with Lifetimes
// Hypothesis: Same pattern works through user-defined mutableSpan property
// Result: CONFIRMED

struct Wrapper {
    var storage = InlineArray<3, Int>(repeating: 0)
    var mutableSpan: MutableSpan<Int> {
        @_lifetime(&self)
        mutating get { storage.mutableSpan }
    }
}

func test_wrapper() {
    var w = Wrapper()
    var span = w.mutableSpan
    span[0] = 42
    span[1] = 43
    span[2] = 44
    print("V4: \(w.storage[0]), \(w.storage[1]), \(w.storage[2])")
}

// MARK: - Variant 5: ~Copyable wrapper with deinit
// Hypothesis: Works for always-~Copyable types too
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

struct NCWrapper: ~Copyable {
    var storage = InlineArray<3, Int>(repeating: 0)
    var mutableSpan: MutableSpan<Int> {
        @_lifetime(&self)
        mutating get { storage.mutableSpan }
    }
    deinit {}
}

func test_nc_wrapper() {
    var w = NCWrapper()
    var span = w.mutableSpan
    span[0] = 99
    print("V5: \(w.storage[0])")
}

// MARK: - Results Summary
// V1 (direct assign):    FAILS — compiler limitation on ~Escapable get-only
// V2 (local var):        CONFIRMED — writes visible
// V3 (scoped do block):  CONFIRMED — writes visible
// V4 (user wrapper):     CONFIRMED — delegates correctly
// V5 (~Copyable wrapper): CONFIRMED — same behavior
//
// Root cause: `mutating get` returns a value, not an inout reference.
// Subscript assignment requires read-modify-write on the property, but
// with only a getter (no setter/_modify), the compiler has no writeback path.
// The workaround of binding to a local var works because MutableSpan writes
// through its internal UnsafeMutablePointer — no writeback to the property needed.

test_local_var()
test_scoped_writes()
test_wrapper()
test_nc_wrapper()
print("\nAll confirmed")
