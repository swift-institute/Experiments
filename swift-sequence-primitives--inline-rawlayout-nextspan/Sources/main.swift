// MARK: - Inline @_rawLayout Buffer for Generating Iterator nextSpan
// Purpose: Validate that a minimal @_rawLayout single-element buffer can provide
//          zero-allocation nextSpan for generating iterators (no backing storage).
//          This is the Option E approach from Research/zero-allocation-nextspan.md.
//
// Hypothesis: A @_rawLayout(like: Element) type provides a stable address via
//             withUnsafePointer(to: _storage). Combined with _overrideLifetime and
//             @_lifetime(&self), this allows Span creation with zero heap allocation.
//
// Key difference from V2 (REFUTED inline Optional):
//   V2 failed because it created Span INSIDE withUnsafePointer(to:_:), which
//   requires Result: Escapable. This approach returns the UnsafePointer from the
//   closure (pointers ARE Escapable), then creates the Span OUTSIDE the closure.
//   This matches the pattern used by Storage.Inline in storage-primitives.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — All variants pass
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//   V1  Counter iterator (@_rawLayout):       CONFIRMED (correct output [1,2,3,4,5] and [10,11,12,13])
//   V2  Fibonacci iterator (@_rawLayout):     CONFIRMED (correct output [0,1,1,2,3,5,8,13])
//   V3  Cyclic group iterator (@_rawLayout):  CONFIRMED (correct output [3,2,6,4,5,1])
//   V4  Size comparison:                      CONFIRMED (SingleElementBuffer<Int>: 8 bytes = Int)
//   V5  Iterator struct size:                 V1_CounterIterator: 25 bytes (stride 32)
//   V6  Empty iterator edge case:             CONFIRMED ([] with safe deinit)
// Date: 2026-02-26

// ============================================================================
// MARK: - Minimal @_rawLayout Single-Element Buffer
// ============================================================================

/// Zero-overhead single-element buffer using @_rawLayout.
/// Same size as Element, no bitmap, no tracking overhead.
/// Caller manages initialization state.
///
/// Follows the storage-primitives pattern: inner @_rawLayout struct wraps
/// the raw storage, outer struct provides typed access via withUnsafePointer.
struct SingleElementBuffer<Element: ~Copyable>: ~Copyable {
    @_rawLayout(like: Element)
    @usableFromInline
    struct _Raw: ~Copyable {
        @usableFromInline
        init() {}
    }

    @usableFromInline
    var _storage: _Raw

    @inlinable
    init() {
        _storage = _Raw()
    }

    /// Get a mutable pointer to the raw storage.
    /// The pointer is valid as long as self is alive.
    /// Caller must ensure the storage is initialized before reading through it.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    func pointer() -> UnsafeMutablePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeMutablePointer(
                mutating: UnsafeRawPointer(base)
                    .assumingMemoryBound(to: Element.self)
            )
        }
    }
}

// ============================================================================
// MARK: - Unified Iterator Protocol (minimal reproduction)
// ============================================================================

protocol UnifiedIteratorProtocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Element>
}

extension UnifiedIteratorProtocol where Self: ~Copyable & ~Escapable, Element: Copyable {
    @inlinable
    mutating func next() -> Element? {
        let span = nextSpan(maximumCount: 1)
        return span.isEmpty ? nil : span[0]
    }
}

// ============================================================================
// MARK: - Variant 1: Counter Iterator with @_rawLayout Buffer
// Hypothesis: A generating iterator (no backing storage) can use
//             SingleElementBuffer to satisfy nextSpan with zero heap allocation.
//             The Span borrows from the buffer, which is a field of self,
//             so @_lifetime(&self) propagates correctly via _overrideLifetime.
// ============================================================================

