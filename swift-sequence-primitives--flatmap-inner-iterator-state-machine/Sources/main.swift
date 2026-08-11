// MARK: - FlatMap Inner Iterator State Machine
// Purpose: Validate strategies for storing an inner iterator in a FlatMap
//          state machine where InnerSequence.Iterator is ~Copyable & ~Escapable.
//
// Context: Sequence.FlatMap needs a state machine: base iterator + optional
//          inner iterator. The inner iterator advances through each inner
//          sequence, transitioning to the next outer element when exhausted.
//
//          Unlike Map/CompactMap (which only store _element: Output?), FlatMap
//          stores _inner: InnerSequence.Iterator? where Iterator may be
//          ~Copyable & ~Escapable (from Sequence.Iterator.Protocol).
//
//          Core issue: `var _inner: InnerSeq.Iterator? = nil` where Iterator
//          is ~Escapable causes "lifetime-dependent variable 'self' escapes
//          its scope" because Optional<~Escapable> is ~Escapable and the nil
//          default has no lifetime source.
//
// Hypotheses:
//   V1: Escapable constraint on Iterator fixes nil init (Iterator state machine)
//   V2: Copyable + Escapable constraint on Iterator + `if var` pattern works
//   V3: No constraint + nil init fails (EXPECTED REFUTED — baseline)
//   V4: Buffer approach (no inner iterator storage) avoids the issue entirely
//   V5: Full production pattern: Escapable + nextSpan + in-place mutation
//   V6: Escapable only (not Copyable) + ~Copyable inner + in-place mutation
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED (V1, V2, V4, V5, V6) / REFUTED (V3)
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//   V1: CONFIRMED — Escapable constraint + in-place mutation works
//   V2: CONFIRMED — Copyable + Escapable + `if var` pattern works
//   V3: REFUTED   — No constraint: 'lifetime-dependent variable self escapes'
//   V4: CONFIRMED — Buffer approach works (no iterator storage needed)
//   V5: CONFIRMED — Full production pattern (nextSpan + Optional inline)
//   V6: CONFIRMED — ~Copyable but Escapable iterators work with V1 pattern
//
//   Key finding: The MINIMUM constraint is `InnerSeq.Iterator: Escapable`.
//   This makes Optional<Iterator> Escapable, allowing `= nil` default.
//   Copyable is NOT required — in-place mutation via `_inner!.next()`
//   avoids the `if var` consume pattern. Adding Copyable enables `if var`
//   but is strictly optional.
//
//   Recommended production pattern: V5 (Escapable + nextSpan + in-place).
//   Broader inner sequence support: V4 (buffer) requires no Iterator constraint
//   but is eager on inner sequences.
//
// Date: 2026-03-10

// ============================================================================
// MARK: - Protocols (minimal reproduction of Sequence.Protocol ecosystem)
// ============================================================================

protocol IterP: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable

    @_lifetime(self: immortal)
    mutating func next() -> Element?
}

protocol SeqP: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: IterP & ~Copyable & ~Escapable where Iterator.Element == Element

    @_lifetime(copy self)
    consuming func makeIterator() -> Iterator
}

// ============================================================================
// MARK: - Concrete Sources
// ============================================================================

/// Simple array-backed sequence (Copyable, Escapable).
struct Source<E: Sendable>: SeqP, Sendable {
    let data: [E]
    init(_ data: [E]) { self.data = data }
    consuming func makeIterator() -> Iter { Iter(data.makeIterator()) }

    struct Iter: IterP, Sendable {
        var inner: Array<E>.Iterator
        init(_ inner: Array<E>.Iterator) { self.inner = inner }
        @_lifetime(self: immortal)
        mutating func next() -> E? { inner.next() }
    }
}

/// ~Copyable iterator source (to test with non-copyable iterators).
struct NCSource<E: Sendable>: SeqP, Sendable {
    let data: [E]
    init(_ data: [E]) { self.data = data }
    consuming func makeIterator() -> NCIter { NCIter(data) }

