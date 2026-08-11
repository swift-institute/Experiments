// MARK: - Consumer Test
// Purpose: Test what happens when a consumer imports ComparableShadow
//
// FINDINGS SO FAR:
// - Declaring `Comparable` in a module DOES shadow Swift.Comparable
// - When consumer uses bare `Comparable`, it resolves to OUR protocol
// - Int does NOT automatically conform to our Comparable
// - This means: shadowing BREAKS existing Swift.Comparable usage!

import ComparableShadow

// MARK: - Test 1: Shadowing Confirmation

func testShadowingConfirmation() {
    print("=== Test 1: Shadowing Confirmation ===")

    // FINDING: This does NOT compile because `Comparable` resolves to
    // ComparableShadow.Comparable, and Int doesn't conform to it.
    //
    // func requireOurComparable<T: Comparable>(_ a: borrowing T, _ b: borrowing T) -> Bool {
    //     a < b
    // }
    // let result = requireOurComparable(5, 10)  // ERROR: Int doesn't conform to Comparable

    print("CONFIRMED: Bare `Comparable` resolves to ComparableShadow.Comparable")
    print("CONFIRMED: Int does NOT automatically conform to our Comparable")
    print("IMPLICATION: Shadowing BREAKS existing code that uses Swift.Comparable")
}

// MARK: - Test 2: ~Copyable type with our Comparable

struct Token: ~Copyable {
    let id: Int
}

// Conform to our Comparable (must use explicit module qualification)
extension Token: ComparableShadow.Comparable {
    static func < (lhs: borrowing Token, rhs: borrowing Token) -> Bool {
        lhs.id < rhs.id
    }

    static func == (lhs: borrowing Token, rhs: borrowing Token) -> Bool {
        lhs.id == rhs.id
    }
}

func testNonCopyableComparable() {
    print("\n=== Test 2: ~Copyable Comparable ===")

    let a = Token(id: 5)
    let b = Token(id: 10)

    print("Token(5) < Token(10) = \(a < b)")
    print("Token(5) > Token(10) = \(a > b)")
    print("Token(5) == Token(10) = \(a == b)")
    print("SUCCESS: ~Copyable type works with our Comparable")
}

// MARK: - Test 3: Swift.Comparable Still Works (with qualification)

func testSwiftComparableStillWorks() {
    print("\n=== Test 3: Swift.Comparable (with qualification) ===")

    // We can still use Swift.Comparable by explicit qualification
    func requireSwiftComparable<T: Swift.Comparable>(_ a: T, _ b: T) -> Bool {
        a < b
    }

    let result = requireSwiftComparable(5, 10)
    print("Swift.Comparable: 5 < 10 = \(result)")

    // Standard library functions that require Swift.Comparable still work
    let ints = [3, 1, 4, 1, 5, 9, 2, 6]
    let sorted = ints.sorted()  // Uses Swift.Comparable
    print("Sorted: \(sorted)")
    print("Min: \(ints.min()!)")
    print("Max: \(ints.max()!)")
    print("SUCCESS: Swift.Comparable still works with explicit qualification")
}

// MARK: - Test 4: Generic function with ~Copyable Comparable

func testGenericNonCopyable() {
    print("\n=== Test 4: Generic ~Copyable Comparable ===")

    // Need to explicitly opt out of Copyable
    func compareTokens<T: ComparableShadow.Comparable & ~Copyable>(
        _ a: borrowing T,
        _ b: borrowing T
    ) -> Bool {
        a < b
    }

    let t1 = Token(id: 5)
    let t2 = Token(id: 10)
    let result = compareTokens(t1, t2)
    print("compareTokens(Token(5), Token(10)) = \(result)")
    print("SUCCESS: Generic function with ~Copyable constraint works")
}

// MARK: - Run All Tests

print("╔════════════════════════════════════════════════════════════╗")
print("║     EXPERIMENT: Comparable Shadowing Test                  ║")
print("╚════════════════════════════════════════════════════════════╝")
print("")

testShadowingConfirmation()
testNonCopyableComparable()
testSwiftComparableStillWorks()
testGenericNonCopyable()

print("")
print("════════════════════════════════════════════════════════════")
print("CONCLUSIONS:")
print("")
print("1. SHADOWING WORKS: Declaring `Comparable` in a module shadows")
print("   Swift.Comparable for consumers of that module.")
print("")
print("2. NOT MAGIC: Existing Swift.Comparable conformances (Int, String)")
print("   do NOT automatically work with our Comparable. They are")
print("   separate protocols with DIFFERENT SIGNATURES:")
print("   - Swift.Comparable: static func < (lhs: Self, rhs: Self)")
print("   - Our Comparable:   static func < (lhs: borrowing Self, rhs: borrowing Self)")
print("")
print("3. RETROACTIVE CONFORMANCE FAILS: We cannot add retroactive")
print("   conformances for Int, String, etc because:")
print("   - Multiple matching operators cause ambiguity")
print("   - Signature difference (borrowing vs non-borrowing)")
print("   - Would break stdlib's own usage")
print("")
print("4. BREAKING: If we name our protocol `Comparable`, consumers")
print("   who write `T: Comparable` will get OUR protocol, and their")
print("   code using Int, String etc will BREAK.")
print("")
print("5. WORKAROUND NOT VIABLE: Consumers would have to write")
print("   `Swift.Comparable` everywhere, defeating the purpose.")
print("")
print("6. RECOMMENDATION: Do NOT name our protocol `Comparable`.")
print("   Keep it as `Comparison.Protocol` to avoid shadowing issues.")
print("   The 'magic' is not achievable with current Swift.")
print("════════════════════════════════════════════════════════════")
