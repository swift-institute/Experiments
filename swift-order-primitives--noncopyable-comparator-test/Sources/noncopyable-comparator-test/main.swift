// EXPERIMENT: noncopyable-comparator-test
// DATE: 2026-01-22
// HYPOTHESIS: Closures can work with ~Copyable types via borrowing parameters
// STATUS: CONFIRMED
// METHODOLOGY: Incremental Construction [EXP-004a]
//
// FINDINGS:
// 1. Struct<T: ~Copyable> works with @Sendable (borrowing T, borrowing T) -> R closures
// 2. Extensions MUST use `where T: ~Copyable` to work with non-copyable types
// 3. Key extraction, chaining, and reversal all work with ~Copyable types
// 4. Copyable types also work with the same API (no separate overloads needed)

enum ComparisonResult: Sendable {
    case less
    case equal
    case greater
}

// =============================================================================
// VARIANT 1: Closure with borrowing parameters
// =============================================================================

struct Comparator1<T: ~Copyable>: Sendable {
    let compare: @Sendable (borrowing T, borrowing T) -> ComparisonResult

    init(_ compare: @escaping @Sendable (borrowing T, borrowing T) -> ComparisonResult) {
        self.compare = compare
    }

    func callAsFunction(_ lhs: borrowing T, _ rhs: borrowing T) -> ComparisonResult {
        compare(lhs, rhs)
    }
}

struct Token: ~Copyable {
    let id: Int
}

let comparator1 = Comparator1<Token> { lhs, rhs in
    if lhs.id < rhs.id {
        return .less
    } else if lhs.id > rhs.id {
        return .greater
    } else {
        return .equal
    }
}

let a = Token(id: 1)
let b = Token(id: 2)
print("V1 - Comparator with borrowing closure: \(comparator1(a, b))")

// =============================================================================
// VARIANT 2: Copyable type with same comparator
// =============================================================================

let intComparator = Comparator1<Int> { lhs, rhs in
    if lhs < rhs {
        return .less
    } else if lhs > rhs {
        return .greater
    } else {
        return .equal
    }
}

print("V2 - Int comparator: \(intComparator(5, 10))")

// =============================================================================
// VARIANT 3: Key extraction with ~Copyable
// =============================================================================

extension Comparator1 where T: ~Copyable {
    static func by<Value: ~Copyable>(
        _ selector: @escaping @Sendable (borrowing T) -> Value,
        using comparator: Comparator1<Value>
    ) -> Comparator1<T> {
        Comparator1 { lhs, rhs in
            comparator(selector(lhs), selector(rhs))
        }
    }
}

struct Person: ~Copyable {
    let name: String
    let age: Int
}

// This tests key extraction
let byAgeComparator = Comparator1<Person>.by(
    { $0.age },
    using: intComparator
)

let alice = Person(name: "Alice", age: 30)
let bob = Person(name: "Bob", age: 25)
print("V3 - Key extraction: \(byAgeComparator(alice, bob))")

// =============================================================================
// VARIANT 4: Chaining comparators
// =============================================================================

extension Comparator1 where T: ~Copyable {
    func then(_ other: Comparator1<T>) -> Comparator1<T> {
        Comparator1 { lhs, rhs in
            let first = self.compare(lhs, rhs)
            switch first {
            case .equal:
                return other.compare(lhs, rhs)
            case .less, .greater:
                return first
            }
        }
    }
}

let stringComparator = Comparator1<String> { lhs, rhs in
    if lhs < rhs {
        return .less
    } else if lhs > rhs {
        return .greater
    } else {
        return .equal
    }
}

let byNameComparator = Comparator1<Person>.by(
    { $0.name },
    using: stringComparator
)

let combinedComparator = byAgeComparator.then(byNameComparator)
let charlie = Person(name: "Charlie", age: 30)
print("V4 - Chained comparator (alice vs charlie, same age): \(combinedComparator(alice, charlie))")

// =============================================================================
// VARIANT 5: Reversed comparator
// =============================================================================

extension Comparator1 where T: ~Copyable {
    var reversed: Comparator1<T> {
        Comparator1 { lhs, rhs in
            switch self.compare(lhs, rhs) {
            case .less: return .greater
            case .equal: return .equal
            case .greater: return .less
            }
        }
    }
}

let descendingAge = byAgeComparator.reversed
print("V5 - Reversed comparator: \(descendingAge(alice, bob))")

print("\n✅ All variants passed!")