struct V1_CounterIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    var _current: Int
    let _end: Int
    var _buffer: SingleElementBuffer<Int>
    var _initialized: Bool

    init(from: Int, to: Int) {
        self._current = from
        self._end = to
        self._buffer = .init()
        self._initialized = false
    }

    deinit {
        if _initialized {
            unsafe _buffer.pointer().deinitialize(count: 1)
        }
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard _current < _end, maximumCount > 0 else {
            let empty = unsafe Span(
                _unsafeStart: UnsafePointer(_buffer.pointer()),
                count: 0
            )
            return unsafe _overrideLifetime(empty, mutating: &self)
        }
        // Clean up previous value
        if _initialized {
            unsafe _buffer.pointer().deinitialize(count: 1)
        }
        // Compute and store new value
        unsafe _buffer.pointer().initialize(to: _current)
        _initialized = true
        _current += 1
        // Create Span from buffer pointer, chain lifetime to &self
        let span = unsafe Span(
            _unsafeStart: UnsafePointer(_buffer.pointer()),
            count: 1
        )
        return unsafe _overrideLifetime(span, mutating: &self)
    }
}

func testV1() {
    var iter = V1_CounterIterator(from: 1, to: 6)

    // Test via default next() (calls nextSpan(1))
    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [1, 2, 3, 4, 5], "V1 next() FAILED: \(results)")
    print("V1a (Counter, next() via nextSpan):  CONFIRMED — \(results)")
}

func testV1_span() {
    var iter = V1_CounterIterator(from: 10, to: 14)

    // Test via direct nextSpan calls
    var results: [Int] = []
    while true {
        let span = iter.nextSpan(maximumCount: 1)
        if span.isEmpty { break }
        results.append(span[0])
    }
    assert(results == [10, 11, 12, 13], "V1 nextSpan FAILED: \(results)")
    print("V1b (Counter, direct nextSpan):      CONFIRMED — \(results)")
}

// ============================================================================
// MARK: - Variant 2: Fibonacci Generator with @_rawLayout Buffer
// Hypothesis: A more complex generating iterator (stateful computation)
//             also works with SingleElementBuffer.
// ============================================================================

struct V2_FibonacciIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    var _a: Int
    var _b: Int
    var _remaining: Int
    var _buffer: SingleElementBuffer<Int>
    var _initialized: Bool

    init(count: Int) {
        self._a = 0
        self._b = 1
        self._remaining = count
        self._buffer = .init()
        self._initialized = false
    }

    deinit {
        if _initialized {
            unsafe _buffer.pointer().deinitialize(count: 1)
        }
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard _remaining > 0, maximumCount > 0 else {
            let empty = unsafe Span(
                _unsafeStart: UnsafePointer(_buffer.pointer()),
                count: 0
            )
            return unsafe _overrideLifetime(empty, mutating: &self)
        }
        if _initialized {
            unsafe _buffer.pointer().deinitialize(count: 1)
        }
        let value = _a
        unsafe _buffer.pointer().initialize(to: value)
        _initialized = true
        let next = _a + _b
        _a = _b
        _b = next
        _remaining -= 1
        let span = unsafe Span(
            _unsafeStart: UnsafePointer(_buffer.pointer()),
            count: 1
        )
        return unsafe _overrideLifetime(span, mutating: &self)
    }
}

func testV2() {
    var iter = V2_FibonacciIterator(count: 8)

    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [0, 1, 1, 2, 3, 5, 8, 13], "V2 FAILED: \(results)")
    print("V2  (Fibonacci, @_rawLayout buffer): CONFIRMED — \(results)")
}

// ============================================================================
// MARK: - Variant 3: Cyclic Group Iterator (mimics real generating iterator)
// Hypothesis: Validates the pattern for the actual use case — cyclic group
//             iterators that currently only have next().
// ============================================================================

struct V3_CyclicIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    let _modulus: Int
    let _generator: Int
    var _current: Int
    var _done: Bool
    var _buffer: SingleElementBuffer<Int>
    var _initialized: Bool

    init(modulus: Int, generator: Int) {
        self._modulus = modulus
        self._generator = generator
        self._current = generator
        self._done = false
        self._buffer = .init()
        self._initialized = false
    }

    deinit {
        if _initialized {
            unsafe _buffer.pointer().deinitialize(count: 1)
        }
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard !_done, maximumCount > 0 else {
            let empty = unsafe Span(
                _unsafeStart: UnsafePointer(_buffer.pointer()),
                count: 0
            )
            return unsafe _overrideLifetime(empty, mutating: &self)
        }
        if _initialized {
            unsafe _buffer.pointer().deinitialize(count: 1)
        }
        let value = _current
        unsafe _buffer.pointer().initialize(to: value)
        _initialized = true
        _current = (_current * _generator) % _modulus
        if _current == _generator {
            _done = true // completed full cycle
        }
        let span = unsafe Span(
            _unsafeStart: UnsafePointer(_buffer.pointer()),
            count: 1
        )
        return unsafe _overrideLifetime(span, mutating: &self)
    }
}

