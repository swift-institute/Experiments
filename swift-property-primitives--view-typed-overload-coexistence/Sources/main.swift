// MARK: - View.Typed.Valued.Valued Overload Coexistence
// Purpose: Verify Property.View.Typed.Valued<N>.Valued<capacity> enables
//          extension-level constraints for ~Copyable containers with TWO
//          value generics (e.g., Buffer.Linked.Inline<N, capacity>).
//
// Background: Property.View.Typed.Valued<n> lifts ONE value generic.
//             Containers like Buffer.Linked.Inline need TWO (N + capacity).
//             Chaining .Valued.Valued should lift both.
//
// Hypothesis: .Valued<n>.Valued<m> composes, allowing ALL constraints at
//             extension level for types with two value generics.
//
// Toolchain: Apple Swift 6.2.3
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 3 variants compile and run correctly
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//   V-1: Single Valued<N> with ~Copyable extensions — CONFIRMED
//   V-2: Valued<N>.Valued<capacity> with ~Copyable extensions — CONFIRMED
//   V-3: Copyable accessor overload + Copyable-only method on Valued.Valued — CONFIRMED
// Date: 2026-02-12

import Property_Primitives

// ============================================================================
// MARK: - Container with TWO value generics
// ============================================================================

struct Container<Element: ~Copyable, let N: Int>: ~Copyable {
    struct Inline<let capacity: Int>: ~Copyable {
        var count: Int = 0

        enum Error: Swift.Error { case capacityExceeded }

        static func insertFront(
            _ element: consuming Element,
            count: inout Int
        ) throws(Error) {
            count += 1
            print("    Inline insertFront (count=\(count))")
        }

        static func insertBack(
            _ element: consuming Element,
            count: inout Int
        ) throws(Error) {
            count += 1
            print("    Inline insertBack (count=\(count))")
        }

        static func removeFront(
            count: inout Int
        ) -> Element? {
            guard count > 0 else { return nil }
            count -= 1
            print("    Inline removeFront (count=\(count))")
            return nil
        }

        static func removeBack(
            count: inout Int
        ) -> Element? {
            guard count > 0 else { return nil }
            count -= 1
            print("    Inline removeBack (count=\(count))")
            return nil
        }
    }
}

// ============================================================================
// MARK: - Tag Types
// ============================================================================

extension Container where Element: ~Copyable {
    enum Insert {}
    enum Remove {}
}

// ============================================================================
// MARK: - Variant 1: Single Valued — Container<E, N> (one value generic)
// ============================================================================

struct HeapContainer<Element: ~Copyable, let N: Int>: ~Copyable {
    var count: Int = 0

    enum Error: Swift.Error { case capacityExceeded }

    static func insertFront(
        _ element: consuming Element,
        count: inout Int
    ) throws(Error) {
        count += 1
        print("    Heap insertFront (count=\(count))")
    }

    static func removeFront(
        count: inout Int
    ) -> Element? {
        guard count > 0 else { return nil }
        count -= 1
        print("    Heap removeFront (count=\(count))")
        return nil
    }
}

extension HeapContainer where Element: ~Copyable {
    enum Insert {}
    enum Remove {}
}

extension HeapContainer where Element: ~Copyable {
    var insert: Property<Insert, Self>.View.Typed<Element>.Valued<N> {
        mutating _read {
            yield unsafe Property<Insert, Self>.View.Typed<Element>.Valued<N>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Insert, Self>.View.Typed<Element>.Valued<N>(&self)
            yield &view
        }
    }

    var remove: Property<Remove, Self>.View.Typed<Element>.Valued<N> {
        mutating _read {
            yield unsafe Property<Remove, Self>.View.Typed<Element>.Valued<N>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Remove, Self>.View.Typed<Element>.Valued<N>(&self)
            yield &view
        }
    }
}

extension Property.View.Typed.Valued
where Tag == HeapContainer<Element, n>.Insert,
      Base == HeapContainer<Element, n>,
      Element: ~Copyable
{
    @_lifetime(&self)
    mutating func front(
        _ element: consuming Element
    ) throws(HeapContainer<Element, n>.Error) {
        try unsafe HeapContainer<Element, n>.insertFront(
            consume element,
            count: &base.pointee.count
        )
    }
}

