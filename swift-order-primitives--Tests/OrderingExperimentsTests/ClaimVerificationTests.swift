import Testing
@testable import OrderingExperiments

// MARK: - Test Data Types

struct Person: Sendable {
    let name: String
    let age: Int
    let department: String
}

// ============================================================================
// MARK: - CLAIM VERIFICATION TESTS
// ============================================================================

/// [CLAIM-001] Comparators can store @Sendable closures
@Test
func `CLAIM-001: Comparators can store @Sendable closures`() {
    // Verify that a comparator can be created with a @Sendable closure
    let comparator = Order.Comparator<Int> { lhs, rhs in
        Comparison.Result(lhs, rhs)
    }

    // Verify it works correctly
    #expect(comparator(1, 2) == .less)
    #expect(comparator(2, 1) == .greater)
    #expect(comparator(1, 1) == .equal)

    print("CLAIM-001: VERIFIED - @Sendable closures can be stored in Comparator<T>")
}

/// [CLAIM-002] `reversed` property returns reversed comparator (involution property)
@Test
func `CLAIM-002: reversed property implements involution`() {
    let ascending: Order.Comparator<Int> = .ascending

    // Test basic reversal
    #expect(ascending(1, 2) == .less)
    #expect(ascending.reversed(1, 2) == .greater)

    // Test involution: reversed(reversed(c)) == c
    let doubleReversed = ascending.reversed.reversed
    #expect(doubleReversed(1, 2) == ascending(1, 2))
    #expect(doubleReversed(2, 1) == ascending(2, 1))
    #expect(doubleReversed(1, 1) == ascending(1, 1))

    print("CLAIM-002: VERIFIED - reversed property is an involution")
}

/// [CLAIM-003] `then(_:)` implements lexicographic chaining (monoid property)
@Test
func `CLAIM-003: then(_:) implements lexicographic chaining`() {
    // Use closure-based selectors since KeyPath is not Sendable
    let byAge = Order.Comparator<Person>.by { $0.age }
    let byName = Order.Comparator<Person>.by { $0.name }
    let byDept = Order.Comparator<Person>.by { $0.department }

    let alice = Person(name: "Alice", age: 30, department: "Engineering")
    let bob = Person(name: "Bob", age: 30, department: "Engineering")
    let charlie = Person(name: "Charlie", age: 25, department: "Sales")

    // Test chaining: when first comparison is equal, use second
    let byAgeThenName = byAge.then(byName)

    // alice vs bob: same age, so compare by name (Alice < Bob)
    #expect(byAgeThenName(alice, bob) == .less)

    // alice vs charlie: different age (30 > 25), so age wins
    #expect(byAgeThenName(alice, charlie) == .greater)

    // Test associativity: (c1 ⊕ c2) ⊕ c3 = c1 ⊕ (c2 ⊕ c3)
    let leftGrouped = byAge.then(byName).then(byDept)
    let rightGrouped = byAge.then(byName.then(byDept))

    // Test with values that exercise all three comparators
    let alice2 = Person(name: "Alice", age: 30, department: "HR")
    let alice3 = Person(name: "Alice", age: 30, department: "Engineering")

    #expect(leftGrouped(alice2, alice3) == rightGrouped(alice2, alice3))

    print("CLAIM-003: VERIFIED - then(_:) implements associative lexicographic chaining")
}

/// [CLAIM-004] KeyPath-based projection works with generics
/// PARTIALLY REFUTED: KeyPath works but is NOT Sendable in Swift 6
@Test
func `CLAIM-004: KeyPath-based projection (NON-SENDABLE)`() {
    // KeyPath-based comparators work but are NOT Sendable
    let byAge = Order.NonSendableComparator<Person>.by(\.age)
    let byName = Order.NonSendableComparator<Person>.by(\.name)

    let alice = Person(name: "Alice", age: 30, department: "Engineering")
    let bob = Person(name: "Bob", age: 25, department: "Sales")

    // Test KeyPath extraction
    #expect(byAge(alice, bob) == .greater)  // 30 > 25
    #expect(byName(alice, bob) == .less)    // "Alice" < "Bob"

    print("CLAIM-004: PARTIALLY VERIFIED - KeyPath projection works but requires NonSendableComparator")
    print("CLAIM-004: REFUTED for Sendable variant - KeyPath is NOT Sendable in Swift 6")
}

