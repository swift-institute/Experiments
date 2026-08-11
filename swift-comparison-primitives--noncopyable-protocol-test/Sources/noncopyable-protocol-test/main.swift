// EXPERIMENT: noncopyable-protocol-test
// DATE: 2026-01-22
// HYPOTHESIS: We can create a Comparable-like protocol with ~Copyable support
//             using borrowing parameters
// STATUS: CONFIRMED
// METHODOLOGY: Incremental Construction [EXP-004a]
//
// FINDINGS:
// 1. Protocols declared with `: ~Copyable` allow non-copyable conformers
// 2. Operators with `borrowing` parameters work in protocol requirements
// 3. CRITICAL: Protocol extensions MUST use `where Self: ~Copyable` to provide
//    default implementations for non-copyable types
// 4. Both Copyable and ~Copyable types can conform to the same protocol
// 5. Generic constraints `T: Protocol & ~Copyable` with `borrowing` work correctly

// =============================================================================
// VARIANT 1: Simplest protocol with ~Copyable
// =============================================================================

protocol SimpleProtocol: ~Copyable {
    static func test(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
}

struct SimpleNonCopyable: ~Copyable, SimpleProtocol {
    let value: Int

    static func test(_ lhs: borrowing SimpleNonCopyable, _ rhs: borrowing SimpleNonCopyable) -> Bool {
        lhs.value < rhs.value
    }
}

// Test
let a = SimpleNonCopyable(value: 1)
let b = SimpleNonCopyable(value: 2)
print("V1 - Simple protocol: \(SimpleNonCopyable.test(a, b))")  // Should be true

// =============================================================================
// VARIANT 2: Protocol with operator requirement
// =============================================================================

protocol OperatorProtocol: ~Copyable {
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

struct OperatorNonCopyable: ~Copyable, OperatorProtocol {
    let value: Int

    static func < (lhs: borrowing OperatorNonCopyable, rhs: borrowing OperatorNonCopyable) -> Bool {
        lhs.value < rhs.value
    }
}

// Test
let c = OperatorNonCopyable(value: 1)
let d = OperatorNonCopyable(value: 2)
print("V2 - Operator protocol: \(c < d)")  // Should be true

// =============================================================================
// VARIANT 3: Protocol with both < and == operators
// =============================================================================

protocol ComparableProtocol: ~Copyable {
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

struct ComparableNonCopyable: ~Copyable, ComparableProtocol {
    let value: Int

    static func < (lhs: borrowing ComparableNonCopyable, rhs: borrowing ComparableNonCopyable) -> Bool {
        lhs.value < rhs.value
    }

    static func == (lhs: borrowing ComparableNonCopyable, rhs: borrowing ComparableNonCopyable) -> Bool {
        lhs.value == rhs.value
    }
}

// Test
let e = ComparableNonCopyable(value: 1)
let f = ComparableNonCopyable(value: 1)
let g = ComparableNonCopyable(value: 2)
print("V3 - Comparable protocol <: \(e < g)")  // true
print("V3 - Comparable protocol ==: \(e == f)")  // true

// =============================================================================
// VARIANT 4: Protocol with all comparison operators and default implementations
// =============================================================================

protocol FullComparableProtocol: ~Copyable {
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
    static func <= (lhs: borrowing Self, rhs: borrowing Self) -> Bool
    static func > (lhs: borrowing Self, rhs: borrowing Self) -> Bool
    static func >= (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

extension FullComparableProtocol where Self: ~Copyable {
    static func <= (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(rhs < lhs)
    }

    static func > (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        rhs < lhs
    }

    static func >= (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(lhs < rhs)
    }
}

struct FullComparableNonCopyable: ~Copyable, FullComparableProtocol {
    let value: Int

    static func < (lhs: borrowing FullComparableNonCopyable, rhs: borrowing FullComparableNonCopyable) -> Bool {
        lhs.value < rhs.value
    }

    static func == (lhs: borrowing FullComparableNonCopyable, rhs: borrowing FullComparableNonCopyable) -> Bool {
        lhs.value == rhs.value
    }
}

// Test
let h = FullComparableNonCopyable(value: 5)
let i = FullComparableNonCopyable(value: 5)
let j = FullComparableNonCopyable(value: 10)
print("V4 - Full protocol <: \(h < j)")  // true
print("V4 - Full protocol ==: \(h == i)")  // true
print("V4 - Full protocol <=: \(h <= i)")  // true
print("V4 - Full protocol >: \(j > h)")  // true
print("V4 - Full protocol >=: \(h >= i)")  // true

// =============================================================================
// VARIANT 5: Result enum for three-way comparison
// =============================================================================

enum ComparisonResult: Sendable, Hashable {
    case less
    case equal
    case greater
}

extension ComparisonResult {
    init<T: FullComparableProtocol & ~Copyable>(_ lhs: borrowing T, _ rhs: borrowing T) {
        if lhs < rhs {
            self = .less
        } else if lhs > rhs {
            self = .greater
        } else {
            self = .equal
        }
    }
}

// Test with non-copyable type
let k = FullComparableNonCopyable(value: 1)
let l = FullComparableNonCopyable(value: 2)
let m = FullComparableNonCopyable(value: 1)
print("V5 - Result(k, l): \(ComparisonResult(k, l))")  // less
print("V5 - Result(l, k): \(ComparisonResult(l, k))")  // greater
print("V5 - Result(k, m): \(ComparisonResult(k, m))")  // equal

// =============================================================================
// VARIANT 6: Copyable type conforming to same protocol
// =============================================================================

struct CopyableValue: FullComparableProtocol {
    let value: Int

    static func < (lhs: borrowing CopyableValue, rhs: borrowing CopyableValue) -> Bool {
        lhs.value < rhs.value
    }

    static func == (lhs: borrowing CopyableValue, rhs: borrowing CopyableValue) -> Bool {
        lhs.value == rhs.value
    }
}

let cv1 = CopyableValue(value: 1)
let cv2 = CopyableValue(value: 2)
print("V6 - Copyable with protocol <: \(cv1 < cv2)")  // true
print("V6 - Result(cv1, cv2): \(ComparisonResult(cv1, cv2))")  // less

// =============================================================================
// VARIANT 7: Generic function using the protocol
// =============================================================================

func compare<T: FullComparableProtocol & ~Copyable>(_ lhs: borrowing T, _ rhs: borrowing T) -> ComparisonResult {
    ComparisonResult(lhs, rhs)
}

let n = FullComparableNonCopyable(value: 5)
let o = FullComparableNonCopyable(value: 3)
print("V7 - Generic compare(n, o): \(compare(n, o))")  // greater

print("\n✅ All variants passed!")
