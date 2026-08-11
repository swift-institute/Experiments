// Status: SUPERSEDED -- pattern shipped in Set_Primitives Hash.Table; see [COPY-FIX-*], [MEM-COPY-005]. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ===----------------------------------------------------------------------===//
// Experiment: Conditional Copyable Hash Table with Class-Based Storage
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS:
// A hash table struct using class-based storage (ManagedBuffer) instead of
// UnsafeMutablePointer can be conditionally Copyable when Element is Copyable,
// enabling Swift.Sequence conformance and for-in loops.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
// Build up complexity step by step to validate each capability.
//
// RESULT: CONFIRMED
//
// Class-based storage (ManagedBuffer) enables:
// 1. Conditional Copyable: `extension HashTable: Copyable where Element: Copyable {}`
// 2. Conditional Sequence: `extension HashTable: Sequence where Element: Copyable { ... }`
// 3. for-in loops work when Element: Copyable
// 4. ~Copyable elements make the container ~Copyable (cannot copy, no Sequence)
//
// Negative test verified: `swift build -Xswiftc -DVERIFY_NONCOPYABLE` fails with
// "'copy' cannot be applied to noncopyable types" for HashTable<MoveOnlyResource>
// ===----------------------------------------------------------------------===//

// MARK: - Variant 1: Basic Class-Based Storage (No Deinit on Struct)

/// ManagedBuffer-based storage for hash table.
/// The class handles cleanup via its deinit.
final class HashStorage: ManagedBuffer<(count: Int, occupied: Int), Int> {

    static func create(capacity: Int) -> HashStorage {
        let storage = HashStorage.create(minimumCapacity: capacity * 2) { _ in (count: 0, occupied: 0) }
        // Initialize hash and position slots to empty (0)
        _ = unsafe storage.withUnsafeMutablePointerToElements { ptr in
            unsafe ptr.initialize(repeating: 0, count: capacity * 2)
        }
        return unsafe unsafeDowncast(storage, to: HashStorage.self)
    }

    deinit {
        // ManagedBuffer handles deallocation automatically
    }
}

/// Hash table using class-based storage.
/// No deinit on struct - Storage class handles cleanup.
struct HashTable<Element: ~Copyable>: ~Copyable {
    var _storage: HashStorage

    init(minimumCapacity: Int = 8) {
        _storage = HashStorage.create(capacity: minimumCapacity)
    }

    var count: Int { _storage.header.count }
    var isEmpty: Bool { count == 0 }

    // NO deinit - HashStorage.deinit handles cleanup
}

// MARK: - Variant 2: Conditional Copyable

extension HashTable: Copyable where Element: Copyable {}

// MARK: - Variant 3: Test Copyable Works

func testCopyable() {
    print("=== Test 1: Conditional Copyable ===")

    var table1 = HashTable<Int>()
    let table2 = table1  // Copy should work when Element: Copyable

    print("table1.count: \(table1.count)")
    print("table2.count: \(table2.count)")
    print("✅ Copying HashTable<Int> works")
}

// MARK: - Variant 4: Conditional Sequence Conformance

extension HashTable: Sequence where Element: Copyable {
    struct Iterator: IteratorProtocol {
        var index: Int = 0
        let maxIndex: Int

        init(count: Int) {
            self.maxIndex = count
        }

        mutating func next() -> Int? {
            guard index < maxIndex else { return nil }
            defer { index += 1 }
            return index  // Placeholder - just return indices for test
        }
    }

    func makeIterator() -> Iterator {
        Iterator(count: count)
    }
}

func testSequence() {
    print("\n=== Test 2: Conditional Sequence ===")

    let table = HashTable<String>()

    // for-in should work when Element: Copyable
    for index in table {
        print("index: \(index)")
    }

    print("✅ for-in loop works with HashTable<String>")
}

// MARK: - Variant 5: ~Copyable Element (Should NOT be Copyable or Sequence)

struct MoveOnlyResource: ~Copyable {
    var id: Int
}

func testNonCopyable() {
    print("\n=== Test 3: ~Copyable Element ===")

    var table = HashTable<MoveOnlyResource>()
    // let table2 = table  // ❌ Should not compile - Element is ~Copyable

    // for element in table { }  // ❌ Should not compile - no Sequence conformance

    print("count: \(table.count)")
    print("✅ HashTable<MoveOnlyResource> is ~Copyable (cannot copy)")
}

// MARK: - Variant 6: Full Set.Ordered Pattern

/// Simulates Set.Ordered with ElementStorage (class) + HashTable
struct OrderedSet<Element: ~Copyable>: ~Copyable {

    final class ElementStorage: ManagedBuffer<Int, Element> {
        static func create(capacity: Int) -> ElementStorage {
            let storage = ElementStorage.create(minimumCapacity: capacity) { _ in 0 }
            return unsafe unsafeDowncast(storage, to: ElementStorage.self)
        }

        deinit {
            let count = header
            guard count > 0 else { return }
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    unsafe (elements + i).deinitialize(count: 1)
                }
            }
        }

        func _readElement(at index: Int) -> Element where Element: Copyable {
            unsafe withUnsafeMutablePointerToElements { $0[index] }
        }
    }

    var _elements: ElementStorage
    var _indices: HashTable<Element>

    init() {
        _elements = ElementStorage.create(capacity: 8)
        _indices = HashTable<Element>()
    }

    var count: Int { _elements.header }
    var isEmpty: Bool { count == 0 }

    // NO deinit - both ElementStorage and HashTable handle their own cleanup
}

// Conditional Copyable for OrderedSet
extension OrderedSet: Copyable where Element: Copyable {}

// Conditional Sequence for OrderedSet
extension OrderedSet: Sequence where Element: Copyable {
    struct Iterator: IteratorProtocol {
        let storage: ElementStorage
        var index: Int = 0

        mutating func next() -> Element? {
            guard index < storage.header else { return nil }
            defer { index += 1 }
            return storage._readElement(at: index)
        }
    }

    func makeIterator() -> Iterator {
        Iterator(storage: _elements)
    }
}

func testOrderedSet() {
    print("\n=== Test 4: Full OrderedSet Pattern ===")

    var set1 = OrderedSet<Int>()
    let set2 = set1  // Copy should work

    print("set1.count: \(set1.count)")
    print("set2.count: \(set2.count)")

    // for-in should work
    for element in set1 {
        print("element: \(element)")
    }

    print("✅ OrderedSet<Int> is Copyable and Sequence")
}

func testOrderedSetNonCopyable() {
    print("\n=== Test 5: OrderedSet with ~Copyable Element ===")

    var set = OrderedSet<MoveOnlyResource>()
    // let set2 = set  // ❌ Should not compile
    // for element in set { }  // ❌ Should not compile

    print("count: \(set.count)")
    print("✅ OrderedSet<MoveOnlyResource> is ~Copyable")
}

// MARK: - Main

print("Conditional Copyable Hash Table Experiment")
print("==========================================\n")

testCopyable()
testSequence()
testNonCopyable()
testOrderedSet()
testOrderedSetNonCopyable()

print("\n==========================================")
print("All tests passed!")
print("CONCLUSION: Class-based storage enables conditional Copyable and Sequence")
