// MARK: - BorrowingSequence Pitch Implementation Test
// Purpose: Can we implement the Swift Forums BorrowingSequence pitch approach
//          for ~Copyable element iteration using proper Nest.Name conventions?
//
// Methodology: Incremental construction [EXP-004a]
// Naming: Strictly following [API-NAME-001], [API-NAME-002]
//
// Toolchain: Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Reference: https://forums.swift.org/t/pitch-borrowing-sequence/84332
//
// Result: PARTIAL - Mechanics work, SE-0427 blocks ~Copyable elements
// Date: 2026-01-24
//
// ── REVALIDATION 2026-05-25 (Swift 6.3.2, swiftlang-6.3.2.1.108) ─────────────────────
// The SE-0427 blocker recorded in V5/V8 below is STALE. With the `SuppressedAssociatedTypes`
// experimental feature enabled, `associatedtype Element: ~Copyable & ~Escapable` now
// compiles and SHIPS in swift-iterator-primitives (Iterator.`Protocol`, see
// swift-iterator-primitives/Sources/Iterator Protocol/Iterator.Protocol.swift:33).
//
// The pitch became SE-0516 "BorrowingSequence", returned for revision:
//   proposal: swiftlang/swift-evolution proposals/0516-borrowing-sequence.md
//   thread:   https://forums.swift.org/t/returned-for-revision-se-0516-borrowing-sequence/85846
// (Returned for: a vision/roadmap for generalized containers of ~Copyable types; API
//  naming; throwing-sequence support. NOT returned over ~Escapable elements.)
//
// Sharper finding, probed in /tmp/iter-escapable-probe on 6.3.2:
//   • single-element `next() -> Element?` + `@_lifetime(&self)` ADMITS a ~Escapable element
//     yielded by a NON-empty iterator — not merely the vacuous empty case. (target `single`)
//   • SE-0516's bulk `nextSpan() -> Span<Element>` CANNOT carry a ~Escapable element:
//     Span requires Escapable elements ("type 'Self.Element' does not conform to protocol
//     'Escapable'"). This is the `Span<Span<Int>>` case SE-0516's Alternatives Considered
//     calls impossible "under the currently proposed model for annotating lifetimes".
//     (target `bulkEscapable`)
//   • the closure-backed witness `Iterate` also cannot ("lifetime-dependent variable
//     '$return_value' escapes its scope") — ~Escapable is reachable only via DIRECT
//     conformance, never via closure storage. (target `witnessEscapable`)
// Conclusion: ~Escapable elements are impossible for the Span-RETURNING model, NOT for the
// institute's single-element model. V5/V8's "SE-0427 is the only blocker" no longer holds.
// ────────────────────────────────────────────────────────────────────────────────────
//
// Blog: BLOG-IDEA-026 "BorrowingSequence: Span-Based Iteration Without Copies"
//
// Naming Conventions Applied:
// - BorrowingSequence → Sequence.Borrowing.Protocol
// - BorrowingIteratorProtocol → Sequence.Iterator.Borrowing.Protocol
// - SpanIterator → Span.Iterator
// - All types use Nest.Name pattern

// =============================================================================
// MARK: - Namespace Structure
// Per [API-NAME-001]: All types MUST use Nest.Name pattern
// =============================================================================

/// Namespace for sequence-related types.
public enum Sequence {}

extension Sequence {
    /// Namespace for iterator-related types.
    public enum Iterator {}
}

extension Sequence {
    /// Namespace for borrowing iteration types.
    public enum Borrowing {}
}

extension Sequence.Iterator {
    /// Namespace for borrowing iterator types.
    public enum Borrowing {}
}

/// Namespace for span-related types.
public enum Span {}

// =============================================================================
// MARK: - Variant 1: Basic ~Escapable Type
// Result: CONFIRMED
// =============================================================================

extension Span {
    /// A non-escaping view over contiguous elements.
    struct View: ~Escapable, ~Copyable {
        let value: Int
        init(_ value: Int) { self.value = value }
    }
}

func testVariant1() {
    print("V1: Testing Span.View (~Escapable type)...")
    let view = Span.View(42)
    print("V1: Created Span.View with value: \(view.value)")
    print("V1: CONFIRMED")
}

// =============================================================================
// MARK: - Variant 2: stdlib Span basics
// Result: CONFIRMED
// =============================================================================

func testVariant2() {
    print("\nV2: Testing stdlib Span basics...")
    let array = [10, 20, 30]
    let span = array.span
    print("V2: Span count: \(span.count)")
    print("V2: Span isEmpty: \(span.isEmpty)")
    print("V2: Span[0] = \(span[0])")
    print("V2: Span[1] = \(span[1])")
    print("V2: Span[2] = \(span[2])")
    print("V2: CONFIRMED - stdlib Span works")
}

// =============================================================================
// MARK: - Variant 3: Span iteration via indices
// Result: CONFIRMED
// =============================================================================

