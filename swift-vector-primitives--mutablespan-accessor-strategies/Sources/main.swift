// MARK: - MutableSpan Accessor Strategy Exhaustive Test
// Purpose: Determine whether ANY accessor pattern enables
//          v.mutableSpan[0] = x on Swift 6.2.3
// Hypothesis: The claim "no accessor pattern works" may be wrong —
//             _modify, get+set, _read+_modify, or methods might enable it
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — three accessor patterns enable v.mutableSpan[0] = x:
//         (1) get + set (no-op), (2) get + _modify, (3) _read + _modify
//         All produce visible writes. _modify-based strategies are preferred.
// Date: 2026-02-06

// ============================================================
// MARK: - Strategy 1: mutating get only (current pattern)
// ============================================================
// Hypothesis: FAILS — "get-only property"
// Result: CONFIRMED FAILS
// Error: "cannot assign through subscript: 'mutableSpan' is a get-only property"

struct S1 {
    var storage = InlineArray<3, Int>(repeating: 0)
    var mutableSpan: MutableSpan<Int> {
        @_lifetime(&self)
        mutating get { storage.mutableSpan }
    }
}

// var v1 = S1()
// v1.mutableSpan[0] = 100  // ❌ error: get-only property

// ============================================================
// MARK: - Strategy 2: mutating get + no-op set
// ============================================================
// Hypothesis: Adding set provides the writeback path compiler needs
// Result: CONFIRMED — compiles AND writes visible
// Output: S2 (get+set): 100

struct S2 {
    var storage = InlineArray<3, Int>(repeating: 0)
    var mutableSpan: MutableSpan<Int> {
        @_lifetime(&self)
        mutating get { storage.mutableSpan }
        @_lifetime(self)
        set { /* no-op — writes go through pointer, no writeback needed */ }
    }
}

func test_s2() {
    var v = S2()
    v.mutableSpan[0] = 100
    v.mutableSpan[1] = 200
    v.mutableSpan[2] = 300
    print("S2 (get+set): \(v.storage[0]), \(v.storage[1]), \(v.storage[2])")
}

// ============================================================
// MARK: - Strategy 3: mutating get + _modify
// ============================================================
// Hypothesis: _modify yields inout MutableSpan — compiler uses it for assignment
// Result: CONFIRMED — compiles AND writes visible
// Output: S3 (get+_modify): 100

struct S3 {
    var storage = InlineArray<3, Int>(repeating: 0)
    var mutableSpan: MutableSpan<Int> {
        @_lifetime(&self)
        mutating get { storage.mutableSpan }
        @_lifetime(&self)
        _modify {
            var span = storage.mutableSpan
            yield &span
        }
    }
}

func test_s3() {
    var v = S3()
    v.mutableSpan[0] = 100
    v.mutableSpan[1] = 200
    v.mutableSpan[2] = 300
    print("S3 (get+_modify): \(v.storage[0]), \(v.storage[1]), \(v.storage[2])")
}

// ============================================================
// MARK: - Strategy 4: _read + _modify (coroutine pair)
// ============================================================
// Hypothesis: Both coroutine accessors — avoids the get-only limitation
// Result: CONFIRMED — compiles AND writes visible
// Output: S4 (_read+_modify): 100

struct S4 {
    var storage = InlineArray<3, Int>(repeating: 0)
    var mutableSpan: MutableSpan<Int> {
        @_lifetime(borrow self)
        _read {
            var copy = storage
            yield copy.mutableSpan
        }
        @_lifetime(&self)
        _modify {
            var span = storage.mutableSpan
            yield &span
        }
    }
}

func test_s4() {
    var v = S4()
    v.mutableSpan[0] = 100
    v.mutableSpan[1] = 200
    v.mutableSpan[2] = 300
    print("S4 (_read+_modify): \(v.storage[0]), \(v.storage[1]), \(v.storage[2])")
}

// ============================================================
// MARK: - Strategy 5: mutating method (not a property)
// ============================================================
// Hypothesis: Method call result supports subscript assignment
// Result: CONFIRMED FAILS
// Error: "cannot assign through subscript: function call returns immutable value"