    struct NCIter: ~Copyable, IterP {
        var _data: [E]
        var _index: Int
        init(_ data: [E]) { self._data = data; self._index = 0 }
        @_lifetime(self: immortal)
        mutating func next() -> E? {
            guard _index < _data.count else { return nil }
            defer { _index += 1 }
            return _data[_index]
        }
    }
}

/// Copyable collect() for testing.
extension SeqP where Self: ~Copyable & ~Escapable, Element: Copyable {
    @_lifetime(copy self)
    consuming func collect() -> [Element] {
        var result: [Element] = []
        var iter = self.makeIterator()
        while let e = iter.next() { result.append(e) }
        return result
    }
}

// ============================================================================
// MARK: - V1: Escapable Constraint Fixes nil Init
// Hypothesis: Adding `InnerSeq.Iterator: Escapable` makes Optional<Iterator>
//             Escapable, so `= nil` default has no lifetime concern.
//             Uses in-place mutation (_inner!.next()) for ~Copyable support.
// ============================================================================

struct V1_FlatMap<
    Base: SeqP & ~Copyable & ~Escapable,
    InnerSeq: SeqP
>: ~Copyable, ~Escapable
where Base.Element: Copyable, InnerSeq.Element: Copyable,
      InnerSeq.Iterator: Escapable {

    let _base: Base
    let _transform: (Base.Element) -> InnerSeq

    @_lifetime(copy base)
    init(base: consuming Base, transform: @escaping (Base.Element) -> InnerSeq) {
        self._base = base
        self._transform = transform
    }
}

extension V1_FlatMap: Copyable where Base: Copyable & ~Escapable {}
extension V1_FlatMap: Escapable where Base: Escapable & ~Copyable {}

extension V1_FlatMap: SeqP where Base: ~Copyable & ~Escapable {
    typealias Element = InnerSeq.Element

    @_lifetime(copy self)
    consuming func makeIterator() -> Iter {
        Iter(base: _base.makeIterator(), transform: _transform)
    }

    struct Iter: ~Copyable, ~Escapable, IterP {
        var _base: Base.Iterator
        let _transform: (Base.Element) -> InnerSeq
        var _inner: InnerSeq.Iterator? = nil

        @_lifetime(copy base)
        init(base: consuming Base.Iterator, transform: @escaping (Base.Element) -> InnerSeq) {
            self._base = base
            self._transform = transform
        }

        @_lifetime(self: immortal)
        mutating func next() -> InnerSeq.Element? {
            while true {
                if _inner != nil {
                    if let element = _inner!.next() {
                        return element
                    }
                    _inner = nil
                }
                guard let baseElement = _base.next() else {
                    return nil
                }
                _inner = _transform(baseElement).makeIterator()
            }
        }
    }
}

func testV1() {
    print("=== V1: Escapable Constraint + In-Place Mutation ===\n")

    let result = V1_FlatMap(base: Source([1, 2, 3]), transform: { n in
        Source(Array(repeating: n, count: n))
    }).collect()
    assert(result == [1, 2, 2, 3, 3, 3], "V1 basic FAILED: \(result)")
    print("V1a [basic]         CONFIRMED — \(result)")

    let empty = V1_FlatMap(base: Source<Int>([]), transform: { n in
        Source([n])
    }).collect()
    assert(empty.isEmpty, "V1 empty FAILED")
    print("V1b [empty outer]   CONFIRMED — isEmpty=\(empty.isEmpty)")

    let result2 = V1_FlatMap(base: Source([1, 2, 3]), transform: { _ in
        Source<Int>([])
    }).collect()
    assert(result2.isEmpty, "V1 empty inner FAILED")
    print("V1c [empty inner]   CONFIRMED — isEmpty=\(result2.isEmpty)")

    let mixed = V1_FlatMap(base: Source([1, 2, 3, 4]), transform: { n in
        n % 2 == 0 ? Source([n, n * 10]) : Source<Int>([])
    }).collect()
    assert(mixed == [2, 20, 4, 40], "V1 mixed FAILED: \(mixed)")
    print("V1d [mixed]         CONFIRMED — \(mixed)")

    let typed = V1_FlatMap(base: Source([1, 2]), transform: { n in
        Source(["\(n)", "\(n * 10)"])
    }).collect()
    assert(typed == ["1", "10", "2", "20"], "V1 type FAILED: \(typed)")
    print("V1e [type change]   CONFIRMED — \(typed)")
}

