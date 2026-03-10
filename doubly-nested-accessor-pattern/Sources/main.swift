// MARK: - Doubly Nested Accessor Pattern
// Purpose: Doubly nested accessor patterns (.a.b.property)
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2

// Two levels of view nesting: container.outer.inner.operation()

struct View<Tag, Base> {
    let base: UnsafeMutablePointer<Base>
    init(_ base: UnsafeMutablePointer<Base>) {
        self.base = base
    }
}

struct Database {
    enum QueryOps {}
    enum FilterOps {}

    var records: [String] = ["alice", "bob", "charlie"]

    var query: View<QueryOps, Database> {
        mutating _read { yield View(&self) }
    }
}

extension View where Tag == Database.QueryOps, Base == Database {
    // Second level: query.filter returns another view
    var filter: View<Database.FilterOps, Database> {
        View<Database.FilterOps, Database>(base)
    }

    func all() -> [String] {
        base.pointee.records
    }
}

extension View where Tag == Database.FilterOps, Base == Database {
    func startingWith(_ prefix: String) -> [String] {
        base.pointee.records.filter { $0.hasPrefix(prefix) }
    }

    func count() -> Int {
        base.pointee.records.count
    }
}

var db = Database()
let all = db.query.all()
let filtered = db.query.filter.startingWith("c")
let count = db.query.filter.count()

print("all: \(all)")
print("filtered: \(filtered)")
print("count: \(count)")
assert(all == ["alice", "bob", "charlie"])
assert(filtered == ["charlie"])
assert(count == 3)
print("doubly-nested-accessor-pattern: CONFIRMED")
