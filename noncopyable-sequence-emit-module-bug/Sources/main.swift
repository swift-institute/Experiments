// SUPERSEDED: See noncopyable-constraint-behavior
// MARK: - ~Copyable Sequence Module Emission Bug
// Purpose: Module emission failure with ~Copyable + Sequence conformance
// Status: BUG FILED #86669 (2026-01-20, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — Sequence inherits Copyable requirement (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT

// Minimal reproduction: generic type with ~Copyable that conditionally conforms to Sequence
// The -emit-module step crashes or produces invalid output

struct Collection<Element: ~Copyable>: ~Copyable {
    var elements: UnsafeMutablePointer<Element>
    var count: Int

    init() {
        elements = .allocate(capacity: 0)
        count = 0
    }

    deinit { elements.deallocate() }
}

extension Collection: @retroactive Sequence where Element: Copyable {
    struct Iterator: IteratorProtocol {
        var index: Int
        let count: Int
        let base: UnsafeMutablePointer<Element>
        mutating func next() -> Element? {
            guard index < count else { return nil }
            defer { index += 1 }
            return base[index]
        }
    }
    func makeIterator() -> Iterator {
        Iterator(index: 0, count: count, base: elements)
    }
}

// If this compiles and runs, the bug may be fixed
let c = Collection<Int>()
print("Collection created with count: \(c.count)")
print("Module emission test: BUILD SUCCEEDED")