// ============================================================================
// MARK: - V2: Copyable + Escapable + `if var` Pattern
// Hypothesis: With both Copyable and Escapable on Iterator, the `if var`
//             pattern works (copies instead of consuming).
// ============================================================================

struct V2_FlatMap<
    Base: SeqP & ~Copyable & ~Escapable,
    InnerSeq: SeqP
>: ~Copyable, ~Escapable
where Base.Element: Copyable, InnerSeq.Element: Copyable,
      InnerSeq.Iterator: Copyable & Escapable {

    let _base: Base
    let _transform: (Base.Element) -> InnerSeq

    @_lifetime(copy base)
    init(base: consuming Base, transform: @escaping (Base.Element) -> InnerSeq) {
        self._base = base
        self._transform = transform
    }
}

extension V2_FlatMap: Copyable where Base: Copyable & ~Escapable {}
extension V2_FlatMap: Escapable where Base: Escapable & ~Copyable {}

extension V2_FlatMap: SeqP where Base: ~Copyable & ~Escapable {
    typealias Element = InnerSeq.Element

    @_lifetime(copy self)
    consuming func makeIterator() -> Iter {
        Iter(base: _base.makeIterator(), transform: _transform)
    }

    struct Iter: ~Copyable, ~Escapable, IterP {
        var _base: Base.Iterator
        let _transform: (Base.Element) -> InnerSeq
        var _inner: InnerSeq.Iterator? = nil

        @_lifetime(copy base)
        init(base: consuming Base.Iterator, transform: @escaping (Base.Element) -> InnerSeq) {
            self._base = base
            self._transform = transform
        }

        @_lifetime(self: immortal)
        mutating func next() -> InnerSeq.Element? {
            while true {
                if var inner = _inner {
                    if let element = inner.next() {
                        _inner = inner
                        return element
                    }
                    _inner = nil
                }
                guard let baseElement = _base.next() else {
                    return nil
                }
                _inner = _transform(baseElement).makeIterator()
            }
        }
    }
}

func testV2() {
    print("\n=== V2: Copyable + Escapable + if var ===\n")

    let result = V2_FlatMap(base: Source([1, 2, 3]), transform: { n in
        Source(Array(repeating: n, count: n))
    }).collect()
    assert(result == [1, 2, 2, 3, 3, 3], "V2 FAILED: \(result)")
    print("V2a [basic]         CONFIRMED — \(result)")

    let mixed = V2_FlatMap(base: Source([1, 2, 3, 4]), transform: { n in
        n % 2 == 0 ? Source([n, n * 10]) : Source<Int>([])
    }).collect()
    assert(mixed == [2, 20, 4, 40], "V2 mixed FAILED: \(mixed)")
    print("V2b [mixed]         CONFIRMED — \(mixed)")
}

// ============================================================================
// MARK: - V3: No Constraint + nil Init (Expected REFUTED)
// Hypothesis: Without Escapable, `var _inner: InnerSeq.Iterator? = nil`
//             fails because Optional<~Escapable> is ~Escapable and nil
//             default has no lifetime source.
// ============================================================================

