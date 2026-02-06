// MARK: - ~Copyable Associated Type Domain Experiment
// Purpose: Determine if `associatedtype Domain: ~Copyable` compiles in Swift 6.2,
//          and if a Tagged<Tag: ~Copyable, RawValue> can satisfy Domain = Tag.
// Hypothesis: Swift 6.2 supports `associatedtype X: ~Copyable` to allow
//             non-copyable type witnesses.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — `associatedtype Domain: ~Copyable` emits
//         "cannot suppress 'Copyable' requirement of an associated type"
//         on Swift 6.2.3. No feature flag resolves this.
// Date: 2026-02-04

// ============================================================================
// MARK: - Variant 1: associatedtype Domain (no suppression)
// Hypothesis: Plain `associatedtype Domain` requires Copyable witnesses.
//             A ~Copyable Tag cannot satisfy it.
// Result: REFUTED — "does not conform to Copyable"
// ============================================================================

// protocol V1_Protocol {
//     associatedtype Domain
//     var value: Int { get }
// }
// struct V1_Tagged<Tag: ~Copyable>: V1_Protocol {
//     typealias Domain = Tag  // ERROR: Tag does not conform to Copyable
//     var value: Int
// }

// ============================================================================
// MARK: - Variant 2: associatedtype Domain: ~Copyable
// Hypothesis: `associatedtype Domain: ~Copyable` allows non-copyable witnesses.
// Result: REFUTED — "cannot suppress 'Copyable' requirement of an associated type"
// ============================================================================

// protocol V2_Protocol {
//     associatedtype Domain: ~Copyable
//     var value: Int { get }
// }

// ============================================================================
// MARK: - Variant 3: associatedtype Domain: ~Copyable & ~Escapable
// Hypothesis: Full suppression of both implicit constraints.
// Result: REFUTED — "cannot suppress 'Copyable' requirement" AND
//                    "cannot suppress 'Escapable' requirement"
// ============================================================================

// ============================================================================
// MARK: - Variant 6: Copyable wrapper as Domain witness
// Hypothesis: Use a Copyable enum wrapper to project ~Copyable Tag into
//             a Copyable Domain type. Pattern: `enum Domain<Tag: ~Copyable> {}`
//             where Domain is always Copyable (uninhabited enum).
// Result: CONFIRMED — Build Succeeded, output: V6 bare×bare: 3, V6 tagged×tagged: 30
// ============================================================================

/// A Copyable phantom witness that wraps a ~Copyable tag.
///
/// Since `Domain.Witness` is an uninhabited enum, it is always Copyable.
/// It exists purely as a type-level marker to satisfy `associatedtype Domain`
/// while projecting through a ~Copyable tag.
enum Witness<Tag: ~Copyable>: Copyable {}

protocol V6_Left {
    associatedtype Domain
    var leftValue: Int { get }
}

protocol V6_Right {
    associatedtype Domain
    var rightValue: Int { get }
}

// Bare conformances: Domain = Never
struct V6_BareLeft: V6_Left {
    typealias Domain = Never
    var leftValue: Int
}

struct V6_BareRight: V6_Right {
    typealias Domain = Never
    var rightValue: Int
}

// Tagged conformances: Domain = Witness<Tag>  (always Copyable!)
struct V6_TaggedLeft<Tag: ~Copyable>: V6_Left {
    typealias Domain = Witness<Tag>
    var leftValue: Int
}

struct V6_TaggedRight<Tag: ~Copyable>: V6_Right {
    typealias Domain = Witness<Tag>
    var rightValue: Int
}

func v6_combine<L: V6_Left, R: V6_Right>(
    _ lhs: L, _ rhs: R
) -> Int where L.Domain == R.Domain {
    lhs.leftValue + rhs.rightValue
}

// Bare × Bare: Never == Never ✓
let r1 = v6_combine(V6_BareLeft(leftValue: 1), V6_BareRight(rightValue: 2))
print("V6 bare×bare: \(r1)")

// Tagged × Tagged (same tag): Witness<MyTag> == Witness<MyTag> ✓
enum MyTag {}
let r2 = v6_combine(
    V6_TaggedLeft<MyTag>(leftValue: 10),
    V6_TaggedRight<MyTag>(rightValue: 20)
)
print("V6 tagged×tagged: \(r2)")

