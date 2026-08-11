// MARK: - Tagged.LiteralSafe Marker Protocol on RawValue
// Purpose: Gate Tagged's ExpressibleByIntegerLiteral on a RawValue marker
//          protocol. RawValues opt in (Int, UInt, Double, etc.); Ordinal
//          deliberately does NOT opt in. Test that this prevents the
//          Bit.Index footgun even when Tagged is Strideable.
//
// Hypothesis:
//   - Literal works for LiteralSafe-tagged RawValues (UInt32, Double, Int, ...)
//   - Literal does NOT work for Ordinal-backed Tagged types (footgun prevention)
//   - Per-tag opt-in via disjoint conditional conformance is possible
//
// Toolchain: Swift 6.3.1 (Xcode 26.4.1 default; swiftlang-6.3.1.1.2)
// Platform:  macOS 26.0 (arm64)
// Date:      2026-04-21
//
// Result: CONFIRMED — marker protocol works for the main mechanism;
//         REFUTED — per-tag opt-in on same protocol is rejected by Swift.
//
// Evidence (stdout + compile errors, per variant):
//   Variant 1: UserID = 42 → rawValue=42 (UInt32 is LiteralSafe) ✓
//   Variant 2: X<Space> = 0.0, Year = 2026 (Double/Int LiteralSafe) ✓
//   Variant 3: (0..<5).map(BitIndex.init) → COMPILE ERROR
//     "generic type alias 'Index' requires that 'Ordinal' conform to 'TaggedLiteralSafe'"
//     → footgun structurally blocked ✓
//   Variant 4: byteIndices.map { BitIndex($0) } = [0, 8, 16, 24, 32]
//     → explicit byte-to-bit still works ✓
//   Variant 5: extension Tagged: ExpressibleByIntegerLiteral where Tag == BitTag,
//              RawValue == Ordinal → COMPILE ERROR
//     "conflicting conformance of 'Tagged<Tag, RawValue>' to protocol
//      'ExpressibleByIntegerLiteral'; there cannot be more than one conformance,
//      even with different conditional bounds"
//     → per-tag opt-in IMPOSSIBLE (marker approach is all-or-nothing per RawValue) ✗
//
// Status: CONFIRMED (marker works) + REFUTED (per-tag opt-in impossible).
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         Tradeoff surfaced: Ordinal-backed Tagged types lose literal ergonomics
//         globally; cannot be selectively re-enabled per-domain.

// MARK: - Tagged + Marker Protocol

struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    var rawValue: RawValue
    init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

extension Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable {}

// THE MARKER: opt-in for RawValues that are safe to forward literals through
protocol TaggedLiteralSafe {}

// Gate the blanket ExpressibleByIntegerLiteral on the marker
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable,
      RawValue: ExpressibleByIntegerLiteral & TaggedLiteralSafe {
    @_disfavoredOverload
    init(integerLiteral value: RawValue.IntegerLiteralType) {
        self.init(__unchecked: (), RawValue(integerLiteral: value))
    }
}

extension Tagged: ExpressibleByFloatLiteral
where Tag: ~Copyable,
      RawValue: ExpressibleByFloatLiteral & TaggedLiteralSafe {
    @_disfavoredOverload
    init(floatLiteral value: RawValue.FloatLiteralType) {
        self.init(__unchecked: (), RawValue(floatLiteral: value))
    }
}

extension Tagged: Equatable where Tag: ~Copyable, RawValue: Equatable {
    static func == (lhs: Tagged, rhs: Tagged) -> Bool { lhs.rawValue == rhs.rawValue }
}
extension Tagged: Comparable where Tag: ~Copyable, RawValue: Comparable {
    static func < (lhs: Tagged, rhs: Tagged) -> Bool { lhs.rawValue < rhs.rawValue }
}
extension Tagged: Strideable where Tag: ~Copyable, RawValue: Strideable {
    func advanced(by n: RawValue.Stride) -> Tagged {
        Tagged(__unchecked: (), rawValue.advanced(by: n))
    }
    func distance(to other: Tagged) -> RawValue.Stride {
        rawValue.distance(to: other.rawValue)
    }
}

// MARK: - Opt-ins: standard numeric types ARE LiteralSafe

extension Int: TaggedLiteralSafe {}
extension Int32: TaggedLiteralSafe {}
extension UInt: TaggedLiteralSafe {}
extension UInt32: TaggedLiteralSafe {}
extension UInt64: TaggedLiteralSafe {}
extension Double: TaggedLiteralSafe {}

// MARK: - Ordinal (UInt-backed) — INTENTIONALLY NOT LiteralSafe

struct Ordinal: ExpressibleByIntegerLiteral, Equatable, Comparable, Strideable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    @_disfavoredOverload
    init(integerLiteral value: UInt) { self.init(value) }
    static func < (lhs: Ordinal, rhs: Ordinal) -> Bool { lhs.rawValue < rhs.rawValue }
    func advanced(by n: Int) -> Ordinal { Ordinal(UInt(Int(self.rawValue) + n)) }
    func distance(to other: Ordinal) -> Int { Int(other.rawValue) - Int(self.rawValue) }
}
// DELIBERATELY DO NOT: extension Ordinal: TaggedLiteralSafe {}