// UNCOMMENT to verify compile error:
// struct V3_Iter<Base: SeqP & ~Copyable & ~Escapable, InnerSeq: SeqP>: ~Copyable, ~Escapable, IterP
// where Base.Element: Copyable, InnerSeq.Element: Copyable {
//     var _base: Base.Iterator
//     let _transform: (Base.Element) -> InnerSeq
//     var _inner: InnerSeq.Iterator? = nil  // ← lifetime error here
//
//     @_lifetime(copy base)
//     init(base: consuming Base.Iterator, transform: @escaping (Base.Element) -> InnerSeq) {
//         self._base = base
//         self._transform = transform
//     }
//
//     @_lifetime(self: immortal)
//     mutating func next() -> InnerSeq.Element? {
//         while true {
//             if _inner != nil {
//                 if let element = _inner!.next() { return element }
//                 _inner = nil
//             }
//             guard let baseElement = _base.next() else { return nil }
//             _inner = _transform(baseElement).makeIterator()
//         }
//     }
// }

func testV3() {
    print("\n=== V3: No Constraint + nil Init (Expected REFUTED) ===\n")
    print("V3  REFUTED — 'lifetime-dependent variable self escapes its scope'")
    print("    var _inner: InnerSeq.Iterator? = nil where Iterator: ~Escapable")
    print("    Optional<~Escapable> is ~Escapable, nil default has no lifetime source")
}

// ============================================================================
// MARK: - V4: Buffer Approach (No Inner Iterator Storage)
// Hypothesis: Eagerly collect inner elements into [Element] buffer.
//             Avoids storing ~Copyable/~Escapable iterator entirely.
//             Trade-off: eager on inner sequence, lazy on outer.
// ============================================================================

struct V4_FlatMap<
    Base: SeqP & ~Copyable & ~Escapable,
    InnerSeq: SeqP
>: ~Copyable, ~Escapable
where Base.Element: Copyable, InnerSeq.Element: Copyable {

    let _base: Base
    let _transform: (Base.Element) -> InnerSeq

    @_lifetime(copy base)
    init(base: consuming Base, transform: @escaping (Base.Element) -> InnerSeq) {
        self._base = base
        self._transform = transform
    }
}

extension V4_FlatMap: Copyable where Base: Copyable & ~Escapable {}
extension V4_FlatMap: Escapable where Base: Escapable & ~Copyable {}

extension V4_FlatMap: SeqP where Base: ~Copyable & ~Escapable {
    typealias Element = InnerSeq.Element

    @_lifetime(copy self)
    consuming func makeIterator() -> Iter {
        Iter(base: _base.makeIterator(), transform: _transform)
    }

    struct Iter: ~Copyable, ~Escapable, IterP {
        var _base: Base.Iterator
        let _transform: (Base.Element) -> InnerSeq
        var _buffer: [InnerSeq.Element] = []
        var _bufferIndex: Int = 0

        @_lifetime(copy base)
        init(base: consuming Base.Iterator, transform: @escaping (Base.Element) -> InnerSeq) {
            self._base = base
            self._transform = transform
        }

        @_lifetime(self: immortal)
        mutating func next() -> InnerSeq.Element? {
            while true {
                if _bufferIndex < _buffer.count {
                    let element = _buffer[_bufferIndex]
                    _bufferIndex += 1
                    return element
                }
                guard let baseElement = _base.next() else {
                    return nil
                }
                _buffer = _transform(baseElement).collect()
                _bufferIndex = 0
            }
        }
    }
}

func testV4() {
    print("\n=== V4: Buffer Approach (Eagerly Collect Inner) ===\n")

    let result = V4_FlatMap(base: Source([1, 2, 3]), transform: { n in
        Source(Array(repeating: n, count: n))
    }).collect()
    assert(result == [1, 2, 2, 3, 3, 3], "V4 FAILED: \(result)")
    print("V4a [Copyable inner]   CONFIRMED — \(result)")

    // Also works with ~Copyable inner iterators (collects eagerly)
    let result2 = V4_FlatMap(base: Source([1, 2, 3]), transform: { n in
        NCSource(Array(repeating: n, count: n))
    }).collect()
    assert(result2 == [1, 2, 2, 3, 3, 3], "V4 NC FAILED: \(result2)")
    print("V4b [~Copyable inner]  CONFIRMED — \(result2)")

    let empty = V4_FlatMap(base: Source<Int>([]), transform: { n in
        Source([n])
    }).collect()
    assert(empty.isEmpty, "V4 empty FAILED")
    print("V4c [empty outer]      CONFIRMED — isEmpty=\(empty.isEmpty)")

    let mixed = V4_FlatMap(base: Source([1, 2, 3, 4]), transform: { n in
        n % 2 == 0 ? NCSource([n, n * 10]) : NCSource<Int>([])
    }).collect()
    assert(mixed == [2, 20, 4, 40], "V4 mixed FAILED: \(mixed)")
    print("V4d [mixed NC]         CONFIRMED — \(mixed)")
}

