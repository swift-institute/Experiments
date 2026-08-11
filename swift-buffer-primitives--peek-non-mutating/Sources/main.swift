// MARK: - Peek Non-Mutating Experiment
// Purpose: Find a non-mutating peek accessor pattern for ~Copyable containers
//          that provides buffer.peek.front syntax with `let` bindings
// Hypothesis: A Copyable struct with eagerly-copied Element values can provide
//             .peek.front / .peek.back without requiring mutating _read
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-02-13-a
// Platform: macOS 15.0 (arm64)
//
// Result: CONFIRMED — V1 (eager struct) works with let on ~Copyable base
// Date: 2026-02-18
//
// Output:
//   inline.peek1.front = 10     (let binding, ~Copyable base)
//   inline.peek1.back  = 30
//   heap.peek1.front   = 10     (let binding, Copyable base)
//   heap.peek1.back    = 30
//   PASS: let binding works with ~Copyable base

// ============================================================================
// MARK: - Shared Infrastructure
// ============================================================================

/// Minimal ~Copyable container simulating Buffer.Ring.Inline / Buffer.Linear.Inline
struct InlineContainer<Element: Copyable & Sendable, let capacity: Int>: ~Copyable {
    var elements: InlineArray<capacity, Element>
    var count: Int

    init(first: Element, second: Element, third: Element) where Element: ExpressibleByIntegerLiteral {
        var arr = InlineArray<capacity, Element>(repeating: 0)
        arr[0] = first
        arr[1] = second
        arr[2] = third
        self.elements = arr
        self.count = 3
    }
}

/// Minimal Copyable container simulating Buffer.Ring (heap-backed, class reference)
final class HeapStorage<Element: Copyable & Sendable>: @unchecked Sendable {
    var elements: [Element]
    init(_ elements: [Element]) { self.elements = elements }
}

struct HeapContainer<Element: Copyable & Sendable> {
    var storage: HeapStorage<Element>
    var count: Int

    init(_ elements: [Element]) {
        self.storage = HeapStorage(elements)
        self.count = elements.count
    }
}

// ============================================================================
// MARK: - Variant 1: Eager Copyable Struct (computed property, no coroutine)
// ============================================================================
// Hypothesis: Non-mutating computed property returning Copyable struct works
//             with `let` binding on ~Copyable base
// Result: CONFIRMED — works with let on both ~Copyable and Copyable bases

struct PeekView1<Element: Copyable & Sendable>: Sendable {
    let front: Element
    let back: Element
}

extension InlineContainer {
    var peek1: PeekView1<Element> {
        PeekView1(front: elements[0], back: elements[count - 1])
    }
}

extension HeapContainer {
    var peek1: PeekView1<Element> {
        PeekView1(front: storage.elements[0], back: storage.elements[count - 1])
    }
}

// ============================================================================
// MARK: - Variant 2: Eager Copyable Struct via _read coroutine
// ============================================================================
// Hypothesis: Non-mutating _read (without `mutating` keyword) can yield
//             a Copyable struct — still works with `let`
// Result: CONFIRMED — works identically to V1

extension InlineContainer {
    var peek2: PeekView1<Element> {
        _read {
            yield PeekView1(front: elements[0], back: elements[count - 1])
        }
    }
}

extension HeapContainer {
    var peek2: PeekView1<Element> {
        _read {
            yield PeekView1(front: storage.elements[0], back: storage.elements[count - 1])
        }
    }
}

// ============================================================================
// MARK: - Variant 3: Named Tuple
// ============================================================================
// Hypothesis: Named tuple (front:, back:) provides dot-access syntax
//             without a separate struct type
// Result: CONFIRMED — works with let on ~Copyable base

extension InlineContainer {
    var peek3: (front: Element, back: Element) {
        (front: elements[0], back: elements[count - 1])
    }
}

// ============================================================================
// MARK: - Variant 4: Lazy via class reference (heap-backed only)
// ============================================================================
// Hypothesis: For heap-backed types, hold the class reference and compute
//             lazily — only reads what you access
// Result: CONFIRMED — works with let (heap-backed only)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

