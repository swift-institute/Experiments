// Status: SUPERSEDED -- Sequence.Protocol -> Collection.Protocol inheritance with .forEach shadowing shipped in collection-primitives. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// EXPERIMENT: Protocol Inheritance Shadowing
//
// Validates that:
// 1. A Collection.Protocol conformer inherits Sequence.Protocol default properties
// 2. A more-specific Collection.Protocol extension can shadow Sequence.Protocol's
// 3. The compiler resolves to the correct (more specific) overload
//
// This models the real scenario where collection-primitives wants to:
// - Inherit .contains, .map, .first, etc. from sequence-primitives defaults
// - Shadow .forEach with an index-based implementation

// MARK: - Minimal Property.View infrastructure

struct PropertyView<Tag, Base: ~Copyable>: ~Copyable, ~Escapable {
    let base: UnsafeMutablePointer<Base>

    @_lifetime(borrow base)
    init(_ base: UnsafeMutablePointer<Base>) {
        self.base = base
    }
}

// MARK: - Tag types

// Sequence-level tags (would live in sequence-primitives)
enum SeqForEach {}
enum SeqContains {}
enum SeqMap {}

// Collection-level tag — only for operations that genuinely differ
enum ColForEach {}

// MARK: - Protocols

protocol SequenceProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: IteratorProtocol where Iterator.Element == Element
    borrowing func makeIterator() -> Iterator
}

protocol CollectionProtocol: SequenceProtocol & ~Copyable {
    var startIndex: Int { get }
    var endIndex: Int { get }
    subscript(position: Int) -> Element { get }
    func index(after i: Int) -> Int
}

// MARK: - Sequence default accessor properties

extension SequenceProtocol where Self: ~Copyable {

    // .forEach — sequence-level default (iterator-based)
    var forEach: PropertyView<SeqForEach, Self> {
        mutating _read {
            yield unsafe PropertyView<SeqForEach, Self>(&self)
        }
    }

    // .contains — sequence-level default (iterator-based)
    var contains: PropertyView<SeqContains, Self> {
        mutating _read {
            yield unsafe PropertyView<SeqContains, Self>(&self)
        }
    }

    // .map — sequence-level default (iterator-based)
    var map: PropertyView<SeqMap, Self> {
        mutating _read {
            yield unsafe PropertyView<SeqMap, Self>(&self)
        }
    }
}

// MARK: - Sequence Property.View implementations

extension PropertyView where Base: SequenceProtocol & ~Copyable, Tag == SeqForEach {
    func callAsFunction(_ body: (borrowing Base.Element) -> Void) {
        print("  → Sequence.ForEach (iterator-based)")
        var iterator = unsafe base.pointee.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

extension PropertyView where Base: SequenceProtocol & ~Copyable, Tag == SeqContains {
    func callAsFunction(_ predicate: (borrowing Base.Element) -> Bool) -> Bool {
        print("  → Sequence.Contains (iterator-based)")
        var iterator = unsafe base.pointee.makeIterator()
        while let element = iterator.next() {
            if predicate(element) { return true }
        }
        return false
    }
}

extension PropertyView where Base: SequenceProtocol & ~Copyable, Tag == SeqMap {
    func callAsFunction<U>(_ transform: (borrowing Base.Element) -> U) -> [U] {
        print("  → Sequence.Map (iterator-based)")
        var result: [U] = []
        var iterator = unsafe base.pointee.makeIterator()
        while let element = iterator.next() {
            result.append(transform(element))
        }
        return result
    }
}

// MARK: - Collection shadows .forEach with index-based implementation

extension CollectionProtocol where Self: ~Copyable {

    // Shadows SequenceProtocol's .forEach — more specific protocol wins
    var forEach: PropertyView<ColForEach, Self> {
        mutating _read {
            yield unsafe PropertyView<ColForEach, Self>(&self)
        }
    }

    // NOTE: .contains and .map are NOT shadowed — inherited from Sequence
}

extension PropertyView where Base: CollectionProtocol & ~Copyable, Tag == ColForEach {
    func callAsFunction(_ body: (borrowing Base.Element) -> Void) {
        print("  → Collection.ForEach (INDEX-based)")
        var index = unsafe base.pointee.startIndex
        let endIndex = unsafe base.pointee.endIndex
        while index < endIndex {
            body(unsafe base.pointee[index])
            index = unsafe base.pointee.index(after: index)
        }
    }
}

// MARK: - Test types

struct MySequence: SequenceProtocol {
    var storage: [Int]
    func makeIterator() -> Array<Int>.Iterator { storage.makeIterator() }
}

struct MyCollection: CollectionProtocol {
    var storage: [Int]
    func makeIterator() -> Array<Int>.Iterator { storage.makeIterator() }
    var startIndex: Int { storage.startIndex }
    var endIndex: Int { storage.endIndex }
    subscript(position: Int) -> Int { storage[position] }
    func index(after i: Int) -> Int { storage.index(after: i) }
}

// MARK: - Tests

print("=== Test 1: Sequence conformer gets sequence defaults ===")
var seq = MySequence(storage: [10, 20, 30])

print("seq.forEach:")
seq.forEach { _ in }
// Expected: → Sequence.ForEach (iterator-based)

print("seq.contains:")
let _ = seq.contains { $0 == 20 }
// Expected: → Sequence.Contains (iterator-based)

print("seq.map:")
let _ = seq.map { $0 * 2 }
// Expected: → Sequence.Map (iterator-based)

print()
print("=== Test 2: Collection conformer — forEach is SHADOWED, others INHERITED ===")
var col = MyCollection(storage: [10, 20, 30])

print("col.forEach:")
col.forEach { _ in }
// Expected: → Collection.ForEach (INDEX-based)  ← SHADOWED

print("col.contains:")
let _ = col.contains { $0 == 20 }
// Expected: → Sequence.Contains (iterator-based)  ← INHERITED

print("col.map:")
let _ = col.map { $0 * 2 }
// Expected: → Sequence.Map (iterator-based)  ← INHERITED

print()
print("=== Test 3: Verify correct results ===")
var col2 = MyCollection(storage: [1, 2, 3, 4, 5])

let hasThree = col2.contains { $0 == 3 }
print("contains 3: \(hasThree)")  // true

let doubled = col2.map { $0 * 2 }
print("map *2: \(doubled)")  // [2, 4, 6, 8, 10]

var sum = 0
col2.forEach { sum += $0 }
print("forEach sum: \(sum)")  // 15

print()
print("=== All tests passed ===")