// ============================================================================
// MARK: - V5: Full Production Pattern (Escapable + nextSpan + Optional Inline)
// Hypothesis: Combining V1's Escapable constraint with the Optional inline
//             nextSpan pattern (from Map/CompactMap). This is the production
//             FlatMap.Iterator shape — verifies nextSpan works with in-place
//             inner iterator mutation.
// ============================================================================

struct V5_FlatMap<
    Base: SeqP & ~Copyable & ~Escapable,
    InnerSeq: SeqP
>: ~Copyable, ~Escapable
where Base.Element: Copyable, InnerSeq.Element: Copyable,
      InnerSeq.Iterator: Escapable {

    let _base: Base
    let _transform: (Base.Element) -> InnerSeq

    @_lifetime(copy base)
    init(base: consuming Base, transform: @escaping (Base.Element) -> InnerSeq) {
        self._base = base
        self._transform = transform
    }
}

extension V5_FlatMap: Copyable where Base: Copyable & ~Escapable {}
extension V5_FlatMap: Escapable where Base: Escapable & ~Copyable {}

extension V5_FlatMap: SeqP where Base: ~Copyable & ~Escapable {
    typealias Element = InnerSeq.Element

    @_lifetime(copy self)
    consuming func makeIterator() -> Iter {
        Iter(base: _base.makeIterator(), transform: _transform)
    }

    struct Iter: ~Copyable, ~Escapable, IterP {
        var _base: Base.Iterator
        let _transform: (Base.Element) -> InnerSeq
        var _inner: InnerSeq.Iterator? = nil
        var _element: InnerSeq.Element? = nil

        @_lifetime(copy base)
        init(base: consuming Base.Iterator, transform: @escaping (Base.Element) -> InnerSeq) {
            self._base = base
            self._transform = transform
        }

        @_lifetime(&self)
        mutating func nextSpan(maximumCount: Int) -> Span<InnerSeq.Element> {
            let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer<InnerSeq.Element>(
                    unsafe UnsafeRawPointer(p).assumingMemoryBound(to: InnerSeq.Element.self)
                )
            }
            guard maximumCount > 0 else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            while true {
                if _inner != nil {
                    if let element = _inner!.next() {
                        _element = element
                        let span = unsafe Span(_unsafeStart: ptr, count: 1)
                        return unsafe _overrideLifetime(span, mutating: &self)
                    }
                    _inner = nil
                }
                guard let baseElement = _base.next() else {
                    let span = unsafe Span(_unsafeStart: ptr, count: 0)
                    return unsafe _overrideLifetime(span, mutating: &self)
                }
                _inner = _transform(baseElement).makeIterator()
            }
        }

        @_lifetime(self: immortal)
        mutating func next() -> InnerSeq.Element? {
            while true {
                if _inner != nil {
                    if let element = _inner!.next() {
                        return element
                    }
                    _inner = nil
                }
                guard let baseElement = _base.next() else {
                    return nil
                }
                _inner = _transform(baseElement).makeIterator()
            }
        }
    }
}

