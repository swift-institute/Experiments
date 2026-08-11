// MARK: - Experiment: Range.Lazy with Nested Iterator (Inline)
// Purpose: Test if declaring Iterator inside struct body (not extension) works
// Hypothesis: Nested types in struct body inherit ~Copyable correctly
//
// Toolchain: Swift 6.2-dev
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-01-24
//
// Key Finding: Nested types declared INSIDE struct body (not in extensions)
// properly inherit ~Copyable constraints. This matches Array.Static pattern.

// ============================================================================
// MARK: - Range Namespace
// ============================================================================

public enum Range {}

// ============================================================================
// MARK: - Range.Lazy<Bound: ~Copyable> with INLINE nested Iterator
// ============================================================================

extension Range {
    /// A lazy range that produces `~Copyable` bounds on-demand.
    public struct Lazy<Bound: ~Copyable>: ~Copyable {
        @usableFromInline
        let start: Int

        @usableFromInline
        let end: Int

        @usableFromInline
        let transform: @Sendable (Int) -> Bound

        // MARK: - Nested Iterator (INLINE in struct body)

        /// Iterator for `Range.Lazy`.
        ///
        /// Declared inline (not in extension) so it inherits `Bound: ~Copyable`
        /// from the outer type. This is the same pattern used by `Array.Static`
        /// and `Array.Storage` in swift-array-primitives.
        public struct Iterator: ~Copyable {
            @usableFromInline
            var current: Int

            @usableFromInline
            let end: Int

            @usableFromInline
            let transform: @Sendable (Int) -> Bound

            @inlinable
            init(current: Int, end: Int, transform: @escaping @Sendable (Int) -> Bound) {
                self.current = current
                self.end = end
                self.transform = transform
            }

            @inlinable
            public mutating func next() -> Bound? {
                guard current < end else { return nil }
                defer { current += 1 }
                return transform(current)
            }
        }

        // MARK: - Initializers

        @inlinable
        public init(_ range: Swift.Range<Int>, transform: @escaping @Sendable (Int) -> Bound) {
            self.start = range.lowerBound
            self.end = range.upperBound
            self.transform = transform
        }

        // MARK: - Properties

        @inlinable
        public var count: Int { end - start }

        @inlinable
        public var isEmpty: Bool { start >= end }

        // MARK: - Iteration Methods

        @inlinable
        public consuming func makeIterator() -> Iterator {
            Iterator(current: start, end: end, transform: transform)
        }

        @inlinable
        public consuming func forEach(_ body: (borrowing Bound) -> Void) {
            for i in start..<end {
                let bound = transform(i)
                body(bound)
            }
        }

        @inlinable
        public consuming func drain(_ body: (consuming Bound) -> Void) {
            for i in start..<end {
                body(transform(i))
            }
        }
    }
}

// MARK: - Sendable

extension Range.Lazy: Sendable where Bound: Sendable {}
extension Range.Lazy.Iterator: Sendable where Bound: Sendable {}

// ============================================================================
// MARK: - Index<Tag> Simulation
// ============================================================================

struct Index<Tag: ~Copyable>: ~Copyable {
    let position: Int
    init(position: Int) { self.position = position }
}

extension Index where Tag: ~Copyable {
    struct Count {
        let rawValue: Int
        init(_ rawValue: Int) { self.rawValue = rawValue }

        var asRange: Range.Lazy<Index<Tag>> {
            Range.Lazy(0..<rawValue) { Index(position: $0) }
        }
    }
}

// ============================================================================
// MARK: - Test with ~Copyable Tag
// ============================================================================

struct NonCopyableTag: ~Copyable {}

// ============================================================================
// MARK: - Custom Operator
// ============================================================================

func ..< <Tag: ~Copyable>(lhs: Int, rhs: Index<Tag>.Count) -> Range.Lazy<Index<Tag>> {
    Range.Lazy(lhs..<rhs.rawValue) { Index(position: $0) }
}

// ============================================================================
// MARK: - Test Execution
// ============================================================================

print("=== Testing Range.Lazy with INLINE Nested Iterator ===\n")

// Test 1: Basic Range.Lazy.forEach
print("Test 1: Range.Lazy<Index<NonCopyableTag>>.forEach")
do {
    let range = Range.Lazy(0..<5) { Index<NonCopyableTag>(position: $0) }
    range.forEach { idx in
        print("  Index at position \(idx.position)")
    }
}

// Test 2: makeIterator pattern - THE KEY TEST
print("\nTest 2: Range.Lazy.makeIterator() -> Range.Lazy.Iterator")
do {
    let range = Range.Lazy(0..<3) { Index<NonCopyableTag>(position: $0) }
    var iterator: Range.Lazy<Index<NonCopyableTag>>.Iterator = range.makeIterator()
    while let idx = iterator.next() {
        print("  Index at position \(idx.position)")
    }
}

// Test 3: Index.Count.asRange
print("\nTest 3: Index.Count.asRange")
do {
    let count = Index<NonCopyableTag>.Count(5)
    count.asRange.forEach { idx in
        print("  Index at position \(idx.position)")
    }
}

// Test 4: Custom operator
print("\nTest 4: Custom operator 0..<count")
do {
    let count = Index<NonCopyableTag>.Count(4)
    (0..<count).forEach { idx in
        print("  Index at position \(idx.position)")
    }
}

// Test 5: drain (consuming)
print("\nTest 5: Range.Lazy.drain")
do {
    let range = Range.Lazy(0..<3) { Index<NonCopyableTag>(position: $0) }
    range.drain { idx in
        print("  Consumed index at position \(idx.position)")
    }
}

// Test 6: Explicit type annotation for Iterator
print("\nTest 6: Explicit Iterator type")
do {
    let range = Range.Lazy(0..<2) { Index<NonCopyableTag>(position: $0) }
    var it: Range.Lazy<Index<NonCopyableTag>>.Iterator = range.makeIterator()
    print("  Iterator type: Range.Lazy<Index<NonCopyableTag>>.Iterator")
    while let idx = it.next() {
        print("  Index at position \(idx.position)")
    }
}

print("\n=== Tests Complete ===")

print("""

RESULT: Inline nested Iterator WORKS!

The key insight from Array.swift:
- Nested types declared INSIDE the struct body (not in extensions)
  properly inherit ~Copyable constraints from outer type parameters.

This means:
- Range.Lazy.Iterator can be a proper nested type
- No need for top-level RangeLazyIterator<Bound>
- Follows the same pattern as Array.Static, Array.Storage

API is now clean:
- Range.Lazy<Bound: ~Copyable>
- Range.Lazy<Bound>.Iterator  (nested, not top-level)

""")