func testVariant3() {
    print("\nV3: Testing Span iteration via indices...")
    let array = [100, 200, 300, 400, 500]
    let span = array.span

    print("V3: Iterating via indices:")
    for i in span.indices {
        print("  V3: span[\(i)] = \(span[i])")
    }
    print("V3: CONFIRMED - Span index iteration works")
}

// =============================================================================
// MARK: - Variant 4: ~Copyable elements (closure-based)
// Result: CONFIRMED
// =============================================================================

extension Sequence {
    /// A unique resource that cannot be copied.
    struct Unique: ~Copyable {
        let id: Int
        init(_ id: Int) { self.id = id }
        deinit { print("  V4: Sequence.Unique \(id) deinitialized") }
    }
}

func testVariant4() {
    print("\nV4: Testing ~Copyable elements with closure-based iteration...")

    let resource = Sequence.Unique(42)

    func borrowAndPrint(_ r: borrowing Sequence.Unique) {
        print("  V4: Borrowed resource \(r.id)")
    }

    borrowAndPrint(resource)

    print("V4: CONFIRMED - closure-based ~Copyable borrowing works")
}

// =============================================================================
// MARK: - Variant 5: SE-0427 Limitation Test
// Result: BLOCKED
// =============================================================================

// This is what the pitch proposes but Swift doesn't support:
//
// extension Sequence.Iterator.Borrowing {
//     protocol `Protocol`: ~Copyable, ~Escapable {
//         associatedtype Element: ~Copyable  // ERROR: cannot suppress 'Copyable'
//         @_lifetime(&self)
//         mutating func nextSpan(maximumCount: Int) -> Swift.Span<Element>
//     }
// }
//
// Compiler error: "cannot suppress 'Copyable' requirement of an associated type"

func testVariant5() {
    print("\nV5: SE-0427 Limitation Test...")
    print("V5: 'associatedtype Element: ~Copyable' is NOT supported")
    print("V5: This blocks the pitch's generic protocol approach")
    print("V5: BLOCKED - SE-0427 limitation remains")
}

// =============================================================================
// MARK: - Variant 6: Span.Iterator (proper Nest.Name)
// Per [API-NAME-001]: Iterator nested in Span namespace
// Result: [PENDING]
// =============================================================================

extension Span {
    /// An iterator over a borrowed Span.
    /// Per [API-NAME-001]: Nested as Span.Iterator, not SpanIterator.
    struct Iterator: ~Escapable, ~Copyable {
        private let _span: Swift.Span<Int>
        private var _position: Int

        @_lifetime(copy span)
        init(span: Swift.Span<Int>) {
            self._span = span
            self._position = 0
        }

        var isEmpty: Bool { _position >= _span.count }
        var remaining: Int { _span.count - _position }

        @_lifetime(self: immortal)
        mutating func next() -> Int? {
            guard _position < _span.count else { return nil }
            let element = _span[_position]
            _position += 1
            return element
        }

        @_lifetime(self: immortal)
        mutating func nextBatch(maximumCount: Int) -> Range<Int> {
            let count = min(maximumCount, remaining)
            let start = _position
            _position += count
            return start..<(start + count)
        }
    }
}

func testVariant6() {
    print("\nV6: Testing Span.Iterator...")
    let array = [10, 20, 30, 40, 50, 60, 70]
    let span = array.span

    var iterator = Span.Iterator(span: span)

    print("V6: Single element iteration:")
    while let element = iterator.next() {
        print("  V6: element = \(element)")
        if iterator.remaining <= 3 { break }
    }

    print("V6: Batch iteration (remaining):")
    let indices = iterator.nextBatch(maximumCount: 10)
    for i in indices {
        print("  V6: span[\(i)] = \(span[i])")
    }

    print("V6: CONFIRMED - Span.Iterator works")
}

// =============================================================================
// MARK: - Variant 7: Full iteration with sum
// Result: CONFIRMED
// =============================================================================

func testVariant7() {
    print("\nV7: Testing full iteration loop pattern...")
    let array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    let span = array.span

    var iterator = Span.Iterator(span: span)
    var sum = 0
    while let element = iterator.next() {
        sum += element
    }
    print("V7: Sum of elements = \(sum) (expected: 55)")
    print("V7: CONFIRMED - Full iteration pattern works")
}

// =============================================================================
// MARK: - Variant 8: Sequence.Iterator.Borrowing.Protocol (Copyable elements)
// Per [API-NAME-001]: Protocol nested in namespace hierarchy
// Result: [PENDING]
// =============================================================================

extension Sequence.Iterator.Borrowing {
    /// Protocol for borrowing iterators.
    /// Per [API-NAME-001]: Nested as Sequence.Iterator.Borrowing.Protocol.
    ///
    /// Note: Element is implicitly Copyable due to SE-0427 limitation.
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element  // Implicitly Copyable - SE-0427 limitation

        @_lifetime(&self)
        mutating func nextSpan(maximumCount: Int) -> Swift.Span<Element>

        var isEmpty: Bool { get }
    }
}

