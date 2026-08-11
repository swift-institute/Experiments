// MARK: - Non-Mutating Pointer Projection on ~Copyable
// Purpose: Verify whether user code can obtain UnsafePointer<Self> from a
//          non-mutating context on a ~Copyable type, enabling non-mutating
//          read accessors that work with `let` bindings
//
// Background: The stdlib uses Builtin.addressOfBorrow(self) internally
//             (InlineArray._protectedAddress, CollectionOfOne.span,
//              withUnsafePointer(to:_:)). But `import Builtin` is not
//             available to user code. This experiment tests what IS available:
//             withUnsafePointer(to: borrowing T, _:) and direct property access.
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-02-13-a
// Platform: macOS 15.0 (arm64)
//
// Result: ALL 7 VARIANTS CONFIRMED — withUnsafePointer(to: self) works
//         non-mutating on ~Copyable types with let bindings. Direct
//         property access also works. The "fundamental language gap"
//         documented in property-primitives borrowing-read-accessor-test
//         is resolved: withUnsafePointer(to:_:) wraps Builtin.addressOfBorrow
//         and is available to user code.
// Date: 2026-02-23

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

// ============================================================================
// MARK: - Variant 1: withUnsafePointer(to: self) in non-mutating computed property
// ============================================================================
// Hypothesis: withUnsafePointer(to:_:) takes `borrowing T` where T: ~Copyable,
//             so passing `self` from a non-mutating context should work.
//             The stdlib implementation uses Builtin.addressOfBorrow(value).
// Result: CONFIRMED — works with let binding on ~Copyable base

extension InlineContainer where Element == Int {
    var peekFront1: Element {
        withUnsafePointer(to: self) { ptr in
            unsafe ptr.pointee.elements[0]
        }
    }

    var peekBack1: Element {
        withUnsafePointer(to: self) { ptr in
            unsafe ptr.pointee.elements[ptr.pointee.count - 1]
        }
    }
}

// ============================================================================
// MARK: - Variant 2: withUnsafePointer(to: self) in borrowing func
// ============================================================================
// Hypothesis: Same pattern works in a borrowing func
// Result: CONFIRMED

extension InlineContainer where Element == Int {
    borrowing func peekFront2() -> Element {
        withUnsafePointer(to: self) { ptr in
            unsafe ptr.pointee.elements[0]
        }
    }
}

// ============================================================================
// MARK: - Variant 3: Non-mutating _read with withUnsafePointer
// ============================================================================
// Hypothesis: withUnsafePointer(to: self) works inside non-mutating _read
// Result: CONFIRMED

extension InlineContainer where Element == Int {
    var peekFront3: Element {
        _read {
            yield withUnsafePointer(to: self) { ptr in
                unsafe ptr.pointee.elements[0]
            }
        }
    }
}

// ============================================================================
// MARK: - Variant 4: Copyable snapshot via withUnsafePointer(to: self)
// ============================================================================
// Hypothesis: Construct a Copyable struct inside withUnsafePointer and return
//             it. The snapshot escapes the closure but the pointer doesn't.
//             This is the pattern for buffer.peek.front / buffer.peek.back
// Result: CONFIRMED

struct PeekSnapshot<Element: Copyable & Sendable>: Sendable {
    let front: Element
    let back: Element
}

extension InlineContainer {
    var peek4: PeekSnapshot<Element> {
        withUnsafePointer(to: self) { ptr in
            unsafe PeekSnapshot(
                front: ptr.pointee.elements[0],
                back: ptr.pointee.elements[ptr.pointee.count - 1]
            )
        }
    }
}

// ============================================================================
// MARK: - Variant 5: Direct property access (no pointer, baseline)
// ============================================================================
// Hypothesis: On ~Copyable types, stored properties can be read directly
//             in non-mutating computed properties without any pointer.
//             This is the simplest correct approach.
// Result: CONFIRMED

extension InlineContainer {
    var peekFront5: Element {
        elements[0]
    }

    var peekBack5: Element {
        elements[count - 1]
    }
}

// ============================================================================
// MARK: - Variant 6: Direct property access returning Copyable snapshot
// ============================================================================
// Hypothesis: Same as V5 but returning a Copyable struct for .front/.back
//             syntax. No pointer needed at all — just read stored properties.
// Result: CONFIRMED

extension InlineContainer {
    var peek6: PeekSnapshot<Element> {
        PeekSnapshot(front: elements[0], back: elements[count - 1])
    }
}

