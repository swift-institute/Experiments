// ===----------------------------------------------------------------------===//
// Experiment: noncopyable-level1-investigation
// Date: 2026-01-22
// Status: IN PROGRESS
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL CRASHES
// ===----------------------------------------------------------------------===//
//
// QUESTION: What specific factor causes Hash.Table<Element> to fail in Set.Ordered?
//
// FINDING SO FAR: Same-file generic types with ~Copyable work at Level 1 and Level 2.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// ===----------------------------------------------------------------------===//

// MARK: - Simulated External Types

@usableFromInline
struct SimulatedTable<Element: ~Copyable>: ~Copyable {
    var _data: Int = 0
    @usableFromInline init() {}
}

extension SimulatedTable: Copyable where Element: Copyable {}

// MARK: - Protocol (like Hash.Protocol)

public protocol HashProtocol: ~Copyable {
    var hashValue: Int { get }
}

// MARK: - Container with compound constraint

public enum Container<Element: HashProtocol & ~Copyable>: ~Copyable {

    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> {
        @usableFromInline
        static func create(minimumCapacity: Int) -> Storage {
            let s = Storage.create(minimumCapacity: minimumCapacity) { _ in 0 }
            return unsafeDowncast(s, to: Storage.self)
        }

        deinit {
            let count = header
            guard count > 0 else { return }
            withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    (elements + i).deinitialize(count: 1)
                }
            }
        }
    }

    // Level 1: Ordered struct
    public struct Ordered: ~Copyable {

        @usableFromInline
        var _storage: Storage

        @usableFromInline
        var _cachedPtr: UnsafeMutablePointer<Element>

        @usableFromInline
        var _table: SimulatedTable<Element>

        @inlinable
        public init() {
            self._storage = Storage.create(minimumCapacity: 0)
            self._cachedPtr = self._storage.withUnsafeMutablePointerToElements { $0 }
            self._table = SimulatedTable()
        }

        // Level 2: Bounded struct
        public struct Bounded: ~Copyable {

            @usableFromInline
            var _storage: Storage

            @usableFromInline
            var _cachedPtr: UnsafeMutablePointer<Element>

            @usableFromInline
            var _table: SimulatedTable<Element>

            public let capacity: Int

            @inlinable
            public init(capacity: Int) {
                self._storage = Storage.create(minimumCapacity: capacity)
                self._cachedPtr = self._storage.withUnsafeMutablePointerToElements { $0 }
                self._table = SimulatedTable()
                self.capacity = capacity
            }
        }
    }
}

// MARK: - Conditional Copyable (same file per [COPY-FIX-004])

extension Container.Ordered: Copyable where Element: Copyable {}
extension Container.Ordered.Bounded: Copyable where Element: Copyable {}

// MARK: - Test Types

struct Token: ~Copyable, HashProtocol {
    let id: Int
    public var hashValue: Int { id }
}

public struct CopyableToken: HashProtocol {
    let id: Int
    public var hashValue: Int { id }
}

// MARK: - Test Execution

print("=== Test 1: Copyable Element ===")
var ordered = Container<CopyableToken>.Ordered()
print("Ordered created")

var bounded = Container<CopyableToken>.Ordered.Bounded(capacity: 4)
print("Bounded created")

print("\n=== Test 2: ~Copyable Element ===")
var ncOrdered = Container<Token>.Ordered()
print("~Copyable Ordered created")

var ncBounded = Container<Token>.Ordered.Bounded(capacity: 4)
print("~Copyable Bounded created")

print("\n=== All tests passed ===")
print("CONCLUSION: Level 1 and Level 2 nesting with compound constraint works")
print("            when all types are in the SAME FILE.")