struct LazyHeapPeekView<Element: Copyable & Sendable> {
    let storage: HeapStorage<Element>
    let count: Int

    var front: Element { storage.elements[0] }
    var back: Element { storage.elements[count - 1] }
}

extension HeapContainer {
    var peek4: LazyHeapPeekView<Element> {
        LazyHeapPeekView(storage: storage, count: count)
    }
}

// ============================================================================
// MARK: - Variant 5/6: Pointer-based approaches (documented, not tested)
// ============================================================================
// V5a: mutating _read with Builtin.addressof(&self) — current Property.View.Read
//      approach. Works but requires `var`. This is the baseline we're trying to beat.
// V5b: Builtin.addressOfBorrow — does not exist in Swift.
// V6:  withUnsafePointer(to:) inside _read — requires `inout` for ~Copyable,
//      so still needs `mutating`. No workaround exists.
//
// Conclusion: Pointer-based non-mutating peek on ~Copyable is impossible
//             without compiler changes. The eager Copyable struct approach
//             is the only viable path for `let` bindings.

// ============================================================================
// MARK: - Test with let bindings
// ============================================================================

print("=== Variant 1: Eager Copyable Struct (computed property) ===")
do {
    let inline = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  inline.peek1.front = \(inline.peek1.front)")
    print("  inline.peek1.back  = \(inline.peek1.back)")

    let heap = HeapContainer([10, 20, 30])
    print("  heap.peek1.front   = \(heap.peek1.front)")
    print("  heap.peek1.back    = \(heap.peek1.back)")
}

print("\n=== Variant 2: Eager Copyable Struct (_read coroutine) ===")
do {
    let inline = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  inline.peek2.front = \(inline.peek2.front)")
    print("  inline.peek2.back  = \(inline.peek2.back)")

    let heap = HeapContainer([10, 20, 30])
    print("  heap.peek2.front   = \(heap.peek2.front)")
    print("  heap.peek2.back    = \(heap.peek2.back)")
}

print("\n=== Variant 3: Named Tuple ===")
do {
    let inline = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  inline.peek3.front = \(inline.peek3.front)")
    print("  inline.peek3.back  = \(inline.peek3.back)")
}

print("\n=== Variant 4: Lazy via class reference (heap only) ===")
do {
    let heap = HeapContainer([10, 20, 30])
    print("  heap.peek4.front   = \(heap.peek4.front)")
    print("  heap.peek4.back    = \(heap.peek4.back)")
}

// Test that Variant 1 genuinely works with let + ~Copyable base
print("\n=== Verification: let binding + ~Copyable base ===")
do {
    let buffer = InlineContainer<Int, 8>(first: 42, second: 99, third: 7)
    let f = buffer.peek1.front
    let b = buffer.peek1.back
    assert(f == 42, "front should be 42")
    assert(b == 7, "back should be 7")
    print("  PASS: let binding works with ~Copyable base")
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================
// V1 (Eager struct, computed property):  CONFIRMED — let + ~Copyable base works
// V2 (Eager struct, _read):             CONFIRMED — identical to V1
// V3 (Named tuple):                     CONFIRMED — let + ~Copyable base works
// V4 (Lazy class ref, heap only):       CONFIRMED — let works (heap-backed only)
// V5/V6 (Pointer-based):               NOT TESTABLE — requires Builtin/~Escapable
//
// Recommendation: V1 (eager Copyable struct via computed property)
//   - Works with `let` bindings on ~Copyable base ✓
//   - Works for both inline (~Copyable) and heap (Copyable) containers ✓
//   - No coroutine overhead (vs V2) ✓
//   - Type-safe with named fields (vs V3 tuple) ✓
//   - Universal — not limited to heap-backed (vs V4) ✓
//   - Trade-off: Always copies both front and back eagerly, even if only one is accessed.
//     Acceptable for peek (Elements are Copyable by constraint, values are small).
