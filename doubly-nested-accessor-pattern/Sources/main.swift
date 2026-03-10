// MARK: - Doubly Nested Accessor Pattern
// Purpose: Two-level view nesting (.a.b.operation()) as a language capability
// Status: CONFIRMED (compiles)
// Date: 2026-01-21
// Toolchain: Swift 6.2
//
// Note: Production swift-primitives uses single-level view access
// (container.domain.operation()), not two-level nesting. This experiment
// validates the language supports deeper nesting if needed in the future.
//
// Production examples (single-level):
//   table.bucket.for(hash: hashValue)
//   table.remove.at(bucket: b)
//   value.compare.to(other)

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
        mutating _read { yield unsafe View(&self) }
    }
}

extension View where Tag == Database.QueryOps, Base == Database {
    // Second level: query.filter returns another view
    var filter: View<Database.FilterOps, Database> {
        View<Database.FilterOps, Database>(base)
    }

    func all() -> [String] {
        unsafe base.pointee.records
    }
}

extension View where Tag == Database.FilterOps, Base == Database {
    func startingWith(_ prefix: String) -> [String] {
        unsafe base.pointee.records.filter { $0.hasPrefix(prefix) }
    }

    func count() -> Int {
        unsafe base.pointee.records.count
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
