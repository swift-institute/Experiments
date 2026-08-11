// MARK: - Lazy Iterator nextSpan Strategies
// Purpose: Validate strategies for lazy iterators to satisfy nextSpan(maximumCount:)
//          as the sole iterator protocol requirement. Tests two approaches:
//          (A) Forward-to-base for element-preserving iterators (zero allocation)
//          (B) Heap buffer for element-transforming iterators (Map, Filter, CompactMap)
//
// Hypothesis: Element-preserving iterators (Drop.First, Prefix.First, Drop.While,
//             Prefix.While) can forward nextSpan to their base iterator with zero
//             buffer cost. Element-transforming iterators need a heap buffer.
//
// Key finding: Creating Span INSIDE a withUnsafePointer closure is impossible
//              (Result: Escapable constraint, Span is ~Escapable). However, the
//              two-step pattern works: extract UnsafePointer (Escapable) from
//              the closure, create Span outside, _overrideLifetime to &self.
//              See stored-property-span-access experiment for this approach.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — Hybrid approach validated
//   V1  Heap buffer (Map pattern, deinit):     CONFIRMED (correct output [1,4,9,16,25])
//   V2  Inline Optional buffer:                 REFUTED (withUnsafePointer requires Result: Escapable)
//   V3  Forward-to-base (Drop.First):           CONFIRMED (correct output [30,40,50])
//   V4  Forward sub-span (Drop.While):          CONFIRMED (correct output [7,8,9,10])
//   V5  Forward prefix sub-span (Prefix.While): CONFIRMED (correct output [2,4,6])
//   V6  Heap buffer (Filter pattern, deinit):   CONFIRMED (correct output [2,4,6,8,10])
//   V7  Forward prefix (Prefix.First):          CONFIRMED (correct output [10,20,30])
// Date: 2026-02-26

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
// MARK: - Base Iterator (contiguous, for composing lazy iterators on top)
// ============================================================================

struct ContiguousBaseIterator: ~Copyable, ~Escapable, UnifiedIteratorProtocol {
    typealias Element = Int

    var base: UnsafePointer<Int>
    var remaining: Int

    @_lifetime(immortal)
    init(base: UnsafePointer<Int>, remaining: Int) {
        self.base = base
        self.remaining = remaining
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        let take = min(maximumCount, remaining)
        guard take > 0 else {
            return Span(_unsafeStart: base, count: 0)
        }
        let span = Span(_unsafeStart: base, count: take)
        base = base + take
        remaining -= take
        return span
    }
}

// ============================================================================
// MARK: - Variant 1: Heap Buffer with deinit (~Copyable ownership)
// Hypothesis: ~Copyable structs support deinit for deterministic cleanup
//             of heap-allocated buffer. This is the pattern for Map, CompactMap,
//             and Filter iterators.
// Pattern: Map iterator that transforms Int -> Int via heap buffer.
// ============================================================================

struct V1_HeapBufferMap: ~Copyable, ~Escapable, UnifiedIteratorProtocol {
    typealias Element = Int

    var _base: ContiguousBaseIterator
    let _transform: (Int) -> Int
    let _mutableBuffer: UnsafeMutablePointer<Int>
    /// Stored property for Span lifetime chaining through self.
    var _bufferPtr: UnsafePointer<Int>
    var _bufferInitialized: Bool

    @_lifetime(copy base)
    init(base: consuming ContiguousBaseIterator, transform: @escaping (Int) -> Int) {
        self._base = base
        self._transform = transform
        let buf = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        self._mutableBuffer = buf
        self._bufferPtr = UnsafePointer(buf)
        self._bufferInitialized = false
    }

    deinit {
        if _bufferInitialized {
            _mutableBuffer.deinitialize(count: 1)
        }
        _mutableBuffer.deallocate()
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard maximumCount > 0 else {
            return Span(_unsafeStart: _bufferPtr, count: 0)
        }
        guard let element = _base.next() else {
            return Span(_unsafeStart: _bufferPtr, count: 0)
        }
        let transformed = _transform(element)
        if _bufferInitialized {
            _mutableBuffer.deinitialize(count: 1)
        }
        _mutableBuffer.initialize(to: transformed)
        _bufferInitialized = true
        return Span(_unsafeStart: _bufferPtr, count: 1)
    }