func testV5() {
    print("\n=== V5: Full Production Pattern (Escapable + nextSpan) ===\n")

    // Via next()
    let result = V5_FlatMap(base: Source([1, 2, 3]), transform: { n in
        Source(Array(repeating: n, count: n))
    }).collect()
    assert(result == [1, 2, 2, 3, 3, 3], "V5 next() FAILED: \(result)")
    print("V5a [next()]        CONFIRMED — \(result)")

    // Via nextSpan()
    do {
        let fm = V5_FlatMap(base: Source([1, 2, 3]), transform: { n in
            Source(Array(repeating: n, count: n))
        })
        var iter = fm.makeIterator()
        var results: [Int] = []
        while true {
            let span = iter.nextSpan(maximumCount: 1)
            if span.isEmpty { break }
            results.append(span[0])
        }
        assert(results == [1, 2, 2, 3, 3, 3], "V5 nextSpan FAILED: \(results)")
        print("V5b [nextSpan]      CONFIRMED — \(results)")
    }

    // Edge cases
    let empty = V5_FlatMap(base: Source<Int>([]), transform: { n in
        Source([n])
    }).collect()
    assert(empty.isEmpty, "V5 empty FAILED")
    print("V5c [empty outer]   CONFIRMED — isEmpty=\(empty.isEmpty)")

    let mixed = V5_FlatMap(base: Source([1, 2, 3, 4]), transform: { n in
        n % 2 == 0 ? Source([n, n * 10]) : Source<Int>([])
    }).collect()
    assert(mixed == [2, 20, 4, 40], "V5 mixed FAILED: \(mixed)")
    print("V5d [mixed]         CONFIRMED — \(mixed)")

    let typed = V5_FlatMap(base: Source([1, 2]), transform: { n in
        Source(["\(n)", "\(n * 10)"])
    }).collect()
    assert(typed == ["1", "10", "2", "20"], "V5 type FAILED: \(typed)")
    print("V5e [type change]   CONFIRMED — \(typed)")
}

// ============================================================================
// MARK: - V6: Just Escapable (not Copyable) + In-Place Mutation
// Hypothesis: With only Escapable (not Copyable), we need in-place mutation
//             (_inner!.next()) rather than `if var`. Tests that ~Copyable
//             iterators with Escapable work.
//             Note: NCSource.NCIter is ~Copyable but NOT ~Escapable (it has
//             no suppression for Escapable). So it IS Escapable. This variant
//             tests the in-place mutation pattern with such iterators.
// ============================================================================

func testV6() {
    print("\n=== V6: Escapable (not Copyable) + In-Place Mutation ===\n")

    // NCSource.NCIter is ~Copyable but Escapable (no ~Escapable suppression)
    // V1 requires only Escapable, so NCSource should work with V1
    let result = V1_FlatMap(base: Source([1, 2, 3]), transform: { n in
        NCSource(Array(repeating: n, count: n))
    }).collect()
    assert(result == [1, 2, 2, 3, 3, 3], "V6 NC FAILED: \(result)")
    print("V6a [~Copyable + Escapable inner] CONFIRMED — \(result)")

    let mixed = V1_FlatMap(base: Source([1, 2, 3, 4]), transform: { n in
        n % 2 == 0 ? NCSource([n, n * 10]) : NCSource<Int>([])
    }).collect()
    assert(mixed == [2, 20, 4, 40], "V6 mixed FAILED: \(mixed)")
    print("V6b [mixed NC inner]              CONFIRMED — \(mixed)")
}

// ============================================================================
// MARK: - Run All Tests
// ============================================================================

print("=== FlatMap Inner Iterator State Machine Validation ===\n")

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()

print("\n=== Results Summary ===")
print("V1: CONFIRMED — Escapable constraint + in-place mutation")
print("V2: CONFIRMED — Copyable + Escapable + if var")
print("V3: REFUTED   — No constraint + nil init (lifetime error)")
print("V4: CONFIRMED — Buffer approach (eager inner, no iterator storage)")
print("V5: CONFIRMED — Full production (Escapable + nextSpan + Optional inline)")
print("V6: CONFIRMED — Escapable only + ~Copyable inner (NCSource)")

print("\n=== Recommendation ===")
print("Minimum constraint: InnerSeq.Iterator: Escapable")
print("Pattern: in-place mutation via _inner!.next() (not `if var`)")
print("Production shape: V5 (Escapable + nextSpan + Optional inline)")