print("V6: compiled and ran")

// ============================================================================
// MARK: - Variant 7: Conditional conformance on generic type (full scenario)
// Hypothesis: The Witness pattern works with conditional conformances on
//             a generic wrapper (simulating Tagged<Tag, RawValue>).
// Result: CONFIRMED — Build Succeeded, output: V7 bare: 42, V7 tagged: 84
// ============================================================================

struct V7_Wrapper<Tag: ~Copyable, RawValue> {
    var rawValue: RawValue
}

protocol V7_Proto {
    associatedtype Domain
    var wrapped: Int { get }
    init(_ value: Int)
}

struct V7_Bare: V7_Proto {
    typealias Domain = Never
    var wrapped: Int
    init(_ value: Int) { self.wrapped = value }
}

extension V7_Wrapper: V7_Proto where RawValue == Int, Tag: ~Copyable {
    typealias Domain = Witness<Tag>
    var wrapped: Int { rawValue }
    init(_ value: Int) { self.rawValue = value }
}

func v7_double<P: V7_Proto>(_ p: P) -> P {
    P(p.wrapped * 2)
}

let v7b = v7_double(V7_Bare(21))
print("V7 bare: \(v7b.wrapped)")

let v7t = v7_double(V7_Wrapper<MyTag, Int>(42))
print("V7 tagged: \(v7t.wrapped)")

print("V7: compiled and ran")

// ============================================================================
// MARK: - Variant 8: Cross-type operators with Domain constraint
// Hypothesis: Free functions with `where L.Domain == R.Domain` correctly
//             accept bare×bare and tagged×tagged, reject tagged×bare.
// Result: CONFIRMED — Build Succeeded, output: V8 bare: 8, V8 tagged: 17
// ============================================================================

protocol V8_Ordinal {
    associatedtype Domain
    var position: Int { get }
    init(position: Int)
}

protocol V8_Cardinal {
    associatedtype Domain
    var count: Int { get }
}

// Bare
struct V8_BareOrd: V8_Ordinal {
    typealias Domain = Never
    var position: Int
    init(position: Int) { self.position = position }
}

struct V8_BareCard: V8_Cardinal {
    typealias Domain = Never
    var count: Int
}

// Tagged
struct V8_TaggedOrd<Tag: ~Copyable>: V8_Ordinal {
    typealias Domain = Witness<Tag>
    var position: Int
    init(position: Int) { self.position = position }
}

struct V8_TaggedCard<Tag: ~Copyable>: V8_Cardinal {
    typealias Domain = Witness<Tag>
    var count: Int
}

// Unified cross-type operator
func + <O: V8_Ordinal, C: V8_Cardinal>(
    lhs: O, rhs: C
) -> O where O.Domain == C.Domain {
    O(position: lhs.position + rhs.count)
}

// Bare + Bare
let v8r1 = V8_BareOrd(position: 5) + V8_BareCard(count: 3)
print("V8 bare: \(v8r1.position)")

// Tagged + Tagged (same tag)
let v8r2 = V8_TaggedOrd<MyTag>(position: 10) + V8_TaggedCard<MyTag>(count: 7)
print("V8 tagged: \(v8r2.position)")

// Tagged + Tagged (different tag) — should NOT compile:
// enum OtherTag {}
// let v8bad = V8_TaggedOrd<MyTag>(position: 1) + V8_TaggedCard<OtherTag>(count: 1)
// ^ Uncomment to verify compile error

print("V8: compiled and ran")

// ============================================================================
// MARK: - Results Summary
// V1: REFUTED — plain associatedtype requires Copyable
// V2: REFUTED — ~Copyable suppression on associatedtype not supported
// V3: REFUTED — ~Copyable & ~Escapable suppression not supported
// V6: CONFIRMED — Witness<Tag> wrapper pattern compiles and runs
// V7: CONFIRMED — conditional conformance with Witness compiles and runs
// V8: CONFIRMED — cross-type operators with Domain constraint compile and run
// ============================================================================
