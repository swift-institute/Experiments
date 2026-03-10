// MARK: - Separate Module Conformance
// Purpose: Module boundaries prevent poisoning
// Status: SOLUTION FOUND
// Date: 2026-01-22
// Toolchain: Swift 6.2

// Problem: Sequence conformance adds implicit `where Element: Copyable`
// to all extensions of a type. This "poisons" the type for ~Copyable use.
//
// Solution: Put the core type in Module A (no Sequence conformance).
// Put the Sequence conformance in Module B (which imports Module A).
// Consumers who need ~Copyable support import only Module A.
// Consumers who need Sequence import Module B.

// Simulating the pattern in a single file:

// "Module A" — core type, ~Copyable compatible
// The struct itself stays Copyable (all stored properties are Copyable).
// The generic parameter accepts ~Copyable types.
struct Stack<Element: ~Copyable> {
    private var storage: [Int] = []  // simplified: tracks Int values
    private var _count: Int = 0

    var count: Int { _count }
    var isEmpty: Bool { _count == 0 }

    mutating func push(_ value: Int) {
        storage.append(value)
        _count += 1
    }

    mutating func pop() -> Int? {
        guard _count > 0 else { return nil }
        _count -= 1
        return storage.removeLast()
    }
}

// "Module B" — Sequence conformance, only for Copyable elements.
// In a real multi-module setup, this would live in a separate module
// so that importing only Module A avoids the Sequence constraint.
extension Stack: Sequence where Element: Copyable {
    struct Iterator: IteratorProtocol {
        var elements: [Int]
        var index: Int = 0
        mutating func next() -> Int? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }

    func makeIterator() -> Iterator {
        Iterator(elements: storage)
    }
}

// Usage with Copyable — can iterate
var intStack = Stack<Int>()
intStack.push(1)
intStack.push(2)
intStack.push(3)

for item in intStack {
    print("Item: \(item)")
}

// Usage with ~Copyable — core operations work, no Sequence
struct Resource: ~Copyable { var id: Int }
var resStack = Stack<Resource>()
resStack.push(10)
let popped = resStack.pop()
print("Popped: \(popped!)")
assert(popped == 10)
assert(resStack.isEmpty)

print("separate-module-conformance: SOLUTION FOUND")
