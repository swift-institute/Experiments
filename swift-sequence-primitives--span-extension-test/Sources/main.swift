// Status: SUPERSEDED -- Swift.Span nested-type extension pattern absorbed into swift-property-primitives Property.View. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// Test: Can we extend Swift.Span to add nested types?
// This avoids introducing a separate top-level Span namespace.

// =============================================================================
// V1: Extend Swift.Span with nested Iterator
// =============================================================================

extension Swift.Span {
    /// Iterator for single-element access to a Span.
    /// Nested in Swift.Span, not a separate Span namespace.
    @safe
    public struct Iterator: ~Escapable, ~Copyable {
        @usableFromInline
        let _span: Swift.Span<Element>

        @usableFromInline
        var _position: Int

        @inlinable
        @_lifetime(copy span)
        public init(span: Swift.Span<Element>) {
            self._span = span
            self._position = 0
        }

        @inlinable
        public var isEmpty: Bool { _position >= _span.count }

        @inlinable
        @_lifetime(self: immortal)
        public mutating func next() -> Element? {
            guard _position < _span.count else { return nil }
            let element = _span[_position]
            _position += 1
            return element
        }
    }
}

// =============================================================================
// V2: Extend Swift.Span.Iterator with nested Batch
// Per [API-NAME-001]: Batch is a specialization of Iterator, nested within it
// =============================================================================

extension Swift.Span.Iterator {
    /// Batch iterator returning sub-spans.
    /// Per [API-NAME-001]: Nested as Swift.Span.Iterator.Batch, not Batch.Iterator.
    @safe
    public struct Batch: ~Escapable, ~Copyable {
        @usableFromInline
        let _span: Swift.Span<Element>

        @usableFromInline
        var _position: Int

        @inlinable
        @_lifetime(copy span)
        public init(span: Swift.Span<Element>) {
            self._span = span
            self._position = 0
        }

        @inlinable
        public var isEmpty: Bool { _position >= _span.count }

        @inlinable
        @_lifetime(copy self)
        public mutating func nextSpan(maximumCount: Int) -> Swift.Span<Element> {
            let count = min(maximumCount, _span.count - _position)
            guard count > 0 else { return _span.extracting(first: 0) }
            let result = _span
                .extracting(first: _position + count)
                .extracting(droppingFirst: _position)
            _position += count
            return result
        }
    }
}

// =============================================================================
// Test
// =============================================================================

func test() {
    let array = [10, 20, 30, 40, 50]
    let span = array.span

    print("Testing Swift.Span<Int>.Iterator:")
    var iter = Swift.Span<Int>.Iterator(span: span)
    while let element = iter.next() {
        print("  element = \(element)")
    }

    print("\nTesting Swift.Span<Int>.Iterator.Batch:")
    var batchIter = Swift.Span<Int>.Iterator.Batch(span: span)
    while !batchIter.isEmpty {
        let batch = batchIter.nextSpan(maximumCount: 2)
        print("  batch.count = \(batch.count)")
    }

    print("\nNaming comparison:")
    print("  Before: Span.Iterator<Int>")
    print("  After:  Swift.Span<Int>.Iterator")
    print("  Before: Span.Batch.Iterator<Int>")
    print("  After:  Swift.Span<Int>.Iterator.Batch")
    print("")
    print("Key insight: Batch is a specialization of Iterator, so it nests inside Iterator.")
}

test()
