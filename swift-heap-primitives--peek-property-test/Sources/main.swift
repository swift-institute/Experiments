// ===----------------------------------------------------------------------===//
// Experiment: PeekAccessor to Property Migration
// Date: 2026-01-26
// Status: CONFIRMED
//
// Result: Property.Typed<Element> pattern works for PeekAccessor migration.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// Key insight: Heap.MinMax: Copyable where Element: Copyable
// This means in the context where peek is available (Element: Copyable),
// the entire struct can be passed to Property.Typed (owned pattern).
//
// Migration pattern used:
//   - Tag: enum Peek {} (added to Extremum namespaces)
//   - Typealias: uses existing Property<Tag> = Property_Primitives.Property<Tag, Heap.MinMax>
//   - Accessor: var peek: Property<Peek>.Typed<Element> { Property.Typed(self) }
//   - Extension: on Property_Primitives.Property.Typed with constraints
//
// API preserved:
//   - heap.peek.min  (non-mutating)
//   - heap.peek.max  (non-mutating)
//   - Works with let bindings
// ===----------------------------------------------------------------------===//

import Property_Primitives
import Comparison_Primitives

// MARK: - Mock Implementation (verified pattern)

final class MockStorage<Element: Copyable>: @unchecked Sendable {
    var elements: [Element]
    init(_ elements: [Element] = []) { self.elements = elements }
    var count: Int { elements.count }
    func read(at index: Int) -> Element? {
        guard index < elements.count else { return nil }
        return elements[index]
    }
}

struct MockHeapMinMax<Element: Copyable & Comparison.`Protocol`> {
    var _storage: MockStorage<Element>
    init(_ elements: [Element] = []) { self._storage = MockStorage(elements) }
    var count: Int { _storage.count }
}

extension MockHeapMinMax {
    enum Peek {}
    typealias Property<Tag> = Property_Primitives.Property<Tag, MockHeapMinMax<Element>>
}

extension MockHeapMinMax where Element: Copyable & Comparison.`Protocol` {
    var peek: Property<Peek>.Typed<Element> {
        Property_Primitives.Property.Typed(self)
    }
}

extension Property_Primitives.Property.Typed
where Tag == MockHeapMinMax<Element>.Peek,
      Base == MockHeapMinMax<Element>,
      Element: Copyable & Comparison.`Protocol`
{
    var min: Element? {
        guard base._storage.count > 0 else { return nil }
        return base._storage.read(at: 0)
    }

    var max: Element? {
        guard base._storage.count > 0 else { return nil }
        let count = base._storage.count
        if count == 1 { return base._storage.read(at: 0) }
        if count == 2 { return base._storage.read(at: 1) }
        let e1 = base._storage.read(at: 1)!
        let e2 = base._storage.read(at: 2)!
        return e1 < e2 ? e2 : e1
    }
}

// MARK: - Test

func test() {
    let heap = MockHeapMinMax<Int>([1, 8, 5, 3, 7])

    // Non-mutating access with let binding
    let minVal = heap.peek.min
    let maxVal = heap.peek.max

    print("heap.peek.min = \(minVal ?? -1)")
    print("heap.peek.max = \(maxVal ?? -1)")

    assert(minVal == 1)
    assert(maxVal == 8)

    print("\nCONFIRMED: Property.Typed pattern works for PeekAccessor")
}

test()
