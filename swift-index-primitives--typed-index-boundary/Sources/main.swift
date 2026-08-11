// MARK: - Typed Index Boundary Experiment
// Purpose: Find "best of both worlds" for typed index arithmetic at stdlib boundary
// Hypothesis: We can enable `position + count` syntax without dual tracking or scalar conversions
//
// Toolchain: Swift 6.2
// Platform: macOS 26
//
// Result: CONFIRMED - Store typed Index<T> as primary, derive raw index at subscript boundary
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Evidence: position + count compiles and works; rawIndex getter encapsulates conversion
// Date: 2026-01-29
//
// APPLIED TO:
// - swift-input-primitives/Input.Buffer
// - swift-input-primitives/Input.Slice
// - See: swift-primitives/Research/typed-index-arithmetic-unification.md
// - See: swift-index-primitives/Skills/index/SKILL.md [IDX-006a], [IDX-006b]
//
// KEY INSIGHT:
// - Store `position: Index<Element>` as the primary representation (not Storage.Index)
// - All arithmetic is pure typed: `position = position + count`
// - Derive `rawIndex: Storage.Index` ONLY when subscripting (O(1) for RandomAccessCollection)
// - The Int(bitPattern:) conversion is encapsulated in a single private getter
// - No dual tracking needed - just one source of truth (the typed position)

import Index_Primitives

// Use fully qualified name to avoid conflict with Collection.Index
typealias TypedIndex<T> = Index_Primitives.Index<T>

// MARK: - Problem Statement
//
// Current: Input.Buffer stores `position: Storage.Index` and must convert:
//   position = storage.index(position, offsetBy: Int(bitPattern: count))
//
// Desired: Pure typed arithmetic without scalar conversion:
//   position = position + count
//
// Challenge: Storage.Index is stdlib type (Int, String.Index, etc.), not Index<T>

// MARK: - Variant 1: Cursor Wrapper with Typed Offset
// Hypothesis: Wrap Storage.Index in a type that provides typed arithmetic

struct Cursor<Base: RandomAccessCollection> {
    var base: Base
    var rawIndex: Base.Index

    // Typed offset from start
    var offset: TypedIndex<Base.Element>.Count {
        // This still requires conversion internally...
        try! TypedIndex<Base.Element>.Count(base.distance(from: base.startIndex, to: rawIndex))
    }

    // Advance using typed count - STILL needs conversion internally
    mutating func advance(by count: TypedIndex<Base.Element>.Count) {
        // We can't avoid this conversion because Base.Index is opaque
        rawIndex = base.index(rawIndex, offsetBy: Int(bitPattern: count))
    }
}

// Result V1: The conversion is unavoidable at the stdlib boundary.
// Storage.Index is not part of our type system.

// MARK: - Variant 2: Index<T> as the Primary Representation
// Hypothesis: Track only Index<T>, derive Storage.Index when needed

struct TypedCursor<Base: RandomAccessCollection> {
    var base: Base
    var typedPosition: TypedIndex<Base.Element>  // Primary!

    // Derive Storage.Index on demand
    var rawIndex: Base.Index {
        base.index(base.startIndex, offsetBy: Int(bitPattern: typedPosition))
    }

    // Pure typed arithmetic!
    mutating func advance(by count: TypedIndex<Base.Element>.Count) {
        typedPosition = typedPosition + count  // No scalar conversion here!
    }

    // Subscript needs the raw index
    var current: Base.Element? {
        guard Int(bitPattern: typedPosition) < base.count else { return nil }
        return base[rawIndex]  // Conversion happens here, once
    }
}

// Result V2: Conversion moved to subscript access, not arithmetic.
// But rawIndex is O(n) for non-random-access collections.

// MARK: - Variant 3: RandomAccessCollection Constraint
// Hypothesis: For RandomAccessCollection, rawIndex derivation is O(1)

struct FastTypedCursor<Base: RandomAccessCollection> {
    var base: Base
    var typedPosition: TypedIndex<Base.Element>

    // O(1) for RandomAccessCollection!
    var rawIndex: Base.Index {
        base.index(base.startIndex, offsetBy: Int(bitPattern: typedPosition))
    }

    mutating func advance(by count: TypedIndex<Base.Element>.Count) {
        typedPosition = typedPosition + count  // Pure typed!
    }

    var current: Base.Element? {
        let pos = Int(bitPattern: typedPosition)
        guard pos < base.count else { return nil }
        return base[rawIndex]
    }
}

// Result V3: For RandomAccessCollection, this is O(1) and clean.
// The Int(bitPattern:) is encapsulated in rawIndex getter.

// MARK: - Variant 4: Lazy Raw Index (Cached)
// Hypothesis: Cache rawIndex to avoid recomputation

