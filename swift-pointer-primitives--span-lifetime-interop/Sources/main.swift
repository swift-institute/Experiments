// ===----------------------------------------------------------------------===//
// EXPERIMENT: span-lifetime-interop
// ===----------------------------------------------------------------------===//
//
// QUESTION: Can we extend Span with custom initializers that delegate to
//           stdlib's init(_unsafeStart:count:)?
//
// HYPOTHESIS: Extension initializers on ~Escapable types require @_lifetime
//             annotations, and delegating to stdlib inits causes lifetime
//             escape errors. The stdlib fixes this with _overrideLifetime,
//             which is internal.
//
// STATUS: [COMPLETED]
// RESULT: HYPOTHESIS REFUTED
//
//         - @_lifetime(immortal) alone does NOT work (errors about escaping)
//         - _overrideLifetime IS available to external packages
//         - The pattern: create span, then assign via _overrideLifetime
//         - This WORKS for both Span and MutableSpan
//
// ===----------------------------------------------------------------------===//

// MARK: - Working Pattern for Span Extensions

print("=== Testing Complete Span Extension Pattern ===")

@safe
struct PointerWrapper<T: ~Copyable>: Copyable, @unchecked Sendable {
    @usableFromInline
    let base: UnsafePointer<T>

    @inlinable
    init(_ pointer: UnsafePointer<T>) {
        unsafe self.base = pointer
    }
}

@safe
struct MutablePointerWrapper<T: ~Copyable>: Copyable, @unchecked Sendable {
    @usableFromInline
    let base: UnsafeMutablePointer<T>

    @inlinable
    init(_ pointer: UnsafeMutablePointer<T>) {
        unsafe self.base = pointer
    }
}

// MARK: - Span Extension (WORKS)

extension Span where Element: ~Copyable {
    /// Working pattern: use _overrideLifetime to establish immortal lifetime
    @_lifetime(immortal)
    init(wrapperStart start: PointerWrapper<Element>, wrapperCount count: Int) {
        let span = unsafe Span(_unsafeStart: start.base, count: count)
        self = unsafe _overrideLifetime(span, borrowing: ())
    }
}

// MARK: - MutableSpan Extension (WORKS)

extension MutableSpan where Element: ~Copyable {
    /// Working pattern for MutableSpan
    @_lifetime(immortal)
    init(mutableWrapperStart start: MutablePointerWrapper<Element>, mutableWrapperCount count: Int) {
        let span = unsafe MutableSpan(_unsafeStart: start.base, count: count)
        self = unsafe _overrideLifetime(span, borrowing: ())
    }
}

// MARK: - Tests

func testSpan() {
    let array = [1, 2, 3, 4, 5]
    unsafe array.withUnsafeBufferPointer { buffer in
        let wrapper = unsafe PointerWrapper(buffer.baseAddress!)
        let span = unsafe Span(wrapperStart: wrapper, wrapperCount: buffer.count)
        print("Span: Created with \(span.count) elements, first = \(span[0])")
    }
}

func testMutableSpan() {
    var array = [10, 20, 30]
    unsafe array.withUnsafeMutableBufferPointer { buffer in
        let wrapper = unsafe MutablePointerWrapper(buffer.baseAddress!)
        var span = unsafe MutableSpan(mutableWrapperStart: wrapper, mutableWrapperCount: buffer.count)
        span[0] = 999
        print("MutableSpan: Modified first element to \(span[0])")
    }
    print("Array after modification: \(array)")
}

testSpan()
testMutableSpan()

print("\n=== ALL TESTS PASSED ===")
print("""

CONCLUSION:
- _overrideLifetime IS available outside stdlib
- Pattern: let span = unsafe Span(...); self = unsafe _overrideLifetime(span, borrowing: ())
- This works for both Span and MutableSpan
- The @_lifetime(immortal) annotation is still required

""")
