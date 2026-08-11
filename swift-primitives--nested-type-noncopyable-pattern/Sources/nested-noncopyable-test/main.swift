// ===----------------------------------------------------------------------===//
// EXPERIMENT: Dictionary namespace with ~Copyable support
// ===----------------------------------------------------------------------===//
//
// FINDINGS:
// 1. Nested type MUST be declared inside the enum body, NOT in extension
// 2. Extensions MUST have explicit `where Value: ~Copyable` constraint
//
// STATUS: [SUCCESS]
// Result: CONFIRMED — Nested ~Copyable types work correctly. Conditional
//   Copyable conformance (where Value: Copyable) compiles and functions
//   as designed.
//
// ===----------------------------------------------------------------------===//

struct MoveOnly: ~Copyable {
    var x: Int
}

/// Namespace for ordered dictionary types.
///
/// This shadows `Swift.Dictionary`. Use `Swift.Dictionary` or module-qualified
/// `Dictionary_Primitives.Dictionary` to disambiguate when both are in scope.
public enum Dictionary<Key: Hashable, Value: ~Copyable>: ~Copyable {
    /// Ordered dictionary with insertion-order preservation.
    public struct Ordered: ~Copyable {
        var _count: Int = 0
        public init() {}
    }
}

// Conditional Copyable conformance
extension Dictionary.Ordered: Copyable where Value: Copyable {}

// Base API for all values (~Copyable and Copyable)
extension Dictionary.Ordered where Value: ~Copyable {
    public mutating func set(_ key: Key, _ value: consuming Value) {
        print("set called (base, consuming)")
        _count += 1
    }
}

// TEST 1: ~Copyable values
func testNonCopyable() {
    typealias MyDict = nested_noncopyable_test.Dictionary<String, MoveOnly>.Ordered
    var dict = MyDict()
    dict.set("key", MoveOnly(x: 42))
    print("✅ Test 1: ~Copyable values work! Count: \(dict._count)")
}

// TEST 2: Copyable values
func testCopyable() {
    typealias MyDict = nested_noncopyable_test.Dictionary<String, Int>.Ordered
    var dict = MyDict()
    dict.set("key", 42)
    print("✅ Test 2: Copyable values work! Count: \(dict._count)")
}

// TEST 3: Copyable conformance
func testCopyableConformance() {
    typealias MyDict = nested_noncopyable_test.Dictionary<String, Int>.Ordered
    var dict1 = MyDict()
    dict1.set("a", 1)
    let dict2 = dict1  // Should copy since Int is Copyable
    print("✅ Test 3: Copyable conformance works! dict1: \(dict1._count), dict2: \(dict2._count)")
}

testNonCopyable()
testCopyable()
testCopyableConformance()
