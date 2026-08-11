// MARK: - Stored Property Span Access Without @_rawLayout
// Purpose: Test whether a Span can be created from a regular stored property
//          WITHOUT using @_rawLayout. The key insight: UnsafePointer is Escapable
//          and CAN be returned from withUnsafePointer closures. We then create
//          Span OUTSIDE the closure and use _overrideLifetime to chain lifetime.
//
// Hypothesis: If we can get an UnsafePointer to a stored property (via
//             withUnsafeMutablePointer or withUnsafePointer), extract it from
//             the closure, and create Span outside — no @_rawLayout is needed.
//             This would mean any regular stored property can back a Span.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED (V1, V3, V4) / REFUTED (V2, V5)
//
//   V1: CONFIRMED — withUnsafeMutablePointer(to: &_element) gives in-place pointer
//   V2: REFUTED   — withUnsafePointer(to: _element) selects `borrowing` overload;
//                    does not guarantee address identity for Copyable types (may copy)
//   V3: CONFIRMED — Full generating iterator works with regular stored property
//   V4: CONFIRMED — Optional<Element> stored property also works
//   V5: REFUTED   — Span as closure result fails (~Escapable, as expected)
//   V6: Size: stored property 24/24 vs @_rawLayout 25/32 (stored property wins)
//
//   Critical distinction: withUnsafeMutablePointer(to: &var) → inout, in-place pointer (SAFE)
//                         withUnsafePointer(to: val) → borrowing overload, may copy (DANGLING)
//   Note: for ~Copyable types, borrowing MUST give original address (can't copy).
//   The V2 failure applies specifically to Copyable stored properties.
//   The &inout form MUST provide the actual memory location (inout contract).
//   Combined with @_lifetime(&self) + _overrideLifetime, the pointer is valid
//   for the Span's lifetime because the stored property is at a fixed offset
//   within self, and self cannot move while the Span is alive.
//
// Date: 2026-02-26

// ============================================================================
// MARK: - Variant 1: withUnsafeMutablePointer(to: &_element) — extract pointer
// Hypothesis: Get a mutable pointer to a stored property, return it from the
//             closure (UnsafePointer is Escapable), create Span outside.
// ============================================================================

struct V1_DirectProperty: ~Copyable {
    var _element: Int
    var _hasValue: Bool

    init() {
        _element = 0
        _hasValue = false
    }

    @_lifetime(&self)
    mutating func store(_ value: Int) {
        _element = value
        _hasValue = true
    }

    @_lifetime(&self)
    mutating func span() -> Span<Int> {
        guard _hasValue else {
            // Need a valid pointer for empty span
            let ptr = withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer(p)
            }
            let empty = unsafe Span(_unsafeStart: ptr, count: 0)
            return unsafe _overrideLifetime(empty, mutating: &self)
        }
        let ptr = withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer(p)
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(s, mutating: &self)
    }
}

func testV1() {
    var v = V1_DirectProperty()
    v.store(42)
    let s = v.span()
    assert(!s.isEmpty && s[0] == 42, "V1 FAILED: expected [42]")
    print("V1  (withUnsafeMutablePointer to &_element): CONFIRMED — \(s[0])")
}

// ============================================================================
// MARK: - Variant 2: withUnsafePointer(to: _element) — borrowing
// Hypothesis: Borrowing variant also works for read-only Span creation.
// Result: REFUTED — withUnsafePointer(to: _element) passes _element by VALUE.
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//         The pointer points to a temporary copy on the stack, which is
//         destroyed when withUnsafePointer returns. The pointer is dangling.
//         Only withUnsafeMutablePointer(to: &_element) gives an in-place pointer.
// ============================================================================

// V2 code removed — produces undefined behavior (dangling pointer to temporary).
// withUnsafePointer(to: value) creates a COPY. Only withUnsafeMutablePointer(to: &var)
// gives a pointer to the actual stored property.

func testV2() {
    print("V2  (withUnsafePointer borrowing _element): REFUTED — dangling pointer to copy")
}

// ============================================================================
// MARK: - Variant 3: Full generating iterator with regular stored property
// Hypothesis: A generating iterator can use a regular stored property (no
//             @_rawLayout) as the Span backing storage.
// ============================================================================

