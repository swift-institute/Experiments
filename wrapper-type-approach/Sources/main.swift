// MARK: - Wrapper Type Approach
// Purpose: Wrapper types avoid direct conformance
// Status: WORKAROUND FOUND
// Date: 2026-01-22
// Toolchain: Swift 6.2

// Problem: Adding Sequence conformance to Container<Element: ~Copyable>
// poisons it for ~Copyable use. Adding Comparable to a type may conflict
// with its design.
//
// Workaround: Wrap in a newtype that adds the conformance.

struct Container<Element: ~Copyable>: ~Copyable {
    var storage: [Int]  // simplified
    var count: Int { storage.count }

    init(_ elements: Int...) {
        storage = elements
    }
}

// Cannot add Sequence to Container without poisoning ~Copyable.
// Instead, create a wrapper:

struct SequenceView<Element> {
    let elements: [Int]  // Copies data out for iteration

    init(_ container: borrowing Container<Element>) {
        self.elements = container.storage
    }
}

extension SequenceView: Sequence {
    func makeIterator() -> Array<Int>.Iterator {
        elements.makeIterator()
    }
}

// Container provides the wrapper via a method
extension Container where Element: Copyable {
    func asSequence() -> SequenceView<Element> {
        SequenceView(self)
    }
}

// Usage with Copyable — can iterate via wrapper
let intContainer = Container<Int>(1, 2, 3, 4, 5)
for item in intContainer.asSequence() {
    print("Item: \(item)")
}

// Usage with ~Copyable — core operations still work
struct Resource: ~Copyable { var id: Int }
let resContainer = Container<Resource>(10, 20, 30)
print("Resource count: \(resContainer.count)")
assert(resContainer.count == 3)
// resContainer.asSequence() — not available (Element is ~Copyable)

print("wrapper-type-approach: WORKAROUND FOUND")
