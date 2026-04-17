// MARK: - Conditional Copyable Type
// Purpose: Conditional Copyable conformance doesn't prevent constraint poisoning
// Status: CONFIRMED FAILS (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — deinit conflicts with conditional Copyable conformance (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
// Revalidated: Swift 6.3.1 (2026-04-17) — STILL PRESENT

// Attempt: Make Container conditionally Copyable, hoping the compiler
// can separate the Copyable and ~Copyable paths

// Variant 1: Container that is unconditionally ~Copyable with deinit
// Adding conditional Copyable conformance conflicts with deinit
struct Container<Element: ~Copyable>: ~Copyable {
    var ptr: UnsafeMutablePointer<Element>
    var count: Int

    init(capacity: Int) {
        ptr = .allocate(capacity: capacity)
        count = 0
    }

    // deinit is required for cleanup, but conflicts with conditional Copyable
    deinit {
        ptr.deinitialize(count: count)
        ptr.deallocate()
    }
}

// This conditional Copyable conformance conflicts with deinit above:
// "deinitializer cannot be declared in generic struct that conforms to 'Copyable'"
extension Container: Copyable where Element: Copyable {}

// Test: Can we still use Container with ~Copyable elements?
struct Resource: ~Copyable { var value: Int }
var c = Container<Resource>(capacity: 4)
print("Container<Resource> count: \(c.count)")

// Variant 2: Without deinit — does conditional Copyable + Sequence work?
struct Container2<Element: ~Copyable>: ~Copyable {
    var count: Int = 0
}

extension Container2: Copyable where Element: Copyable {}

// Can we add Sequence when Container2 is conditionally Copyable?
extension Container2: Sequence where Element: Copyable {
    func makeIterator() -> EmptyCollection<Element>.Iterator {
        EmptyCollection<Element>().makeIterator()
    }
}

// Test with ~Copyable element
var c2 = Container2<Resource>()
print("Container2<Resource> count: \(c2.count)")
print("Conditional Copyable test: BUILD SUCCEEDED")