func testV3() {
    // Z/7* generated by 3: 3, 2, 6, 4, 5, 1 (then cycles back to 3)
    var iter = V3_CyclicIterator(modulus: 7, generator: 3)

    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [3, 2, 6, 4, 5, 1], "V3 FAILED: \(results)")
    print("V3  (Cyclic group, @_rawLayout):     CONFIRMED — \(results)")
}

// ============================================================================
// MARK: - Variant 4: Size Comparison
// Hypothesis: SingleElementBuffer<Int> has zero overhead (same size as Int).
//             Compare to Optional<Int> and UnsafeMutablePointer<Int>.
// ============================================================================

func testV4() {
    let rawLayoutSize = MemoryLayout<SingleElementBuffer<Int>>.size
    let rawLayoutStride = MemoryLayout<SingleElementBuffer<Int>>.stride
    let optionalSize = MemoryLayout<Optional<Int>>.size
    let optionalStride = MemoryLayout<Optional<Int>>.stride
    let pointerSize = unsafe MemoryLayout<UnsafeMutablePointer<Int>>.size

    print("V4  Size comparison:")
    print("    SingleElementBuffer<Int>: size=\(rawLayoutSize), stride=\(rawLayoutStride)")
    print("    Optional<Int>:            size=\(optionalSize), stride=\(optionalStride)")
    print("    UnsafeMutablePointer<Int>: size=\(pointerSize)")

    let intSize = MemoryLayout<Int>.size
    if rawLayoutSize == intSize {
        print("    CONFIRMED — SingleElementBuffer has zero overhead (same as Int: \(intSize) bytes)")
    } else {
        print("    UNEXPECTED — SingleElementBuffer size \(rawLayoutSize) != Int size \(intSize)")
    }
}

// ============================================================================
// MARK: - Variant 5: Iterator Struct Size Comparison
// Hypothesis: V1_CounterIterator (with @_rawLayout buffer) is smaller than
//             a heap-buffer equivalent iterator.
// ============================================================================

func testV5() {
    let inlineIterSize = MemoryLayout<V1_CounterIterator>.size
    let inlineIterStride = MemoryLayout<V1_CounterIterator>.stride

    print("V5  Iterator struct sizes:")
    print("    V1_CounterIterator (inline @_rawLayout): size=\(inlineIterSize), stride=\(inlineIterStride)")
    print("    (Heap buffer equivalent would add 8 bytes for pointer, similar _initialized bool)")
}

// ============================================================================
// MARK: - Variant 6: Empty Iterator Edge Case
// Hypothesis: Empty iteration (from == to) works correctly with @_rawLayout buffer.
//             The buffer is never initialized, deinit is safe.
// ============================================================================

func testV6() {
    var iter = V1_CounterIterator(from: 5, to: 5)

    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results.isEmpty, "V6 FAILED: expected empty, got \(results)")
    print("V6  (Empty iterator, no init/deinit): CONFIRMED — [] (deinit safe)")
}

// ============================================================================
// MARK: - Run All Tests
// ============================================================================

print("=== Inline @_rawLayout Buffer for Generating Iterator nextSpan ===\n")

testV1()
testV1_span()
print()
testV2()
print()
testV3()
print()
testV4()
print()
testV5()
print()
testV6()

print("\n=== Results Summary ===")
print("V1  Counter iterator (@_rawLayout):    (see above)")
print("V2  Fibonacci iterator (@_rawLayout):  (see above)")
print("V3  Cyclic group iterator (@_rawLayout): (see above)")
print("V4  Size comparison:                   (see above)")
print("V5  Iterator struct sizes:             (see above)")
print("V6  Empty iterator edge case:          (see above)")

print("\n=== Conclusion ===")
print("If all variants CONFIRMED: @_rawLayout(like: Element) provides zero-allocation")
print("nextSpan for generating iterators. Recommended as Storage<Element>.Single in")
print("storage-primitives, replacing heap buffers for ~80 generating iterators.")
