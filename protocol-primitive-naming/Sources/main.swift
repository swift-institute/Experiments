// MARK: - Protocol Primitive Naming
// Purpose: Semantic naming for protocol primitives
// Status: ANALYSIS
// Date: 2026-01-21
// Toolchain: Swift 6.0

// Analysis: How should protocol primitives be named?
//
// Option A: Adjective form (Swift convention)
//   - Hashable, Equatable, Comparable, Sendable
//   - Pro: Follows Swift stdlib convention
//   - Con: Can't always find a natural adjective
//
// Option B: Noun.Protocol form (Nest.Name convention)
//   - Hash.Protocol, Comparison.Protocol, Index.Protocol
//   - Pro: Follows [API-NAME-001] namespace structure
//   - Con: Departs from stdlib convention
//   - Note: Swift doesn't support nested protocol declarations,
//     so we use the enum-namespace pattern with a top-level protocol.
//
// Option C: Capability form
//   - Hash.Capable, Comparison.Capable
//   - Pro: Clear meaning
//   - Con: Verbose

// In swift-primitives, we use Option B for domain-specific protocols.
// Since Swift doesn't allow `enum Foo { protocol Bar {} }`, the
// actual pattern is: top-level protocol + enum namespace for discovery.

// Pattern: Protocol defined at top level, enum provides namespace grouping
protocol HashProtocol: ~Copyable {
    var hashValue: Int { get }
}

// Namespace enum provides discovery and documentation grouping
enum Hash {
    // In real code, typealias maps to the top-level protocol:
    // typealias Protocol = HashProtocol
    // (Cannot use `Protocol` as a typealias name — reserved keyword.
    //  In practice, use the full name or `Protocol_` suffix.)
}

// Usage
struct Key: HashProtocol {
    var name: String
    var hashValue: Int { name.hashValue }
}

// Simulated Comparison.Protocol pattern
protocol ComparisonProtocol: ~Copyable {
    static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
}

enum Comparison {
    // typealias Protocol = ComparisonProtocol
}

struct Score: ComparisonProtocol {
    var value: Int
    static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        lhs.value < rhs.value
    }
}

// ~Copyable type conforming to domain protocol
struct UniqueToken: ~Copyable, ComparisonProtocol {
    var id: Int
    static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        lhs.id < rhs.id
    }
}

let k = Key(name: "test")
print("Hash: \(k.hashValue)")

let s1 = Score(value: 10)
let s2 = Score(value: 20)
print("isLessThan: \(Score.isLessThan(s1, s2))")
assert(Score.isLessThan(s1, s2))

let t1 = UniqueToken(id: 3)
let t2 = UniqueToken(id: 7)
print("UniqueToken isLessThan: \(UniqueToken.isLessThan(t1, t2))")
assert(UniqueToken.isLessThan(t1, t2))

print("protocol-primitive-naming: ANALYSIS")
print("Decision: Use Noun.Protocol for domain protocols, adjective for capabilities")
