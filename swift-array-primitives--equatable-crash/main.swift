// Status: FIXED -- original compiler-crash hypothesis (synthesized Equatable for nested type with constraint extension on ~Copyable Outer) does NOT reproduce on Swift 6.3.1.
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Revalidated: Swift 6.3.1 (2026-04-30) -- FIXED. swift build (debug): clean compile (0.62s); swift build -c release: clean compile (0.55s); swift run output: "SUCCESS: Equatable and Hashable conformances work". (Phase 1b stale-triage 2026-04-30)
// ===----------------------------------------------------------------------===//
// Experiment: Equatable Conformance Crash in Nested Types
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: Synthesized Equatable conformance crashes the compiler when:
// - The type is nested inside `Outer<Element: ~Copyable>` with constraint `where Element == X`
// - The outer type has a nested Storage class
// - The nested type also conforms to RandomAccessCollection
//
// EXPECTED: Build should succeed
// ACTUAL: TBD
//
// RELATED: Array<Bit>.Packed crash with "ambiguous use of operator '=='"
// ===----------------------------------------------------------------------===//

// Minimal tag type (like Bit)
public struct Tag: Sendable, Equatable, Hashable {
    public var rawValue: Bool
    public init(_ value: Bool) { self.rawValue = value }
}

// Custom Index type (like Bit.Index)
extension Tag {
    public struct Index: Comparable, Sendable {
        public var position: Int

        public init(position: Int) {
            self.position = position
        }

        public static func < (lhs: Index, rhs: Index) -> Bool {
            lhs.position < rhs.position
        }
    }
}

// Outer container with ~Copyable context and nested Storage
public enum Container<Element: ~Copyable>: ~Copyable {

    // Nested storage at Container level (like Array.Storage)
    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> {
        @usableFromInline
        static func createEmpty() -> Storage {
            let storage = Storage.create(minimumCapacity: 0) { _ in 0 }
            return unsafeDowncast(storage, to: Storage.self)
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
}

// Constrained extension with nested type that wants Equatable
extension Container where Element == Tag {
    /// A type nested inside a constrained extension (like Array<Bit>.Packed)
    public struct Packed: Sendable {
        @usableFromInline
        var _storage: ContiguousArray<UInt>

        @usableFromInline
        var _count: Int

        public init() {
            self._storage = []
            self._count = 0
        }
    }
}

// Subscript access (like Array<Bit>.Packed)
extension Container<Tag>.Packed {
    public subscript(index: Tag.Index) -> Bool {
        get {
            precondition(index.position >= 0 && index.position < _count, "Index out of bounds")
            let wordIndex = index.position / UInt.bitWidth
            let bitIndex = index.position % UInt.bitWidth
            let mask: UInt = 1 << bitIndex
            return (_storage[wordIndex] & mask) != 0
        }
        set {
            precondition(index.position >= 0 && index.position < _count, "Index out of bounds")
            let wordIndex = index.position / UInt.bitWidth
            let bitIndex = index.position % UInt.bitWidth
            let mask: UInt = 1 << bitIndex
            if newValue {
                _storage[wordIndex] |= mask
            } else {
                _storage[wordIndex] &= ~mask
            }
        }
    }
}

// Sequence conformance
extension Container<Tag>.Packed: Sequence {
    public struct Iterator: IteratorProtocol, Sendable {
        let storage: ContiguousArray<UInt>
        let count: Int
        var index: Int

        init(storage: ContiguousArray<UInt>, count: Int) {
            self.storage = storage
            self.count = count
            self.index = 0
        }

        public mutating func next() -> Bool? {
            guard index < count else { return nil }
            let wordIndex = index / UInt.bitWidth
            let bitIndex = index % UInt.bitWidth
            let mask: UInt = 1 << bitIndex
            defer { index += 1 }
            return (storage[wordIndex] & mask) != 0
        }
    }

    public func makeIterator() -> Iterator {
        Iterator(storage: _storage, count: _count)
    }
}

// RandomAccessCollection conformance
extension Container<Tag>.Packed: RandomAccessCollection {
    public typealias Index = Tag.Index
    public typealias Element = Bool

    public var startIndex: Index { Tag.Index(position: 0) }
    public var endIndex: Index { Tag.Index(position: _count) }

    public func index(after i: Index) -> Index {
        Tag.Index(position: i.position + 1)
    }

    public func index(before i: Index) -> Index {
        Tag.Index(position: i.position - 1)
    }
}

// CRASH TRIGGER: Synthesized Equatable conformance
extension Container<Tag>.Packed: Equatable {}

// CRASH TRIGGER: Synthesized Hashable conformance
extension Container<Tag>.Packed: Hashable {}

print("SUCCESS: Equatable and Hashable conformances work")
