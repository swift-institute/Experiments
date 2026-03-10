// MARK: - Fluent API Pattern
// Purpose: Fluent API patterns with Property.View
// Status: CONFIRMED
// Date: 2026-01-22
// Toolchain: Swift 6.2

// Property.View enables fluent namespaced API: container.domain.operation()

struct View<Tag, Base> {
    let base: UnsafeMutablePointer<Base>
    init(_ base: UnsafeMutablePointer<Base>) {
        self.base = base
    }
}

struct Collection {
    enum SearchOps {}
    enum SortOps {}

    var elements: [Int] = [3, 1, 4, 1, 5]

    var search: View<SearchOps, Collection> {
        mutating _read { yield View(&self) }
    }

    var sort: View<SortOps, Collection> {
        mutating _read { yield View(&self) }
    }
}

extension View where Tag == Collection.SearchOps, Base == Collection {
    func contains(_ value: Int) -> Bool {
        base.pointee.elements.contains(value)
    }

    func index(of value: Int) -> Int? {
        base.pointee.elements.firstIndex(of: value)
    }
}

extension View where Tag == Collection.SortOps, Base == Collection {
    func ascending() -> [Int] {
        base.pointee.elements.sorted()
    }

    func descending() -> [Int] {
        base.pointee.elements.sorted(by: >)
    }
}

var coll = Collection()
let found = coll.search.contains(4)
let idx = coll.search.index(of: 5)
let asc = coll.sort.ascending()
let desc = coll.sort.descending()

print("contains(4): \(found)")
print("index(of: 5): \(idx!)")
print("ascending: \(asc)")
print("descending: \(desc)")
assert(found == true)
assert(idx == 4)
assert(asc == [1, 1, 3, 4, 5])
assert(desc == [5, 4, 3, 1, 1])
print("fluent-api-pattern: CONFIRMED")