    /// Performance override: direct element return avoids Span construction.
    @_lifetime(self: immortal)
    mutating func next() -> Int? {
        guard let element = _base.next() else { return nil }
        return _transform(element)
    }
}

func testV1() {
    let array = [1, 2, 3, 4, 5]
    array.withUnsafeBufferPointer { buffer in
        var iter = V1_HeapBufferMap(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            transform: { $0 * $0 }
        )

        // Test via next() override
        var results: [Int] = []
        while let elem = iter.next() {
            results.append(elem)
        }
        assert(results == [1, 4, 9, 16, 25], "V1 next() FAILED: \(results)")
        print("V1a (Heap buffer, next() override): CONFIRMED — \(results)")
    }

    // Test via nextSpan
    array.withUnsafeBufferPointer { buffer in
        var iter = V1_HeapBufferMap(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            transform: { $0 * $0 }
        )

        var results: [Int] = []
        while true {
            let span = iter.nextSpan(maximumCount: 1)
            if span.isEmpty { break }
            results.append(span[0])
        }
        assert(results == [1, 4, 9, 16, 25], "V1 nextSpan FAILED: \(results)")
        print("V1b (Heap buffer, nextSpan path):   CONFIRMED — \(results)")
    }
}

// ============================================================================
// MARK: - Variant 2: Inline Optional Buffer — REFUTED
// Hypothesis: Storing Element? inline and creating Span via withUnsafePointer
//             avoids heap allocation.
// Result: REFUTED — withUnsafePointer(to:_:) requires Result: Escapable.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         Span<Element> is ~Escapable. Cannot return Span from withUnsafePointer.
//         There is no user-accessible API to get a pointer to a stored property
//         and return a ~Escapable value constructed from it.
//
//         Error: "global function 'withUnsafePointer(to:_:)' requires that
//                 'Span<Int>' conform to 'Escapable'"
// ============================================================================

// V2 not tested — compile-time REFUTED.
// The heap buffer approach (V1) is the only viable strategy for
// element-transforming iterators.

func testV2() {
    print("V2 (Inline Optional buffer):        REFUTED — withUnsafePointer requires Result: Escapable")
}

// ============================================================================
// MARK: - Variant 3: Forward-to-Base (Drop.First pattern)
// Hypothesis: Element-preserving iterators can forward nextSpan directly to
//             the base iterator after their state logic. The returned Span
//             borrows from _base (field of self), and @_lifetime(&self)
//             propagates the borrow correctly.
// Pattern: Skip first N elements, then forward all subsequent nextSpan calls.
// ============================================================================

struct V3_DropFirstIterator: ~Copyable, ~Escapable, UnifiedIteratorProtocol {
    typealias Element = Int

    var _base: ContiguousBaseIterator
    var _remaining: Int

    @_lifetime(copy base)
    init(base: consuming ContiguousBaseIterator, remaining: Int) {
        self._base = base
        self._remaining = remaining
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        // Skip phase: consume base spans until count exhausted
        while _remaining > 0 {
            let toSkip = min(maximumCount > 0 ? maximumCount : Int.max, _remaining)
            let span = _base.nextSpan(maximumCount: toSkip)
            if span.isEmpty { return span } // base exhausted
            _remaining -= span.count
        }
        // Forward phase: pass through to base
        return _base.nextSpan(maximumCount: maximumCount)
    }

    /// Performance override.
    @_lifetime(self: immortal)
    mutating func next() -> Int? {
        while _remaining > 0 {
            _remaining -= 1
            guard _base.next() != nil else { return nil }
        }
        return _base.next()
    }
}