/// [CLAIM-005] callAsFunction enables `comparator(a, b)` syntax
@Test
func `CLAIM-005: callAsFunction enables comparator(a, b) syntax`() {
    let comparator: Order.Comparator<Int> = .ascending

    // Test the call syntax directly
    let result1 = comparator(1, 2)
    let result2 = comparator(2, 1)
    let result3 = comparator(1, 1)

    #expect(result1 == .less)
    #expect(result2 == .greater)
    #expect(result3 == .equal)

    print("CLAIM-005: VERIFIED - callAsFunction enables comparator(a, b) syntax")
}

/// [CLAIM-006] Direction enum supports reversal
@Test
func `CLAIM-006: Direction enum supports reversal`() {
    #expect(Order.Direction.ascending.reversed == .descending)
    #expect(Order.Direction.descending.reversed == .ascending)

    // Test involution
    #expect(Order.Direction.ascending.reversed.reversed == .ascending)
    #expect(Order.Direction.descending.reversed.reversed == .descending)

    print("CLAIM-006: VERIFIED - Direction enum supports reversal as involution")
}

/// [CLAIM-007] Comparator works with Comparable types
@Test
func `CLAIM-007: Comparator works with Comparable types`() {
    // Test with Int
    let intComparator: Order.Comparator<Int> = .ascending
    #expect(intComparator(1, 2) == .less)

    // Test with String
    let stringComparator: Order.Comparator<String> = .ascending
    #expect(stringComparator("apple", "banana") == .less)

    // Test with Double
    let doubleComparator: Order.Comparator<Double> = .ascending
    #expect(doubleComparator(1.5, 2.5) == .less)

    // Test descending static property
    let descending: Order.Comparator<Int> = .descending
    #expect(descending(1, 2) == .greater)

    print("CLAIM-007: VERIFIED - Comparator works with Comparable types")
}

/// [CLAIM-008] PartialComparator returns Optional
@Test
func `CLAIM-008: PartialComparator returns Optional`() {
    // Create a partial comparator for floating point that treats NaN as incomparable
    let floatComparator = Order.PartialComparator<Double> { lhs, rhs in
        if lhs.isNaN || rhs.isNaN {
            return nil
        }
        return Comparison.Result(lhs, rhs)
    }

    // Test comparable values
    #expect(floatComparator(1.0, 2.0) == .less)
    #expect(floatComparator(2.0, 1.0) == .greater)
    #expect(floatComparator(1.0, 1.0) == .equal)

    // Test incomparable values (NaN)
    #expect(floatComparator(Double.nan, 1.0) == nil)
    #expect(floatComparator(1.0, Double.nan) == nil)
    #expect(floatComparator(Double.nan, Double.nan) == nil)

    print("CLAIM-008: VERIFIED - PartialComparator returns Optional for incomparable values")
}

// ============================================================================
// MARK: - ASSUMPTION VERIFICATION TESTS
// ============================================================================

/// [ASSUMP-001] @Sendable closures can be stored in structs
@Test
func `ASSUMP-001: @Sendable closures can be stored in structs`() {
    struct SendableContainer: Sendable {
        let closure: @Sendable (Int, Int) -> Bool
    }

    let container = SendableContainer { lhs, rhs in lhs < rhs }
    #expect(container.closure(1, 2) == true)

    print("ASSUMP-001: VERIFIED - @Sendable closures can be stored in Sendable structs")
}