extension Property.View.Typed.Valued
where Tag == HeapContainer<Element, n>.Remove,
      Base == HeapContainer<Element, n>,
      Element: ~Copyable
{
    @_lifetime(&self)
    mutating func front() -> Element? {
        unsafe HeapContainer<Element, n>.removeFront(
            count: &base.pointee.count
        )
    }
}

// ============================================================================
// MARK: - Variant 2: Valued.Valued — Container.Inline<N, capacity> (two value generics)
// ============================================================================

extension Container.Inline where Element: ~Copyable {
    var insert: Property<Container<Element, N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Container<Element, N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Container<Element, N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>(&self)
            yield &view
        }
    }

    var remove: Property<Container<Element, N>.Remove, Self>.View.Typed<Element>.Valued<N>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Container<Element, N>.Remove, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Container<Element, N>.Remove, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>(&self)
            yield &view
        }
    }
}

// Extension with ALL constraints at extension level — both n and m available
extension Property.View.Typed.Valued.Valued
where Tag == Container<Element, n>.Insert,
      Base == Container<Element, n>.Inline<m>,
      Element: ~Copyable
{
    @_lifetime(&self)
    mutating func front(
        _ element: consuming Element
    ) throws(Container<Element, n>.Inline<m>.Error) {
        try unsafe Container<Element, n>.Inline<m>.insertFront(
            consume element,
            count: &base.pointee.count
        )
    }

    @_lifetime(&self)
    mutating func back(
        _ element: consuming Element
    ) throws(Container<Element, n>.Inline<m>.Error) {
        try unsafe Container<Element, n>.Inline<m>.insertBack(
            consume element,
            count: &base.pointee.count
        )
    }
}

extension Property.View.Typed.Valued.Valued
where Tag == Container<Element, n>.Remove,
      Base == Container<Element, n>.Inline<m>,
      Element: ~Copyable
{
    @_lifetime(&self)
    mutating func front() -> Element? {
        unsafe Container<Element, n>.Inline<m>.removeFront(
            count: &base.pointee.count
        )
    }

    @_lifetime(&self)
    mutating func back() -> Element? {
        unsafe Container<Element, n>.Inline<m>.removeBack(
            count: &base.pointee.count
        )
    }
}

// ============================================================================
// MARK: - Variant 3: Copyable overloads on Valued.Valued
// ============================================================================

extension Container.Inline where Element: Copyable {
    var insert: Property<Container<Element, N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity> {
        mutating _read {
            print("    [Copyable Inline accessor: CoW prep]")
            yield unsafe Property<Container<Element, N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>(&self)
        }
        mutating _modify {
            print("    [Copyable Inline accessor: CoW prep]")
            var view = unsafe Property<Container<Element, N>.Insert, Self>.View.Typed<Element>.Valued<N>.Valued<capacity>(&self)
            yield &view
        }
    }
}

extension Property.View.Typed.Valued.Valued
where Tag == Container<Element, n>.Insert,
      Base == Container<Element, n>.Inline<m>,
      Element: Copyable
{
    @_lifetime(&self)
    mutating func safe(_ element: consuming Element) {
        try! unsafe Container<Element, n>.Inline<m>.insertFront(
            consume element,
            count: &base.pointee.count
        )
    }
}

// ============================================================================
// MARK: - Test Execution
// ============================================================================

print("=== V1: Single Valued — HeapContainer<Int, 2> ===")
do {
    var c = HeapContainer<Int, 2>()
    try c.insert.front(10)
    _ = c.remove.front()
    print("  count: \(c.count)")
}

print("\n=== V2: Valued.Valued — Container<Int, 2>.Inline<8> (~Copyable path) ===")
do {
    var c = Container<Int, 2>.Inline<8>()
    try c.insert.front(10)
    try c.insert.back(20)
    _ = c.remove.front()
    print("  count: \(c.count)")
}

print("\n=== V3: Valued.Valued — Copyable accessor + Copyable-only method ===")
do {
    var c = Container<Int, 2>.Inline<8>()
    c.insert.safe(10)  // no try — Copyable-only
    c.insert.safe(20)  // no try
    print("  count: \(c.count)")
}

print("\nAll variants completed.")