func testV3() {
    let array = [10, 20, 30, 40, 50]
    array.withUnsafeBufferPointer { buffer in
        var iter = V3_DropFirstIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            remaining: 2
        )

        // Test via next() override
        var results: [Int] = []
        while let elem = iter.next() {
            results.append(elem)
        }
        assert(results == [30, 40, 50], "V3 next() FAILED: \(results)")
        print("V3a (Drop.First, next() override):  CONFIRMED — \(results)")
    }

    // Test via nextSpan — batch access after skip
    array.withUnsafeBufferPointer { buffer in
        var iter = V3_DropFirstIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            remaining: 2
        )

        var results: [Int] = []
        while true {
            let span = iter.nextSpan(maximumCount: 10)
            if span.isEmpty { break }
            for i in span.indices { results.append(span[i]) }
        }
        assert(results == [30, 40, 50], "V3 nextSpan FAILED: \(results)")
        print("V3b (Drop.First, nextSpan forward):  CONFIRMED — \(results)")
    }
}

// ============================================================================
// MARK: - Variant 4: Forward with Sub-Span (Drop.While pattern)
// Hypothesis: During predicate phase, scan base spans for first non-match,
//             return sub-span via extracting(droppingFirst:). After predicate
//             phase, forward all subsequent calls directly.
// ============================================================================

struct V4_DropWhileIterator: ~Copyable, ~Escapable, UnifiedIteratorProtocol {
    typealias Element = Int

    var _base: ContiguousBaseIterator
    let _predicate: (Int) -> Bool
    var _dropping: Bool

    @_lifetime(copy base)
    init(base: consuming ContiguousBaseIterator,
         predicate: @escaping (Int) -> Bool) {
        self._base = base
        self._predicate = predicate
        self._dropping = true
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        if !_dropping {
            // After predicate phase: forward directly
            return _base.nextSpan(maximumCount: maximumCount)
        }
        // Predicate phase: scan spans for first non-match
        while _dropping {
            let span = _base.nextSpan(maximumCount: maximumCount > 0 ? maximumCount : Int.max)
            if span.isEmpty { return span } // base exhausted during dropping
            // Scan for first element that fails the predicate
            for i in span.indices {
                if !_predicate(span[i]) {
                    _dropping = false
                    // Return sub-span from index i onward
                    return span.extracting(droppingFirst: i)
                }
            }
            // All elements matched — continue dropping
        }
        // Unreachable in practice, but compiler needs a return path
        return _base.nextSpan(maximumCount: 0)
    }

    /// Performance override.
    @_lifetime(self: immortal)
    mutating func next() -> Int? {
        while let element = _base.next() {
            if _dropping && _predicate(element) {
                continue
            }
            _dropping = false
            return element
        }
        return nil
    }
}

func testV4() {
    let array = [2, 4, 6, 7, 8, 9, 10]
    array.withUnsafeBufferPointer { buffer in
        var iter = V4_DropWhileIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            predicate: { $0 % 2 == 0 }  // drop while even
        )

        // Test via next() override
        var results: [Int] = []
        while let elem = iter.next() {
            results.append(elem)
        }
        assert(results == [7, 8, 9, 10], "V4 next() FAILED: \(results)")
        print("V4a (Drop.While, next() override):  CONFIRMED — \(results)")
    }

    // Test via nextSpan — sub-span transition
    array.withUnsafeBufferPointer { buffer in
        var iter = V4_DropWhileIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            predicate: { $0 % 2 == 0 }
        )

        var results: [Int] = []
        while true {
            let span = iter.nextSpan(maximumCount: 100)
            if span.isEmpty { break }
            for i in span.indices { results.append(span[i]) }
        }
        assert(results == [7, 8, 9, 10], "V4 nextSpan FAILED: \(results)")
        print("V4b (Drop.While, nextSpan sub-span): CONFIRMED — \(results)")
    }
}

// ============================================================================
// MARK: - Variant 5: Forward with Prefix (Prefix.While pattern)
// Hypothesis: Forward base spans, scan for predicate failure,
//             return sub-span via extracting(first:), then return empty.
// ============================================================================

struct V5_PrefixWhileIterator: ~Copyable, ~Escapable, UnifiedIteratorProtocol {
    typealias Element = Int

    var _base: ContiguousBaseIterator
    let _predicate: (Int) -> Bool
    var _done: Bool