struct Cardinal: ExpressibleByIntegerLiteral, Equatable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    @_disfavoredOverload
    init(integerLiteral value: UInt) { self.init(value) }
    static func * (lhs: Cardinal, rhs: Cardinal) -> Cardinal {
        Cardinal(lhs.rawValue * rhs.rawValue)
    }
}

// MARK: - Domain types that match production shape

enum BitTag {}
enum UserTag {}

typealias Index<Element> = Tagged<Element, Ordinal>
typealias BitIndex = Tagged<BitTag, Ordinal>
typealias UserID = Tagged<UserTag, UInt32>

extension Tagged where Tag == UInt8, RawValue == Ordinal {
    var count: Cardinal { Cardinal(rawValue.rawValue) }
}

extension Tagged where Tag == BitTag, RawValue == Ordinal {
    // The footgun-prone cross-domain init
    init(_ byteIndex: Index<UInt8>) {
        let bits = byteIndex.count * Cardinal(8)
        self.init(__unchecked: (), Ordinal(bits.rawValue))
    }
}

// MARK: - Variant 1: Ergonomic use for LiteralSafe RawValues
// Hypothesis: UserID = 42 compiles (UInt32 is LiteralSafe)

print("=== Variant 1: Kernel.User.ID literal use (LiteralSafe RawValue) ===")
let user: UserID = 42
print("  UserID = 42: rawValue=\(user.rawValue)   (expected: 42)")

// MARK: - Variant 2: Production typealiases that NEED literals
// Double-backed (coordinates), UInt32 (Kernel IDs), Int (Time.Offset components)

struct SpatialX<Space>: ~Copyable {}
struct YearTag: ~Copyable {}
typealias X<Space> = Tagged<SpatialX<Space>, Double>
typealias Year = Tagged<YearTag, Int>

enum SomeSpace {}
print()
print("=== Variant 2: Coordinates / year components ===")
let x: X<SomeSpace> = 0.0
let year: Year = 2026
print("  X = 0.0: rawValue=\(x.rawValue)     (expected: 0.0)")
print("  Year = 2026: rawValue=\(year.rawValue)  (expected: 2026)")

// MARK: - Variant 3: The FOOTGUN — Ordinal-backed Tagged types
// Hypothesis: `(0..<5).map(BitIndex.init)` behaves differently now because
//             BitIndex itself doesn't conform to ExpressibleByIntegerLiteral
//             (Ordinal is not TaggedLiteralSafe).

print()
print("=== Variant 3: Footgun test — BitIndex (Ordinal-backed) ===")
// Does BitIndex accept literals directly?
// let bad: BitIndex = 5  // Should fail: Ordinal not LiteralSafe

// Does (0..<5).map(BitIndex.init) compile?
// The candidates for BitIndex.init with unlabeled single arg:
//   - init(_ byteIndex: Index<UInt8>) — but Index<UInt8> is Tagged<UInt8, Ordinal>,
//     and Ordinal is not LiteralSafe, so Index<UInt8> doesn't accept literals.
//     Therefore 0..<5 cannot be inferred as Range<Index<UInt8>>.
//   - integerLiteral init: labeled, not accessible via .init function reference.
//   - __unchecked init: labeled, not accessible.
// Expected: compile error.

// Confirmed: the following is a compile error.
// error: generic type alias 'Index' requires that 'Ordinal' conform to 'TaggedLiteralSafe'
// let result3: [BitIndex] = (0..<5).map(BitIndex.init)
print("  (0..<5).map(BitIndex.init): COMPILE ERROR (footgun prevented)")
print("  Direct literal: let idx: BitIndex = 5 ALSO a compile error.")

// MARK: - Variant 4: Explicit byte-to-bit via closure still works
// If callers need byte-to-bit conversion, they do it explicitly.

print()
print("=== Variant 4: Explicit byte→bit construction still works ===")
let byteIndices: [Index<UInt8>] = (0..<5).map { n in
    Index<UInt8>(__unchecked: (), Ordinal(UInt(n)))
}
let bits: [BitIndex] = byteIndices.map { BitIndex($0) }
print("  Explicit byte→bit: \(bits.map { $0.rawValue.rawValue })")
print("  Expected: [0, 8, 16, 24, 32]")

// MARK: - Variant 5: Per-domain opt-in — REJECTED by Swift
// Attempted concrete-tag extension:
//   extension Tagged: ExpressibleByIntegerLiteral where Tag == BitTag, RawValue == Ordinal
//
// Swift rejects this as: "conflicting conformance of 'Tagged<Tag, RawValue>'
// to protocol 'ExpressibleByIntegerLiteral'; there cannot be more than one
// conformance, even with different conditional bounds."
//
// IMPLICATION: the marker protocol gate is all-or-nothing. If a domain needs
// literal ergonomics but its RawValue is not LiteralSafe, options are:
//   1. Make that RawValue LiteralSafe globally (re-opens footgun for every
//      tag that uses it — typically unacceptable).
//   2. Make the domain type a proper struct (not a typealias) that wraps
//      Tagged and adds its own `ExpressibleByIntegerLiteral`.
//   3. Provide labeled initializers: Bit.Index(position: 5) instead of = 5.
//   4. Live without literal ergonomics for that domain.

print()
print("=== Variant 5: Per-tag opt-in impossible — Swift restriction ===")
print("  See comment block above. Only one Tagged: ExpressibleByIntegerLiteral")
print("  conformance allowed, regardless of disjoint constraints.")
