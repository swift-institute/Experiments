// ===----------------------------------------------------------------------===//
// EXPERIMENT: Can ~Copyable structs conform to Hash.Protocol & Sequence.Protocol?
// ===----------------------------------------------------------------------===//
//
// Hypothesis: Hash.Protocol and Sequence.Protocol from swift-primitives are
// designed for ~Copyable support and can be used instead of Swift equivalents.
//
// Question: Can Set.Ordered conform to these protocols instead of Swift ones?
//
// Status: CONFIRMED
//
// Result:
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// - Hash.Protocol WORKS for ~Copyable (provides ==, !=, hashValue)
// - Sequence.Protocol WORKS for ~Copyable (provides makeIterator, forEach)
// - for-in loops REQUIRE Swift.Sequence (which requires Copyable)
// - Users must use forEach() or index-based iteration for ~Copyable containers
//
// ===----------------------------------------------------------------------===//

// Simulate Hash.Protocol from swift-hash-primitives
enum Hash {
    protocol `Protocol`: ~Copyable {
        static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
        borrowing func hash(into hasher: inout Hasher)
    }
}

extension Hash.`Protocol` where Self: ~Copyable {
    var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }

    static func != (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(lhs == rhs)
    }
}

// Simulate Sequence.Protocol from swift-sequence-primitives
enum Sequence {
    /// A protocol for types that can be iterated, supporting `~Copyable`.
    ///
    /// NOTE: for-in syntax is NOT supported. Use .forEach or index-based iteration.
    protocol `Protocol`: ~Copyable {
        associatedtype Element
        associatedtype Iterator: IteratorProtocol where Iterator.Element == Element
        borrowing func makeIterator() -> Iterator
    }
}

// MARK: - Test: ~Copyable container conforming to both protocols

final class Storage<Element>: @unchecked Sendable {
    var elements: [Element] = []
    var count: Int { elements.count }

    init() {}

    func read(at index: Int) -> Element {
        elements[index]
    }

    func append(_ element: Element) {
        elements.append(element)
    }
}

struct Container<Element: Hashable>: ~Copyable {
    let storage: Storage<Element>

    init() {
        self.storage = Storage()
    }

    mutating func insert(_ element: Element) {
        storage.append(element)
    }

    var count: Int { storage.count }
}

// MARK: - Hash.Protocol conformance

extension Container: Hash.`Protocol` {
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if lhs.storage.read(at: i) != rhs.storage.read(at: i) {
                return false
            }
        }
        return true
    }

    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(storage.read(at: i))
        }
    }
}

// MARK: - Sequence.Protocol conformance

extension Container: Sequence.`Protocol` {
    struct Iterator: IteratorProtocol {
        var index: Int = 0
        let storage: Storage<Element>
        let count: Int

        init(_ container: borrowing Container<Element>) {
            self.storage = container.storage
            self.count = container.count
        }

        mutating func next() -> Element? {
            guard index < count else { return nil }
            let element = storage.read(at: index)
            index += 1
            return element
        }
    }

    borrowing func makeIterator() -> Iterator {
        Iterator(self)
    }

    // forEach using Sequence.Protocol's makeIterator
    func forEach(_ body: (Element) -> Void) {
        var iterator = makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

// MARK: - Algebra-style accessor using class storage reference

extension Container {
    struct Algebra {
        let _storage: Storage<Element>

        init(storage: Storage<Element>) {
            self._storage = storage
        }

        var _count: Int { _storage.count }

        func union(_ other: borrowing Container<Element>) -> Container<Element> {
            var result = Container<Element>()
            for i in 0..<_count {
                result.insert(_storage.read(at: i))
            }
            for i in 0..<other.count {
                result.insert(other.storage.read(at: i))
            }
            return result
        }
    }

    var algebra: Algebra {
        Algebra(storage: storage)
    }
}

// MARK: - Main

print("Testing Hash.Protocol + Sequence.Protocol for ~Copyable containers...")
print("")

// Create containers
var container = Container<Int>()
container.insert(1)
container.insert(2)
container.insert(3)
print("Container A: [1, 2, 3]")

var container2 = Container<Int>()
container2.insert(1)
container2.insert(2)
container2.insert(3)
print("Container B: [1, 2, 3]")

var container3 = Container<Int>()
container3.insert(4)
container3.insert(5)
print("Container C: [4, 5]")
print("")

// Test == operator from Hash.Protocol
print("Test 1: Hash.Protocol == operator")
if container == container2 {
    print("  ✓ A == B (both [1,2,3])")
}
if container != container3 {
    print("  ✓ A != C (different elements)")
}
print("")

// Test hashValue from Hash.Protocol
print("Test 2: Hash.Protocol hashValue")
let hashA = container.hashValue
let hashB = container2.hashValue
print("  hashValue of A: \(hashA)")
print("  hashValue of B: \(hashB)")
if hashA == hashB {
    print("  ✓ Equal containers have equal hash values")
}
print("")

// Test forEach from Sequence.Protocol
print("Test 3: Sequence.Protocol forEach")
print("  Container A elements:")
container.forEach { print("    - \($0)") }
print("")

// Test Algebra accessor
print("Test 4: Algebra accessor pattern (stores Storage, not Container)")
let union = container.algebra.union(container3)
print("  Union of A and C:")
union.forEach { print("    - \($0)") }
print("")

print("===")
print("EXPERIMENT CONFIRMED:")
print("")
print("1. Hash.Protocol from swift-hash-primitives WORKS with ~Copyable:")
print("   - Provides == and != operators")
print("   - Provides hashValue computed property")
print("   - Provides borrowing hash(into:) method")
print("")
print("2. Sequence.Protocol from swift-sequence-primitives WORKS with ~Copyable:")
print("   - Provides borrowing makeIterator() method")
print("   - Enables forEach() implementation")
print("   - Does NOT enable for-in syntax (requires Swift.Sequence)")
print("")
print("3. for-in loops are a LANGUAGE LIMITATION:")
print("   - Swift for-in requires Sequence conformance")
print("   - Sequence requires Copyable")
print("   - ~Copyable containers CANNOT use for-in syntax")
print("")
print("4. For Set.Ordered fix:")
print("   - Conform to Hash.Protocol (already imported via Hash_Primitives)")
print("   - Conform to Sequence.Protocol (need to add Sequence_Primitives)")
print("   - Change Algebra to store ElementStorage (class, Copyable) not Set.Ordered")
print("   - Remove Swift.Equatable, Swift.Hashable, Swift.Sequence conformances")
print("   - Update algebra operations to use forEach or index-based iteration")
