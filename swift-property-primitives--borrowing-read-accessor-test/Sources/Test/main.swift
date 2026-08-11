// ===----------------------------------------------------------------------===//
// EXPERIMENT: Borrowing Read Accessor — Pointer Projection from Borrow
// ===----------------------------------------------------------------------===//
//
// Purpose: Determine whether user code can obtain UnsafePointer<Self> from a
//          non-mutating/borrowing context on a ~Copyable type, enabling
//          non-mutating read accessors that work with `let` bindings
//
// History:
//   v1 (2026-02-XX): Concluded the gap was fundamental — no way to project
//                     pointer from borrow. This was WRONG.
//   v2 (2026-02-23): SUPERSEDED — withUnsafePointer(to: self) works from
//                     non-mutating context on ~Copyable types. The stdlib
//                     implementation wraps Builtin.addressOfBorrow(value).
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-02-13-a
// Platform: macOS 15.0 (arm64)
//
// Result: REFUTED — The gap is NOT fundamental. withUnsafePointer(to: self)
//         provides pointer-from-borrow through the public API.
//         Builtin.addressOfBorrow exists in the compiler and is used by
//         stdlib (InlineArray._protectedAddress, CollectionOfOne.span,
//         withUnsafePointer(to:_:)). User code accesses it indirectly via
//         withUnsafePointer(to: borrowing T, _:).
// Date: 2026-02-23
// ===----------------------------------------------------------------------===//

// MARK: - Infrastructure

/// Minimal ~Copyable container for testing pointer projection
struct Container<Element: Copyable & Sendable, let capacity: Int>: ~Copyable {
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
// MARK: - Test 1: Non-mutating _read without pointer (baseline)
// ============================================================================
// Hypothesis: Non-mutating _read can yield stored properties directly
// Result: CONFIRMED (unchanged from v1)

struct SimpleContainer {
    var value: Int = 42

    var borrowedValue: Int {
        _read {
            yield value
        }
    }
}

// ============================================================================
// MARK: - Test 2: withUnsafePointer(to: self) in non-mutating computed property
// ============================================================================
// Hypothesis: withUnsafePointer(to:_:) takes `borrowing T` where T: ~Copyable,
//             so passing `self` from a non-mutating context should work.
// v1 status: Assumed impossible. Never tested.
// v2 Result: CONFIRMED — works with let binding on ~Copyable base
//
// This is the KEY finding that invalidates the v1 conclusion.

extension Container where Element == Int {
    var peekFront: Element {
        withUnsafePointer(to: self) { ptr in
            unsafe ptr.pointee.elements[0]
        }
    }

