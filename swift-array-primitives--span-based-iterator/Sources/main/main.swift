// ============================================================================
// EXPERIMENT: Span-based ~Escapable Iterator
// ============================================================================
// Hypothesis: A ~Escapable iterator using Span can provide zero-copy iteration
//             with lifetime safety, enabling proper Sequence.Protocol conformance
//             without copying to Swift.Array.
//
// Methodology: [EXP-004a] Incremental Construction
// - V1: Basic ~Escapable struct with Span                    ✅ PASS
// - V2: ~Copyable + IteratorProtocol                         ❌ BLOCKED (IteratorProtocol requires Copyable)
// - V2b: ~Escapable + IteratorProtocol                       ❌ BLOCKED (IteratorProtocol requires Escapable)
// - V3: Pointer-based Escapable iterator                     ✅ PASS
// - V4: Container with makeIterator()                        ✅ PASS
// - V5: ~Copyable container + Swift.Sequence                 ❌ BLOCKED (Sequence requires Copyable)
// - V6: Copyable container + Swift.Sequence                  TESTING
//
// ============================================================================
// CRITICAL FINDINGS:
// ============================================================================
//
// 1. IteratorProtocol requires BOTH Copyable AND Escapable
//    → Cannot use ~Escapable (Span-based) iterators with IteratorProtocol
//    → Cannot use ~Copyable iterators with IteratorProtocol
//
// 2. Swift.Sequence requires Copyable
//    → ~Copyable containers CANNOT conform to Swift.Sequence
//    → No for-in syntax for ~Copyable containers
//
// 3. VIABLE SOLUTION for Copyable containers:
//    → Pointer-based iterator (Copyable, Escapable) with typed Index<Element>
//    → Container conforms to Swift.Sequence
//    → Zero-copy iteration (no Swift.Array allocation)
//    → Typed indices for position tracking
//
// 4. For ~Copyable containers:
//    → Must use custom iteration (forEach with closure)
//    → Cannot use for-in syntax
//    → This is what we already have
//
// Result: CONFIRMED - Pointer-based iterator with typed Index is the solution
// Status: SUPERSEDED 2026-04-30 — Array subscript surface changed; experiment's call shape no longer matches
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// ============================================================================

import Index_Primitives

// MARK: - V6: Copyable Container with Swift.Sequence

/// Pointer-based iterator: Copyable, Escapable, typed Index<Element>.
/// Zero-copy iteration without Swift.Array allocation.
@safe
struct PointerIterator<Element: Copyable>: IteratorProtocol {
    private let base: UnsafePointer<Element>
    private let end: Index<Element>.Count
    private var position: Index<Element>

    @unsafe
    init(base: UnsafePointer<Element>, count: Index<Element>.Count) {
        unsafe self.base = base
        self.end = count
        self.position = .zero
    }

    mutating func next() -> Element? {
        guard position < end else { return nil }
        let result = unsafe base[position.position.rawValue]
        position = (position + 1)!
        return result
    }
}

/// Copyable container that conforms to Swift.Sequence.
/// Uses pointer-based iterator for zero-copy iteration.
@safe
struct CopyableContainer<Element: Copyable>: Sequence {
    private let storage: UnsafeMutablePointer<Element>
    let count: Index<Element>.Count

    init(_ elements: [Element]) throws {
        let c = try Index<Element>.Count(elements.count)
        self.count = c
        unsafe self.storage = UnsafeMutablePointer<Element>.allocate(capacity: elements.count)
        for (i, e) in elements.enumerated() {
            unsafe (storage + i).initialize(to: e)
        }
    }

    // Sequence conformance - zero-copy iteration
    func makeIterator() -> PointerIterator<Element> {
        unsafe PointerIterator(base: UnsafePointer(storage), count: count)
    }
}

// MARK: - V6 Test: for-in syntax with Copyable container

func testV6() {
    do {
        let container = try CopyableContainer([1, 2, 3, 4, 5])

        // Test for-in syntax
        var sum = 0
        for value in container {
            sum += value
        }

        if sum == 15 {
            print("V6 PASS: for-in with pointer-based iterator, sum = \(sum)")
            print("         Zero-copy iteration, typed Index<Element> position")
        } else {
            print("V6 FAIL: Expected sum 15, got \(sum)")
        }
    } catch {
        print("V6 FAIL: \(error)")
    }
}

testV6()

// V7: Custom iterator protocol
testV7()

// ============================================================================
// CONCLUSION
// ============================================================================
//
// For Array Primitives, the implementation should be:
//
// 1. For ~Copyable containers (Array.Bounded, etc.):
//    - Keep existing forEach closure-based iteration
//    - NO Swift.Sequence conformance (not possible)
//    - Uses typed Index<Element> internally
//
// 2. For Copyable elements (Array.Bounded where Element: Copyable):
//    - ADD Swift.Sequence conformance
//    - Use PointerIterator with typed Index<Element>
//    - Zero-copy iteration (no Swift.Array allocation)
//    - Enables for-in syntax
//
// This is BETTER than Swift.Array copying because:
// - No allocation during iteration
// - Typed Index<Element> for position tracking
// - Same memory safety (pointer valid for container lifetime)
// ============================================================================