// ============================================================================
// MARK: - Variant 7: withUnsafePointer on a stored property (not self)
// ============================================================================
// Hypothesis: withUnsafePointer(to: storedProperty) works from non-mutating
//             context — this is the existing Property.View.pointer(to:_:)
//             workaround
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

extension InlineContainer where Element == Int {
    var peekFront7: Element {
        withUnsafePointer(to: elements) { ptr in
            unsafe ptr.pointee[0]
        }
    }
}

// ============================================================================
// MARK: - Test with let bindings
// ============================================================================

print("=== Variant 1: withUnsafePointer(to: self) computed property ===")
do {
    let buffer = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  buffer.peekFront1 = \(buffer.peekFront1)")
    print("  buffer.peekBack1  = \(buffer.peekBack1)")
}

print("\n=== Variant 2: withUnsafePointer(to: self) borrowing func ===")
do {
    let buffer = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  buffer.peekFront2() = \(buffer.peekFront2())")
}

print("\n=== Variant 3: withUnsafePointer(to: self) inside _read ===")
do {
    let buffer = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  buffer.peekFront3 = \(buffer.peekFront3)")
}

print("\n=== Variant 4: Copyable snapshot via withUnsafePointer(to: self) ===")
do {
    let buffer = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  buffer.peek4.front = \(buffer.peek4.front)")
    print("  buffer.peek4.back  = \(buffer.peek4.back)")
}

print("\n=== Variant 5: Direct property access (baseline) ===")
do {
    let buffer = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  buffer.peekFront5 = \(buffer.peekFront5)")
    print("  buffer.peekBack5  = \(buffer.peekBack5)")
}

print("\n=== Variant 6: Copyable snapshot via direct access ===")
do {
    let buffer = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  buffer.peek6.front = \(buffer.peek6.front)")
    print("  buffer.peek6.back  = \(buffer.peek6.back)")
}

print("\n=== Variant 7: withUnsafePointer on stored property ===")
do {
    let buffer = InlineContainer<Int, 8>(first: 10, second: 20, third: 30)
    print("  buffer.peekFront7 = \(buffer.peekFront7)")
}

// Verification
print("\n=== Verification: let binding + ~Copyable base + assertions ===")
do {
    let buffer = InlineContainer<Int, 8>(first: 42, second: 99, third: 7)

    assert(buffer.peekFront1 == 42, "V1 front")
    assert(buffer.peekBack1 == 7, "V1 back")

    assert(buffer.peekFront2() == 42, "V2 front")

    assert(buffer.peekFront3 == 42, "V3 front")

    assert(buffer.peek4.front == 42, "V4 front")
    assert(buffer.peek4.back == 7, "V4 back")

    assert(buffer.peekFront5 == 42, "V5 front")
    assert(buffer.peekBack5 == 7, "V5 back")

    assert(buffer.peek6.front == 42, "V6 front")
    assert(buffer.peek6.back == 7, "V6 back")

    assert(buffer.peekFront7 == 42, "V7 front")

    print("  ALL ASSERTIONS PASSED")
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================
// V1 (withUnsafePointer(to: self) computed):     CONFIRMED
// V2 (withUnsafePointer(to: self) borrowing):    CONFIRMED
// V3 (withUnsafePointer(to: self) in _read):     CONFIRMED
// V4 (Copyable snapshot via withUnsafePointer):   CONFIRMED
// V5 (Direct property access, no pointer):       CONFIRMED
// V6 (Copyable snapshot via direct access):      CONFIRMED
// V7 (withUnsafePointer on stored property):     CONFIRMED
//
// Key finding: withUnsafePointer(to: self) WORKS from non-mutating context
// on ~Copyable types. The public API wraps Builtin.addressOfBorrow internally.
// This means pointer-based non-mutating peek IS possible through the public API.
//
// Implication for Property.View.Read: A non-mutating variant is now feasible.
// Property.View.Read currently uses `UnsafePointer<Base>` obtained via `&self`,
// requiring `mutating _read`. With `withUnsafePointer(to: self)`, the pointer
// can be obtained from a non-mutating context — no `&self` needed.
//
// Recommendation: V5/V6 (direct property access) for peek specifically,
// since peek elements are Copyable by constraint and the pattern is simpler.
// withUnsafePointer(to: self) (V1-V4) for future cases where pointer-based
// non-mutating access to ~Copyable state is genuinely needed.