    var peekBack: Element {
        withUnsafePointer(to: self) { ptr in
            unsafe ptr.pointee.elements[ptr.pointee.count - 1]
        }
    }
}

// ============================================================================
// MARK: - Test 3: withUnsafePointer(to: self) in borrowing func
// ============================================================================
// Hypothesis: Same pattern works in a borrowing func
// v1 status: Not tested
// v2 Result: CONFIRMED

extension Container where Element == Int {
    borrowing func peekFrontBorrowing() -> Element {
        withUnsafePointer(to: self) { ptr in
            unsafe ptr.pointee.elements[0]
        }
    }
}

// ============================================================================
// MARK: - Test 4: withUnsafePointer(to: self) inside non-mutating _read
// ============================================================================
// Hypothesis: withUnsafePointer(to: self) works inside non-mutating _read
// v1 status: Not tested
// v2 Result: CONFIRMED

extension Container where Element == Int {
    var peekFrontRead: Element {
        _read {
            yield withUnsafePointer(to: self) { ptr in
                unsafe ptr.pointee.elements[0]
            }
        }
    }
}

// ============================================================================
// MARK: - Test 5: Copyable snapshot via withUnsafePointer(to: self)
// ============================================================================
// Hypothesis: Build a Copyable struct inside withUnsafePointer and return it.
//             This is the practical pattern for buffer.peek.front/.back
// v1 status: Not tested
// v2 Result: CONFIRMED

struct PeekSnapshot<Element: Copyable & Sendable>: Sendable {
    let front: Element
    let back: Element
}

extension Container {
    var peek: PeekSnapshot<Element> {
        withUnsafePointer(to: self) { ptr in
            unsafe PeekSnapshot(
                front: ptr.pointee.elements[0],
                back: ptr.pointee.elements[ptr.pointee.count - 1]
            )
        }
    }
}

// ============================================================================
// MARK: - Test 6: Direct property access (no pointer needed)
// ============================================================================
// Hypothesis: On ~Copyable types, Copyable stored properties can be read
//             directly in non-mutating computed properties
// v1 status: Partially documented as workaround
// v2 Result: CONFIRMED — simplest correct approach when Elements are Copyable

extension Container {
    var peekDirect: PeekSnapshot<Element> {
        PeekSnapshot(front: elements[0], back: elements[count - 1])
    }
}

// ============================================================================
// MARK: - Test 7: withUnsafePointer on stored property (existing workaround)
// ============================================================================
// Hypothesis: withUnsafePointer(to: storedProperty) works from non-mutating
//             context — this was the known workaround from v1
// Result: CONFIRMED (unchanged from v1)

extension Container where Element == Int {
    var peekFrontStoredProperty: Element {
        withUnsafePointer(to: elements) { ptr in
            unsafe ptr.pointee[0]
        }
    }
}

// ============================================================================
// MARK: - Test 8: ~Escapable View with withUnsafePointer(to: self)
// ============================================================================
// This was the "holy grail" from v1 — a ~Escapable view that holds a pointer
// to self, obtained non-mutating. The Lifetimes feature is enabled in this
// experiment's Package.swift.
//
// Hypothesis: withUnsafePointer(to: self) + ~Escapable View provides
//             Property.View.Read semantics without mutating
// Result: [DOCUMENTED — requires further investigation]
//
// NOTE: The initializer for ~Escapable types with stored UnsafePointer
// currently produces "an initializer cannot return a ~Escapable result".
// This is a separate limitation from pointer acquisition — the pointer
// acquisition itself works (Tests 2-5 prove this). The ~Escapable view
// pattern needs initializer support to land, which is tracked separately.

// Commented out — kept for documentation of the remaining limitation:
//
// struct ReadView<Base: ~Copyable>: ~Copyable, ~Escapable {
//     let base: UnsafePointer<Base>
//
//     @_lifetime(borrow base)
//     init(_ base: UnsafePointer<Base>) {
//         self.base = base
//     }
// }
//
// extension Container where Element == Int {
//     var readView: ReadView<Self> {
//         withUnsafePointer(to: self) { ptr in
//             ReadView(ptr)
//         }
//     }
// }

// ============================================================================
// MARK: - Verification
// ============================================================================

print("=== Borrowing Read Accessor — Pointer Projection Test ===\n")

// Test 1
do {
    let c = SimpleContainer()
    print("Test 1 — Non-mutating _read yielding stored property:")
    print("  c.borrowedValue = \(c.borrowedValue)")
    assert(c.borrowedValue == 42)
    print("  CONFIRMED")
}

// Test 2
do {
    let c = Container<Int, 8>(first: 10, second: 20, third: 30)
    print("\nTest 2 — withUnsafePointer(to: self) in computed property:")
    print("  c.peekFront = \(c.peekFront)")
    print("  c.peekBack  = \(c.peekBack)")
    assert(c.peekFront == 10)
    assert(c.peekBack == 30)
    print("  CONFIRMED — non-mutating, let binding, ~Copyable base")
}

// Test 3
do {
    let c = Container<Int, 8>(first: 10, second: 20, third: 30)
    print("\nTest 3 — withUnsafePointer(to: self) in borrowing func:")
    print("  c.peekFrontBorrowing() = \(c.peekFrontBorrowing())")
    assert(c.peekFrontBorrowing() == 10)
    print("  CONFIRMED")
}

// Test 4
do {
    let c = Container<Int, 8>(first: 10, second: 20, third: 30)
    print("\nTest 4 — withUnsafePointer(to: self) inside _read:")
    print("  c.peekFrontRead = \(c.peekFrontRead)")
    assert(c.peekFrontRead == 10)
    print("  CONFIRMED")
}

// Test 5
do {
    let c = Container<Int, 8>(first: 10, second: 20, third: 30)
    print("\nTest 5 — Copyable snapshot via withUnsafePointer(to: self):")
    print("  c.peek.front = \(c.peek.front)")
    print("  c.peek.back  = \(c.peek.back)")
    assert(c.peek.front == 10)
    assert(c.peek.back == 30)
    print("  CONFIRMED")
}

// Test 6
do {
    let c = Container<Int, 8>(first: 10, second: 20, third: 30)
    print("\nTest 6 — Direct property access (no pointer):")
    print("  c.peekDirect.front = \(c.peekDirect.front)")
    print("  c.peekDirect.back  = \(c.peekDirect.back)")
    assert(c.peekDirect.front == 10)
    assert(c.peekDirect.back == 30)
    print("  CONFIRMED")
}

// Test 7
do {
    let c = Container<Int, 8>(first: 10, second: 20, third: 30)
    print("\nTest 7 — withUnsafePointer on stored property:")
    print("  c.peekFrontStoredProperty = \(c.peekFrontStoredProperty)")
    assert(c.peekFrontStoredProperty == 10)
    print("  CONFIRMED")
}

// Test 8 — documented only, not runnable yet
print("\nTest 8 — ~Escapable View with pointer-from-borrow:")
print("  DOCUMENTED — ~Escapable initializer limitation blocks this pattern")
print("  The pointer acquisition works (Tests 2-5). The view construction")
print("  needs ~Escapable initializer support (separate limitation).")

// ============================================================================
// MARK: - Test 9: ~Escapable init(borrowing:) with withUnsafePointer(to:)
// ============================================================================
// Hypothesis: A ~Escapable type can have init(borrowing:) that obtains
//             UnsafePointer<Base> via withUnsafePointer(to: base) and stores it.
//             This is the exact pattern Property.View.Read.init(borrowing:) needs.
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

struct BorrowView<Base: ~Copyable>: ~Copyable, ~Escapable {
    let _base: UnsafePointer<Base>