struct S5 {
    var storage = InlineArray<3, Int>(repeating: 0)
    @_lifetime(&self)
    mutating func getMutableSpan() -> MutableSpan<Int> {
        storage.mutableSpan
    }
}

// var v5 = S5()
// v5.getMutableSpan()[0] = 100  // ❌ error: function call returns immutable value

// ============================================================
// MARK: - Strategy 6: direct subscript (control)
// ============================================================
// Result: CONFIRMED — trivially works

struct S6 {
    var storage = InlineArray<3, Int>(repeating: 0)
    subscript(index: Int) -> Int {
        get { storage[index] }
        set { storage[index] = newValue }
    }
}

func test_s6() {
    var v = S6()
    v[0] = 100
    print("S6 (direct subscript): \(v.storage[0])")
}

// ============================================================
// MARK: - Strategy 7: get + _modify on ~Copyable type with deinit
// ============================================================
// Hypothesis: Same pattern works on always-~Copyable types
// Result: CONFIRMED — compiles AND writes visible
// Output: S7 (~Copyable get+_modify): 100, 200, 300

struct S7: ~Copyable {
    var storage = InlineArray<3, Int>(repeating: 0)
    var mutableSpan: MutableSpan<Int> {
        @_lifetime(&self)
        mutating get { storage.mutableSpan }
        @_lifetime(&self)
        _modify {
            var span = storage.mutableSpan
            yield &span
        }
    }
    deinit {}
}

func test_s7() {
    var v = S7()
    v.mutableSpan[0] = 100
    v.mutableSpan[1] = 200
    v.mutableSpan[2] = 300
    print("S7 (~Copyable get+_modify): \(v.storage[0]), \(v.storage[1]), \(v.storage[2])")
}

// ============================================================
// MARK: - Strategy 8: get + _modify, generic Element: ~Copyable, nested
// ============================================================
// Hypothesis: Full production-like structure with get + _modify works
// Result: CONFIRMED — compiles AND writes visible
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
// Output: S8 (full production-like): 100, 200, 300

struct S8_Outer<Element: ~Copyable, let N: Int>: ~Copyable {}
extension S8_Outer: Copyable where Element: Copyable {}

extension S8_Outer where Element: ~Copyable {
    struct Inner: ~Copyable {
        var storage: InlineArray<N, Element>
        init(repeating value: consuming Element) where Element: Copyable {
            storage = InlineArray<N, Element>(repeating: value)
        }
        deinit {}
    }
}

extension S8_Outer.Inner where Element: ~Copyable {
    var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get { storage.mutableSpan }
        @_lifetime(&self)
        _modify {
            var span = storage.mutableSpan
            yield &span
        }
    }
}

func test_s8() {
    var v = S8_Outer<Int, 3>.Inner(repeating: 0)
    v.mutableSpan[0] = 100
    v.mutableSpan[1] = 200
    v.mutableSpan[2] = 300
    print("S8 (full production-like): \(v.storage[0]), \(v.storage[1]), \(v.storage[2])")
}

// ============================================================
// MARK: - Results Summary
// ============================================================
// S1 (get only):           ❌ FAILS — "get-only property"
// S2 (get + no-op set):    ✅ WORKS — writes visible
// S3 (get + _modify):      ✅ WORKS — writes visible
// S4 (_read + _modify):    ✅ WORKS — writes visible
// S5 (method):             ❌ FAILS — "function call returns immutable value"
// S6 (direct subscript):   ✅ WORKS — trivially correct
// S7 (~Copyable + _modify): ✅ WORKS — writes visible
// S8 (production-like):    ✅ WORKS — writes visible
//
// CONCLUSION: The original claim is REFUTED.
// Adding `_modify` (or even a no-op `set`) to the mutableSpan property
// enables v.mutableSpan[0] = x.
//
// RECOMMENDED STRATEGY: get + _modify (S3/S7/S8)
// - _modify is the semantically correct accessor for yielding mutable access
// - No-op set (S2) works but is a hack — the set body does nothing
// - _read + _modify (S4) requires a _read that constructs a MutableSpan
//   for the read path, which is awkward

test_s2()
test_s3()
test_s4()
test_s6()
test_s7()
test_s8()