    @_lifetime(copy base)
    init(base: consuming ContiguousBaseIterator,
         predicate: @escaping (Int) -> Bool) {
        self._base = base
        self._predicate = predicate
        self._done = false
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard !_done else {
            return _base.nextSpan(maximumCount: 0) // empty span
        }
        let span = _base.nextSpan(maximumCount: maximumCount)
        if span.isEmpty {
            _done = true
            return span
        }
        // Scan for first element that fails the predicate
        for i in span.indices {
            if !_predicate(span[i]) {
                _done = true
                // Return sub-span up to (not including) index i
                return span.extracting(first: i)
            }
        }
        // All matched — return full span
        return span
    }

    /// Performance override.
    @_lifetime(self: immortal)
    mutating func next() -> Int? {
        guard !_done else { return nil }
        guard let element = _base.next() else { return nil }
        if _predicate(element) {
            return element
        }
        _done = true
        return nil
    }
}

func testV5() {
    let array = [2, 4, 6, 7, 8, 9, 10]
    array.withUnsafeBufferPointer { buffer in
        var iter = V5_PrefixWhileIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            predicate: { $0 % 2 == 0 }  // take while even
        )

        // Test via next() override
        var results: [Int] = []
        while let elem = iter.next() {
            results.append(elem)
        }
        assert(results == [2, 4, 6], "V5 next() FAILED: \(results)")
        print("V5a (Prefix.While, next() override): CONFIRMED — \(results)")
    }

    // Test via nextSpan — sub-span early termination
    array.withUnsafeBufferPointer { buffer in
        var iter = V5_PrefixWhileIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            predicate: { $0 % 2 == 0 }
        )

        var results: [Int] = []
        while true {
            let span = iter.nextSpan(maximumCount: 100)
            if span.isEmpty { break }
            for i in span.indices { results.append(span[i]) }
        }
        assert(results == [2, 4, 6], "V5 nextSpan FAILED: \(results)")
        print("V5b (Prefix.While, nextSpan sub-span): CONFIRMED — \(results)")
    }
}

// ============================================================================
// MARK: - Variant 6: Filter with Heap Buffer
// Hypothesis: Filter needs heap buffer (inline is REFUTED). For each nextSpan
//             call, scan base for next matching element, store in buffer,
//             return single-element Span.
// ============================================================================

struct V6_FilterIterator: ~Copyable, ~Escapable, UnifiedIteratorProtocol {
    typealias Element = Int

    var _base: ContiguousBaseIterator
    let _predicate: (Int) -> Bool
    let _mutableBuffer: UnsafeMutablePointer<Int>
    /// Stored property for Span lifetime chaining through self.
    var _bufferPtr: UnsafePointer<Int>
    var _bufferInitialized: Bool

    @_lifetime(copy base)
    init(base: consuming ContiguousBaseIterator,
         predicate: @escaping (Int) -> Bool) {
        self._base = base
        self._predicate = predicate
        let buf = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        self._mutableBuffer = buf
        self._bufferPtr = UnsafePointer(buf)
        self._bufferInitialized = false
    }

    deinit {
        if _bufferInitialized {
            _mutableBuffer.deinitialize(count: 1)
        }
        _mutableBuffer.deallocate()
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard maximumCount > 0 else {
            return Span(_unsafeStart: _bufferPtr, count: 0)
        }
        // Scan for next matching element
        while let candidate = _base.next() {
            if _predicate(candidate) {
                if _bufferInitialized {
                    _mutableBuffer.deinitialize(count: 1)
                }
                _mutableBuffer.initialize(to: candidate)
                _bufferInitialized = true
                return Span(_unsafeStart: _bufferPtr, count: 1)
            }
        }
        // Exhausted
        return Span(_unsafeStart: _bufferPtr, count: 0)
    }

    /// Performance override.
    @_lifetime(self: immortal)
    mutating func next() -> Int? {
        while let element = _base.next() {
            if _predicate(element) {
                return element
            }
        }
        return nil
    }
}