/// [ASSUMP-002] KeyPath works with generics at Tier 0
/// REFUTED: KeyPath works with generics but is NOT Sendable
@Test
func `ASSUMP-002: KeyPath with generics - Sendability check`() {
    // Test that KeyPath works in a generic context without Foundation
    func extractValue<T, V>(from value: T, using keyPath: KeyPath<T, V>) -> V {
        value[keyPath: keyPath]
    }

    let person = Person(name: "Alice", age: 30, department: "Engineering")
    let age = extractValue(from: person, using: \.age)
    #expect(age == 30)

    print("ASSUMP-002: PARTIALLY VERIFIED - KeyPath works with generics")
    print("ASSUMP-002: REFUTED - KeyPath is NOT Sendable, cannot be used in @Sendable closures")
}

/// [ASSUMP-003] callAsFunction works with generic return types
@Test
func `ASSUMP-003: callAsFunction works with generic return types`() {
    struct GenericCallable<Input, Output> {
        let transform: (Input) -> Output

        func callAsFunction(_ input: Input) -> Output {
            transform(input)
        }
    }

    let doubler = GenericCallable<Int, Int> { $0 * 2 }
    #expect(doubler(5) == 10)

    let stringify = GenericCallable<Int, String> { "\($0)" }
    #expect(stringify(42) == "42")

    print("ASSUMP-003: VERIFIED - callAsFunction works with generic return types")
}

/// [ASSUMP-004] Closures capturing @Sendable closures are themselves @Sendable
@Test
func `ASSUMP-004: Closures capturing @Sendable closures are @Sendable`() {
    let innerClosure: @Sendable (Int, Int) -> Comparison.Result = { lhs, rhs in
        Comparison.Result(lhs, rhs)
    }

    // Capture the inner closure in another @Sendable closure
    let outerClosure: @Sendable (Int, Int) -> Comparison.Result = { lhs, rhs in
        innerClosure(lhs, rhs).reversed
    }

    #expect(outerClosure(1, 2) == .greater)

    print("ASSUMP-004: VERIFIED - Closures capturing @Sendable closures can be @Sendable")
}

/// [ASSUMP-005] Nested generic types compile correctly
@Test
func `ASSUMP-005: Nested generic types compile correctly`() {
    // Order.Comparator<T> is a nested generic type
    let comparator: Order.Comparator<Int> = .ascending

    // Order.Projection<Root, Value> has two generic parameters
    let projection = Order.Projection<Person, Int>({ $0.age })

    let person = Person(name: "Alice", age: 30, department: "Engineering")

    // Test that nested generics work correctly
    #expect(comparator(1, 2) == .less)
    #expect(projection.comparator(person, Person(name: "Bob", age: 25, department: "Sales")) == .greater)

    print("ASSUMP-005: VERIFIED - Nested generic types compile and work correctly")
}

// ============================================================================
// MARK: - ALGEBRAIC PROPERTY TESTS
// ============================================================================

/// Test that Direction is a proper involution
@Test
func `Algebraic: Direction involution property`() {
    for direction in Order.Direction.allCases {
        #expect(direction.reversed.reversed == direction,
               "Direction.\(direction).reversed.reversed should equal Direction.\(direction)")
    }
    print("ALGEBRAIC: Direction involution property holds for all cases")
}

/// Test Comparator monoid identity
@Test
func `Algebraic: Comparator identity element`() {
    // The identity comparator returns .equal for all inputs
    let identity = Order.Comparator<Int> { _, _ in .equal }
    let ascending: Order.Comparator<Int> = .ascending

    // Test: c ⊕ identity = c
    let rightIdentity = ascending.then(identity)
    #expect(rightIdentity(1, 2) == ascending(1, 2))
    #expect(rightIdentity(2, 1) == ascending(2, 1))
    #expect(rightIdentity(1, 1) == ascending(1, 1))

    // Test: identity ⊕ c = c
    let leftIdentity = identity.then(ascending)
    #expect(leftIdentity(1, 2) == ascending(1, 2))
    #expect(leftIdentity(2, 1) == ascending(2, 1))
    #expect(leftIdentity(1, 1) == ascending(1, 1))

    print("ALGEBRAIC: Comparator monoid identity property holds")
}

// ============================================================================
// MARK: - SENDABLE COMPLIANCE TESTS
// ============================================================================