struct V3_CounterIterator: ~Copyable {
    var _current: Int
    let _end: Int
    var _element: Int

    init(from: Int, to: Int) {
        _current = from
        _end = to
        _element = 0
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard _current < _end, maximumCount > 0 else {
            let ptr = withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer(p)
            }
            let empty = unsafe Span(_unsafeStart: ptr, count: 0)
            return unsafe _overrideLifetime(empty, mutating: &self)
        }
        _element = _current
        _current += 1
        let ptr = withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer(p)
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(s, mutating: &self)
    }

    @_lifetime(self: immortal)
    mutating func next() -> Int? {
        let span = nextSpan(maximumCount: 1)
        return span.isEmpty ? nil : span[0]
    }
}

func testV3() {
    var iter = V3_CounterIterator(from: 1, to: 6)
    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [1, 2, 3, 4, 5], "V3 FAILED: \(results)")
    print("V3  (Counter iterator, stored property): CONFIRMED — \(results)")
}

// ============================================================================
// MARK: - Variant 4: Optional stored property (compute-on-demand)
// Hypothesis: Optional<Element> stored property also works. The Optional's
//             payload has a stable address while self is alive.
// ============================================================================

struct V4_OptionalProperty: ~Copyable {
    var _element: Int?

    init() { _element = nil }

    @_lifetime(&self)
    mutating func store(_ value: Int) -> Span<Int> {
        _element = value
        // Get pointer to the Optional (not the payload)
        let ptr = withUnsafeMutablePointer(to: &_element) { p in
            // Reinterpret Optional<Int> pointer as Int pointer
            // (Optional's payload is at the start for non-class types)
            unsafe UnsafePointer<Int>(UnsafeRawPointer(p).assumingMemoryBound(to: Int.self))
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(s, mutating: &self)
    }
}

func testV4() {
    var v = V4_OptionalProperty()
    let s = v.store(77)
    assert(s[0] == 77, "V4 FAILED: expected 77")
    print("V4  (Optional stored property):          CONFIRMED — \(s[0])")
}

// ============================================================================
// MARK: - Variant 5: Verify V2 REFUTED claim — Span as closure result
// Hypothesis: REFUTED. withUnsafePointer requires Result: Escapable (implicit).
//             Span is ~Escapable. This should fail to compile.
// ============================================================================

// UNCOMMENT to verify compile error:
// struct V5_DirectSpanReturn {
//     var _element: Int
//
//     @_lifetime(&self)
//     mutating func span() -> Span<Int> {
//         // This should FAIL: Span is ~Escapable, can't be closure Result
//         return withUnsafePointer(to: _element) { p in
//             Span(_unsafeStart: p, count: 1)
//         }
//     }
// }

func testV5() {
    print("V5  (Span as closure result):            REFUTED (compile error, as expected)")
}

// ============================================================================
// MARK: - Variant 6: Size comparison — stored property vs @_rawLayout
// Hypothesis: A stored property has the same size as @_rawLayout.
// ============================================================================

func testV6() {
    let storedSize = MemoryLayout<V3_CounterIterator>.size
    let storedStride = MemoryLayout<V3_CounterIterator>.stride

    print("V6  Size comparison:")
    print("    V3_CounterIterator (stored property): size=\(storedSize), stride=\(storedStride)")
    print("    (Compare with inline-rawlayout-nextspan V1: size=25, stride=32)")
}

// ============================================================================
// MARK: - Run All Tests
// ============================================================================

print("=== Stored Property Span Access Without @_rawLayout ===\n")

testV1()
testV2()
print()
testV3()
print()
testV4()
print()
testV5()
print()
testV6()

print("\n=== Conclusion ===")
print("V1,V3,V4 CONFIRMED: regular stored properties CAN back Span creation.")
print("V2 REFUTED: withUnsafePointer(to: val) copies — ONLY &inout form works.")
print("")
print("Pattern: withUnsafeMutablePointer(to: &_element) → extract pointer →")
print("         Span outside closure → _overrideLifetime(span, mutating: &self)")
print("No @_rawLayout, no Memory.Inline, no new types needed.")
print("Stored property is SMALLER than @_rawLayout (no _initialized Bool).")