func testV6() {
    let array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    array.withUnsafeBufferPointer { buffer in
        var iter = V6_FilterIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            predicate: { $0 % 2 == 0 }  // keep evens
        )

        // Test via next() override
        var results: [Int] = []
        while let elem = iter.next() {
            results.append(elem)
        }
        assert(results == [2, 4, 6, 8, 10], "V6 next() FAILED: \(results)")
        print("V6a (Filter, next() override):      CONFIRMED — \(results)")
    }

    // Test via nextSpan — heap buffer path
    array.withUnsafeBufferPointer { buffer in
        var iter = V6_FilterIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            predicate: { $0 % 2 == 0 }
        )

        var results: [Int] = []
        while true {
            let span = iter.nextSpan(maximumCount: 1)
            if span.isEmpty { break }
            results.append(span[0])
        }
        assert(results == [2, 4, 6, 8, 10], "V6 nextSpan FAILED: \(results)")
        print("V6b (Filter, nextSpan heap buffer):  CONFIRMED — \(results)")
    }
}

// ============================================================================
// MARK: - Variant 7: Prefix.First (forward with count limit)
// Hypothesis: Prefix.First can forward nextSpan with clamped maximumCount.
//             No buffer needed, no predicate scanning.
// ============================================================================

struct V7_PrefixFirstIterator: ~Copyable, ~Escapable, UnifiedIteratorProtocol {
    typealias Element = Int

    var _base: ContiguousBaseIterator
    var _remaining: Int

    @_lifetime(copy base)
    init(base: consuming ContiguousBaseIterator, remaining: Int) {
        self._base = base
        self._remaining = remaining
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard _remaining > 0 else {
            return _base.nextSpan(maximumCount: 0) // empty span
        }
        let clamped = min(maximumCount, _remaining)
        let span = _base.nextSpan(maximumCount: clamped)
        _remaining -= span.count
        return span
    }

    /// Performance override.
    @_lifetime(self: immortal)
    mutating func next() -> Int? {
        guard _remaining > 0 else { return nil }
        _remaining -= 1
        return _base.next()
    }
}

func testV7() {
    let array = [10, 20, 30, 40, 50]
    array.withUnsafeBufferPointer { buffer in
        var iter = V7_PrefixFirstIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            remaining: 3
        )

        // Test via next()
        var results: [Int] = []
        while let elem = iter.next() {
            results.append(elem)
        }
        assert(results == [10, 20, 30], "V7 next() FAILED: \(results)")
        print("V7a (Prefix.First, next() override): CONFIRMED — \(results)")
    }

    // Test via nextSpan — batch access with limit
    array.withUnsafeBufferPointer { buffer in
        var iter = V7_PrefixFirstIterator(
            base: ContiguousBaseIterator(
                base: buffer.baseAddress!,
                remaining: buffer.count
            ),
            remaining: 3
        )

        var results: [Int] = []
        while true {
            let span = iter.nextSpan(maximumCount: 100)
            if span.isEmpty { break }
            for i in span.indices { results.append(span[i]) }
        }
        assert(results == [10, 20, 30], "V7 nextSpan FAILED: \(results)")
        print("V7b (Prefix.First, nextSpan forward): CONFIRMED — \(results)")
    }
}

// ============================================================================
// MARK: - Run All Tests
// ============================================================================

print("=== Lazy Iterator nextSpan Strategy Validation ===\n")

testV1()
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
print()
testV7()

print("\n=== Results Summary ===")
print("V1  Heap buffer (Map, deinit):    (see above)")
print("V2  Inline Optional buffer:       REFUTED (withUnsafePointer requires Result: Escapable)")
print("V3  Forward-to-base (Drop.First): (see above)")
print("V4  Forward sub-span (Drop.While):(see above)")
print("V5  Forward prefix (Prefix.While):(see above)")
print("V6  Heap buffer (Filter, deinit): (see above)")
print("V7  Forward prefix (Prefix.First):(see above)")

print("\n=== Strategy Recommendation ===")
print("Element-preserving (Drop.First, Prefix.First, Drop.While, Prefix.While):")
print("  → Forward nextSpan to base iterator (zero allocation, batch-capable)")
print("Element-transforming (Map, CompactMap, Filter):")
print("  → Heap buffer with deinit (one allocation per iterator lifetime)")