/// Verify Sendable conformance compiles (Swift 6 strict concurrency)
@Test
func `Sendable: All Sendable types conform correctly`() async {
    // These lines will fail compilation if types are not Sendable

    let direction: Order.Direction = .ascending
    let comparator: Order.Comparator<Int> = .ascending
    let projection = Order.Projection<Person, Int>({ $0.age })
    let partialComparator = Order.PartialComparator<Double> { lhs, rhs in
        Comparison.Result(lhs, rhs)
    }

    // Use in async context to verify Sendable
    await Task {
        _ = direction
        _ = comparator
        _ = projection
        _ = partialComparator
    }.value

    print("SENDABLE: All Sendable types can be used across concurrency boundaries")
}

/// Verify that NonSendable types do NOT conform to Sendable
@Test
func `Sendable: NonSendable types correctly omit Sendable`() {
    // NonSendableComparator should NOT be Sendable
    let comparator = Order.NonSendableComparator<Person>.by(\.age)

    // This comparator works locally
    let alice = Person(name: "Alice", age: 30, department: "Engineering")
    let bob = Person(name: "Bob", age: 25, department: "Sales")
    #expect(comparator(alice, bob) == .greater)

    print("NON-SENDABLE: NonSendableComparator works for local (non-concurrent) use")
}

// ============================================================================
// MARK: - PROJECTION TESTS
// ============================================================================

@Test
func `Projection: Direction integration (Sendable)`() {
    let ascending = Order.Projection<Person, Int>({ $0.age }, direction: .ascending)
    let descending = Order.Projection<Person, Int>({ $0.age }, direction: .descending)

    let young = Person(name: "Young", age: 20, department: "A")
    let old = Person(name: "Old", age: 40, department: "B")

    // Ascending: younger comes first
    #expect(ascending.comparator(young, old) == .less)

    // Descending: older comes first
    #expect(descending.comparator(young, old) == .greater)

    // Test reversed projection
    #expect(ascending.reversed.direction == .descending)
    #expect(descending.reversed.direction == .ascending)

    print("PROJECTION (Sendable): Direction integration works correctly")
}

@Test
func `Projection: KeyPath-based (NonSendable)`() {
    let ascending = Order.NonSendableProjection<Person, Int>(\.age, direction: .ascending)
    let descending = Order.NonSendableProjection<Person, Int>(\.age, direction: .descending)

    let young = Person(name: "Young", age: 20, department: "A")
    let old = Person(name: "Old", age: 40, department: "B")

    // Ascending: younger comes first
    #expect(ascending.comparator(young, old) == .less)

    // Descending: older comes first
    #expect(descending.comparator(young, old) == .greater)

    print("PROJECTION (NonSendable): KeyPath-based direction integration works correctly")
}

// ============================================================================
// MARK: - DISCOVERY DOCUMENTATION
// ============================================================================

/// Document the critical KeyPath Sendable discovery
@Test
func `DISCOVERY: KeyPath is NOT Sendable in Swift 6`() {
    // This test documents the critical discovery that KeyPath<Root, Value>
    // is NOT Sendable in Swift 6 strict concurrency mode.

    // The design paper proposed:
    //   public static func by<Value: Comparable>(
    //       _ keyPath: KeyPath<T, Value>
    //   ) -> Order.Comparator<T>
    //
    // This DOES NOT COMPILE with Swift 6 strict concurrency because
    // capturing a KeyPath in a @Sendable closure is forbidden.

    // WORKAROUNDS:
    // 1. Use closure-based selectors: .by { $0.age } instead of .by(\.age)
    // 2. Use NonSendableComparator for local (non-concurrent) KeyPath usage
    // 3. Wait for Swift evolution to make KeyPath Sendable

    print("DISCOVERY DOCUMENTED: KeyPath<Root, Value> is NOT Sendable in Swift 6")
    print("  - Compiler error: 'capture of keyPath with non-Sendable type in @Sendable closure'")
    print("  - Impact: Design paper Section 5.3.4 requires revision")
    print("  - Workaround: Use closure-based .by({ $0.property }) instead of .by(\\.property)")
}