    @_lifetime(borrow base)
    init(borrowing base: borrowing Base) {
        unsafe _base = withUnsafePointer(to: base) { unsafe $0 }
    }

    var value: UnsafePointer<Base> {
        unsafe _base
    }
}

do {
    let c = Container<Int, 8>(first: 10, second: 20, third: 30)
    print("\nTest 9 — ~Escapable init(borrowing:) with withUnsafePointer(to:):")
    let view = BorrowView(borrowing: c)
    let front = unsafe view.value.pointee.elements[0]
    print("  view.value.pointee.elements[0] = \(front)")
    assert(front == 10)
    print("  CONFIRMED — ~Escapable init(borrowing:) works with pointer escape")
}

print("\n=== UPDATED ANALYSIS (v2, 2026-02-23) ===")
print("")
print("v1 CONCLUSION (SUPERSEDED):")
print("  'The gap is fundamental to Swift's current ownership model design'")
print("  This was WRONG. withUnsafePointer(to: self) was never tested.")
print("")
print("v2 CONCLUSION:")
print("  withUnsafePointer(to: self) WORKS from non-mutating context on")
print("  ~Copyable types with let bindings. The stdlib wraps this as")
print("  Builtin.addressOfBorrow(value) internally.")
print("")
print("WHAT EXISTS (updated):")
print("  - withUnsafePointer(to: self) — pointer from borrow, closure-scoped")
print("  - withUnsafePointer(to: storedProperty) — same, per-property")
print("  - Non-mutating _read (yields stored properties)")
print("  - Direct stored property access in borrowing context")
print("  - ~Escapable types (Lifetimes feature)")
print("")
print("WHAT'S REMAINING:")
print("  - ~Escapable initializer for stored UnsafePointer (compiler limitation)")
print("  - SE-0474 CoroutineAccessors (experimental, not yet stable)")
print("  - BorrowAndMutateAccessors (experimental, not yet stable)")
print("")
print("IMPLICATION FOR PROPERTY.VIEW.READ:")
print("  A non-mutating variant IS feasible. Current Property.View.Read")
print("  requires &self to obtain UnsafePointer<Base>. With")
print("  withUnsafePointer(to: self), the pointer can be obtained from a")
print("  non-mutating context — no &self needed. The closure scope means")
print("  the view must be constructed and consumed within the closure,")
print("  but this is compatible with the _read coroutine pattern.")

print("\n  ALL TESTS PASSED")

// ============================================================================
// MARK: - Results Summary
// ============================================================================
// Test 1 (non-mutating _read, no pointer):              CONFIRMED
// Test 2 (withUnsafePointer(to: self) computed):         CONFIRMED — KEY FINDING
// Test 3 (withUnsafePointer(to: self) borrowing func):   CONFIRMED
// Test 4 (withUnsafePointer(to: self) in _read):         CONFIRMED
// Test 5 (Copyable snapshot via withUnsafePointer):       CONFIRMED
// Test 6 (Direct property access, no pointer):           CONFIRMED
// Test 7 (withUnsafePointer on stored property):         CONFIRMED
// Test 8 (~Escapable view with pointer-from-borrow):     DOCUMENTED (blocked by
//          ~Escapable initializer limitation, not pointer acquisition)
// Test 9 (~Escapable init(borrowing:) via withUnsafePointer): CONFIRMED
//
// v1 RESULT: CONFIRMED (gap is fundamental)  ← SUPERSEDED
// v2 RESULT: REFUTED — pointer-from-borrow IS available via public API
//
// The "fundamental gap" was an error of omission — withUnsafePointer(to: self)
// was never tested. It works because the stdlib implementation calls
// Builtin.addressOfBorrow(value), which projects a pointer from a borrow.
// This builtin is used in production by InlineArray._protectedAddress,
// CollectionOfOne.span, and withUnsafePointer(to:_:) itself.
