// MARK: - Value Generic Nested Type Bug
// Purpose: Nested types with value generics must be in body, not extension
// Status: CONFIRMED (2026-01-20, Swift 6.2)
// Revalidation: FIXED in Swift 6.2.4 — nested types in extensions work with value generics (2026-03-10)

// MARK: - Variant 1: Nested type in body (should work)
struct Outer1<let N: Int> {
    struct Inner {
        var capacity: Int { N }
    }

    var inner: Inner { Inner() }
}

// MARK: - Variant 2: Nested type in extension (may fail)
struct Outer2<let N: Int> {}

extension Outer2 {
    struct Inner {
        var capacity: Int { N }
    }

    var inner: Inner { Inner() }
}

// Test
let o1 = Outer1<4>()
print("Variant 1 (body): capacity = \(o1.inner.capacity)")

let o2 = Outer2<4>()
print("Variant 2 (extension): capacity = \(o2.inner.capacity)")

print("Value generic nested type test: BUILD SUCCEEDED")
