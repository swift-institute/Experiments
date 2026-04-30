// MARK: - ~Copyable Accessor Incompatibility
// Purpose: Accessor patterns incompatible with ~Copyable containers
// Status: CONFIRMED (2026-01-20, Swift 6.2)
// Revalidation: FIXED in Swift 6.2.4 — _read/_modify work with ~Copyable (2026-03-10)
// Revalidation: Swift 6.3.1 (2026-04-17) — STILL WORKS
// Result: CONFIRMED — _read/_modify accessors with ~Copyable containers originally broken, fixed in Swift 6.2.4
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

struct Container<Element: ~Copyable>: ~Copyable {
    private var storage: UnsafeMutablePointer<Element>
    private var _count: Int

    init(capacity: Int) {
        storage = .allocate(capacity: capacity)
        _count = 0
    }

    var count: Int { _count }

    // Standard subscript — does this work with ~Copyable?
    subscript(index: Int) -> Element {
        _read {
            yield storage[index]
        }
        _modify {
            yield &storage[index]
        }
    }

    deinit {
        storage.deinitialize(count: _count)
        storage.deallocate()
    }
}

// Test with Copyable
var intContainer = Container<Int>(capacity: 4)
print("Int container created")

// Test with ~Copyable — this may fail
struct Resource: ~Copyable { var value: Int }
var resContainer = Container<Resource>(capacity: 4)
print("Resource container created")
print("Accessor incompatibility test: BUILD SUCCEEDED")