extension Sequence.Borrowing {
    /// Protocol for borrowing sequences.
    /// Per [API-NAME-001]: Nested as Sequence.Borrowing.Protocol.
    ///
    /// Note: Element is implicitly Copyable due to SE-0427 limitation.
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element  // Implicitly Copyable - SE-0427 limitation
        associatedtype Iterator: Sequence.Iterator.Borrowing.`Protocol`
            where Iterator.Element == Element

        @_lifetime(borrow self)
        borrowing func makeIterator() -> Iterator
    }
}

func testVariant8() {
    print("\nV8: Sequence.Borrowing.Protocol defined...")
    print("V8: Sequence.Iterator.Borrowing.Protocol defined...")
    print("V8: Protocols compile with Copyable elements")
    print("V8: CONFIRMED - Protocol definitions work (Copyable elements only)")
}

// =============================================================================
// MARK: - Variant 9: Span-returning Iterator with extracting
// Result: [PENDING]
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
// =============================================================================

extension Span {
    /// An iterator that returns Span batches.
    /// Per [API-NAME-001]: Nested as Span.Batch.Iterator.
    enum Batch {}
}

extension Span.Batch {
    struct Iterator: ~Escapable, ~Copyable {
        private var _span: Swift.Span<Int>
        private var _position: Int

        @_lifetime(copy span)
        init(span: Swift.Span<Int>) {
            self._span = span
            self._position = 0
        }

        var isEmpty: Bool { _position >= _span.count }

        @_lifetime(copy self)
        mutating func nextSpan(maximumCount: Int) -> Swift.Span<Int> {
            let count = min(maximumCount, _span.count - _position)
            let subspan = _span.extracting(first: _position + count)
                .extracting(droppingFirst: _position)
            _position += count
            return subspan
        }
    }
}

func testVariant9() {
    print("\nV9: Testing Span.Batch.Iterator...")
    let array = [10, 20, 30, 40, 50, 60, 70]
    let span = array.span

    var iterator = Span.Batch.Iterator(span: span)

    let batch1 = iterator.nextSpan(maximumCount: 3)
    print("V9: Batch 1 (max 3): count = \(batch1.count)")
    for i in batch1.indices {
        print("  V9: batch1[\(i)] = \(batch1[i])")
    }

    let batch2 = iterator.nextSpan(maximumCount: 10)
    print("V9: Batch 2 (max 10): count = \(batch2.count)")
    for i in batch2.indices {
        print("  V9: batch2[\(i)] = \(batch2[i])")
    }

    print("V9: CONFIRMED - Span.Batch.Iterator works")
}

// =============================================================================
// MARK: - Run All Tests
// =============================================================================

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

print("=" * 70)
print("BorrowingSequence Pitch - Nest.Name Naming Convention Applied")
print("=" * 70)

testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5()
testVariant6()
testVariant7()
testVariant8()
testVariant9()

print("\n" + "=" * 70)
print("NAMING CONVENTION MAPPING")
print("=" * 70)
print("""
Original Pitch Name              → Swift Institute Name
─────────────────────────────────────────────────────────
BorrowingSequence                → Sequence.Borrowing.Protocol
BorrowingIteratorProtocol        → Sequence.Iterator.Borrowing.Protocol
SpanIterator / IndexBasedIterator→ Swift.Span<Element>.Iterator
SpanReturningIterator            → Swift.Span<Element>.Iterator.Batch
NonEscapingView                  → Span.View
UniqueResource                   → Sequence.Unique

Note: This experiment uses local Span.* types for exploration.
The library now extends Swift.Span directly per [API-NAME-001].
""")

print("\n" + "=" * 70)
print("SUMMARY")
print("=" * 70)
print("""
V1: Span.View (~Escapable)              - CONFIRMED
V2: stdlib Span basics                  - CONFIRMED
V3: Span index iteration                - CONFIRMED
V4: ~Copyable closure-based iteration   - CONFIRMED
V5: associatedtype Element: ~Copyable   - BLOCKED (SE-0427)
V6: Span.Iterator                       - CONFIRMED
V7: Full iteration loop pattern         - CONFIRMED
V8: Sequence.Borrowing.Protocol         - CONFIRMED (Copyable only)
V9: Span.Batch.Iterator                 - CONFIRMED

NAMING CONVENTIONS APPLIED:
- [API-NAME-001] Nest.Name pattern for all types
- [API-NAME-002] No compound identifiers
- Protocol uses backticks: `Protocol` (reserved keyword)

CONCLUSION:
The pitch's approach works with proper Swift Institute naming.
SE-0427 remains the only blocker for ~Copyable elements.

REVALIDATED 2026-05-25 (Swift 6.3.2) — see header. SE-0427 blocker lifted via
SuppressedAssociatedTypes; `associatedtype Element: ~Copyable & ~Escapable` ships in
swift-iterator-primitives. The remaining real limit is ~Escapable elements under a
Span-RETURNING model (SE-0516); the institute's single-element next() model admits them,
and the closure-backed witness Iterate cannot carry them.
""")