struct CachedTypedCursor<Base: RandomAccessCollection> {
    var base: Base
    var typedPosition: TypedIndex<Base.Element>
    private var _cachedRawIndex: Base.Index?

    var rawIndex: Base.Index {
        mutating get {
            if let cached = _cachedRawIndex {
                return cached
            }
            let computed = base.index(base.startIndex, offsetBy: Int(bitPattern: typedPosition))
            _cachedRawIndex = computed
            return computed
        }
    }

    mutating func advance(by count: TypedIndex<Base.Element>.Count) {
        typedPosition = typedPosition + count
        // Invalidate cache - will recompute on next access
        _cachedRawIndex = nil
    }

    // Or: update cache incrementally
    mutating func advanceWithCache(by count: TypedIndex<Base.Element>.Count) {
        typedPosition = typedPosition + count
        if let cached = _cachedRawIndex {
            _cachedRawIndex = base.index(cached, offsetBy: Int(bitPattern: count))
        }
    }
}

// Result V4: Cache works but adds complexity. For RandomAccessCollection,
// rawIndex is already O(1) so caching has minimal benefit.

// MARK: - Variant 5: Protocol Extension for Clean Syntax
// Hypothesis: Extend RandomAccessCollection to accept typed counts directly

extension RandomAccessCollection {
    /// Subscript with typed index (derives raw index internally)
    subscript<T>(typed position: TypedIndex<T>) -> Element where T == Element {
        let rawIdx = index(startIndex, offsetBy: Int(bitPattern: position))
        return self[rawIdx]
    }
}

func testTypedSubscript() {
    let array = [10, 20, 30, 40, 50]
    let position: TypedIndex<Int> = try! TypedIndex(2)

    // Clean typed access!
    let value = array[typed: position]
    print("array[typed: \(position)] = \(value)")  // 30
}

// Result V5: This provides clean syntax at the use site.
// The conversion is hidden in the subscript implementation.

// MARK: - Variant 6: The Key Insight
// Hypothesis: The "best of both worlds" is accepting that:
// 1. Typed arithmetic (Index + Count) works in the typed world
// 2. Stdlib boundary REQUIRES conversion (unavoidable)
// 3. The goal is to MINIMIZE and ENCAPSULATE conversions

// The ideal pattern:
// - Store typed position as primary
// - Derive raw index ONLY when subscripting
// - All arithmetic stays typed

struct IdealCursor<Base: RandomAccessCollection> {
    let base: Base
    private(set) var position: TypedIndex<Base.Element>

    init(_ base: Base) {
        self.base = base
        self.position = .zero
    }

    var count: TypedIndex<Base.Element>.Count {
        try! TypedIndex<Base.Element>.Count(base.count)
    }

    var isEmpty: Bool {
        position >= count  // Typed comparison!
    }

    // Pure typed arithmetic - no conversions!
    mutating func advance(by count: TypedIndex<Base.Element>.Count) {
        position = position + count
    }

    // Conversion encapsulated here only
    private var rawIndex: Base.Index {
        base.index(base.startIndex, offsetBy: Int(bitPattern: position))
    }

    var first: Base.Element? {
        guard !isEmpty else { return nil }
        return base[rawIndex]
    }
}

// MARK: - Test Execution

func runTests() {
    print("=== Typed Index Boundary Experiment ===\n")

    // Test V3: FastTypedCursor
    var cursor = FastTypedCursor(
        base: [1, 2, 3, 4, 5],
        typedPosition: .zero
    )
    print("Initial position: \(cursor.typedPosition)")
    print("Current element: \(cursor.current ?? -1)")

    let advanceBy: TypedIndex<Int>.Count = try! TypedIndex<Int>.Count(2)
    cursor.advance(by: advanceBy)
    print("After advance(by: 2): position = \(cursor.typedPosition)")
    print("Current element: \(cursor.current ?? -1)")

    // Test V5: Typed subscript
    print("\n--- Typed Subscript Test ---")
    testTypedSubscript()

    // Test V6: IdealCursor
    print("\n--- IdealCursor Test ---")
    var ideal = IdealCursor([10, 20, 30, 40, 50])
    print("Initial: position = \(ideal.position), first = \(ideal.first ?? -1)")

    let step: TypedIndex<Int>.Count = try! TypedIndex<Int>.Count(3)
    ideal.advance(by: step)
    print("After advance(by: 3): position = \(ideal.position), first = \(ideal.first ?? -1)")

    print("\n=== Summary ===")
    print("Key insight: Store typed Index<T> as primary representation.")
    print("Derive raw Storage.Index ONLY at subscript boundaries.")
    print("All arithmetic stays in typed domain: position + count")
    print("Conversion (Int(bitPattern:)) is encapsulated in rawIndex getter.")
}

runTests()
