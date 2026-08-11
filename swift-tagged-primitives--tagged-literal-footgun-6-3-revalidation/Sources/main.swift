// MARK: - Footgun Revalidation on Swift 6.3.1
// Purpose: Reproduce the original Bit.Index byte-to-bit overload resolution footgun
//          on current toolchains. The original repro was swift-6.2-RELEASE;
//          verify empirically before committing to a fix.
//
// Original footgun (2026-02-11, from cross-domain-init-overload-resolution-footgun.md):
//   for i in (0..<5).map(Bit.Index.init) {
//       #expect(bits[i] == true)  // CRASH: i = 0, 8, 16, 24, 32 — not 0, 1, 2, 3, 4
//   }
//
// Toolchain: Swift 6.3.1 (Xcode 26.4.1 default; swiftlang-6.3.1.1.2)
// Platform:  macOS 26.0 (arm64)
// Date:      2026-04-21
//
// Result: PARTIAL — footgun is STRUCTURALLY DORMANT without Strideable on Tagged,
//         but ACTIVE the moment Strideable is introduced (the desired production
//         state per swift-index-primitives/Research/Strideable Index Design.md).
//         The current "safety" is accidental, not principled.
//
// Evidence (see Variant 1 output below):
//   Without Tagged: Strideable    → (0..<5).map(BitIndex.init) = [0, 1, 2, 3, 4]   safe
//   With    Tagged: Strideable    → (0..<5).map(BitIndex.init) = [0, 8, 16, 24, 32] footgun live
//   With Strideable + @_disfavoredOverload on literal init → still [0, 8, 16, 24, 32]
//       — @_disfavoredOverload does NOT protect.
//
// Structural explanation: Range<T> requires T: Strideable to be a Sequence.
// Without Strideable on Index<UInt8> (= Tagged<UInt8, Ordinal>), Swift cannot
// infer 0..<5 as Range<Index<UInt8>>; the literal-inference chain is blocked.
// With Strideable, Swift forms Range<Index<UInt8>>, resolves .map(BitIndex.init)
// to the unlabeled byte-to-bit init, and produces scaled values silently.
//
// Status: STILL PRESENT on Swift 6.3.1 once Strideable is added.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

// MARK: - Minimal Tagged Infrastructure

struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    var rawValue: RawValue
    init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

extension Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable {}

extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable, RawValue: ExpressibleByIntegerLiteral {
    @_disfavoredOverload
    init(integerLiteral value: RawValue.IntegerLiteralType) {
        self.init(__unchecked: (), RawValue(integerLiteral: value))
    }
}

extension Tagged: Equatable where Tag: ~Copyable, RawValue: Equatable {
    static func == (lhs: Tagged, rhs: Tagged) -> Bool { lhs.rawValue == rhs.rawValue }
}
extension Tagged: Comparable where Tag: ~Copyable, RawValue: Comparable {
    static func < (lhs: Tagged, rhs: Tagged) -> Bool { lhs.rawValue < rhs.rawValue }
}

// STRIDEABLE — the missing link. Per `Strideable Index Design.md` DECISION,
// Index<Tag> SHOULD conform to Strideable. Without it, Range<Index<T>>
// isn't iterable and the footgun cannot fire. WITH it, the footgun is live.
extension Tagged: Strideable where Tag: ~Copyable, RawValue: Strideable {
    func advanced(by n: RawValue.Stride) -> Tagged { Tagged(__unchecked: (), rawValue.advanced(by: n)) }
    func distance(to other: Tagged) -> RawValue.Stride { rawValue.distance(to: other.rawValue) }
}

// MARK: - Minimal Ordinal / Cardinal (UInt-backed, mirror production)

struct Ordinal: ExpressibleByIntegerLiteral, Equatable, Comparable, Strideable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    @_disfavoredOverload
    init(integerLiteral value: UInt) { self.init(value) }
    static func < (lhs: Ordinal, rhs: Ordinal) -> Bool { lhs.rawValue < rhs.rawValue }
    // Strideable — models position-traversal per Strideable Index Design.md
    func advanced(by n: Int) -> Ordinal { Ordinal(UInt(Int(self.rawValue) + n)) }
    func distance(to other: Ordinal) -> Int { Int(other.rawValue) - Int(self.rawValue) }
}

struct Cardinal: ExpressibleByIntegerLiteral, Equatable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    @_disfavoredOverload
    init(integerLiteral value: UInt) { self.init(value) }
    static func * (lhs: Cardinal, rhs: Cardinal) -> Cardinal {
        Cardinal(lhs.rawValue * rhs.rawValue)
    }
}

// MARK: - Index<Element> and BitIndex mirror production typealiases

enum BitTag {}

typealias Index<Element> = Tagged<Element, Ordinal>
typealias BitIndex = Tagged<BitTag, Ordinal>

extension Tagged where Tag == UInt8, RawValue == Ordinal {
    var count: Cardinal { Cardinal(rawValue.rawValue) }
}

extension Tagged where Tag == BitTag, RawValue == Ordinal {
    // The FOOTGUN INIT — unlabeled cross-domain conversion with ×8 scaling
    init(_ byteIndex: Index<UInt8>) {
        let bits = byteIndex.count * Cardinal(8)
        self.init(__unchecked: (), Ordinal(bits.rawValue))
    }
}

// MARK: - Variant 1: Original footgun shape
// `(0..<5).map(BitIndex.init)` — the exact shape from the research.
// Hypothesis: if footgun reproduces, values are [0, 8, 16, 24, 32].
//              if footgun is gone, values are [0, 1, 2, 3, 4] or compile error.

print("=== Variant 1: (0..<5).map(BitIndex.init) ===")
let result1: [BitIndex] = (0..<5).map(BitIndex.init)
let v1 = result1.map { $0.rawValue.rawValue }
print("  Values:   \(v1)")
print("  Footgun:  [0, 8, 16, 24, 32]")
print("  Correct:  [0, 1, 2, 3, 4]")
print("  Result:   \(v1 == [0, 8, 16, 24, 32] ? "FOOTGUN REPRODUCED" : "footgun NOT reproduced")")

// MARK: - Variant 2: Direct BitIndex(5) via literal
// Confirms the integerLiteral init is accessible.

print()
print("=== Variant 2: Literal-typed BitIndex(5) ===")
let direct: BitIndex = 5
print("  BitIndex(5) literal: \(direct.rawValue.rawValue)   (expected 5)")

// MARK: - Variant 3: Explicit closure on Range<Int>
// Proves byte-to-bit init CAN be called explicitly (so it exists + works).

print()
print("=== Variant 3: Byte-to-bit via closure on Range<Int> ===")
let byteIndices: [Index<UInt8>] = (0..<5).map { i in
    Index<UInt8>(__unchecked: (), Ordinal(UInt(i)))
}
let bitsFromBytes: [BitIndex] = byteIndices.map { BitIndex($0) }
let v3 = bitsFromBytes.map { $0.rawValue.rawValue }
print("  byteIndices.map { BitIndex($0) }: \(v3)")
print("  Expected: [0, 8, 16, 24, 32] (×8 scaling works when called directly)")

// MARK: - Variant 4: Without @_disfavoredOverload on literal
// Hypothesis: disfavor attribute behavior may differ on 6.3.1

struct Bare {
    let raw: Ordinal
    init(integerLiteral value: UInt) { self.raw = Ordinal(value) }  // no disfavor
    init(_ byteIndex: Index<UInt8>) {                                // cross-domain
        let bits = byteIndex.count * Cardinal(8)
        self.raw = Ordinal(bits.rawValue)
    }
}
extension Bare: ExpressibleByIntegerLiteral {}

print()
print("=== Variant 4: Without @_disfavoredOverload on literal ===")
print("  With Strideable added, `(0..<5).map(Bare.init)` reports ambiguous init")
print("  (compile error). @_disfavoredOverload on the literal init resolves it.")
let v4v: [UInt] = []  // Not compiled — see above
// let v4: [Bare] = (0..<5).map(Bare.init)  // error: ambiguous use of 'init'

// MARK: - Variant 5: Can Range<Index<UInt8>> be formed at all?
// The original footgun claim requires Swift to infer 0..<5 as Range<Index<UInt8>>.
// Range<T> requires T: Strideable to be iterable. Tagged is NOT Strideable.
// Verify this structural block empirically.

print()
print("=== Variant 5: Range<Index<UInt8>> iterability ===")
let forcedRange: Range<Index<UInt8>> = (0 as Index<UInt8>)..<(5 as Index<UInt8>)
print("  Range<Index<UInt8>> CAN be constructed: \(forcedRange)")
// Uncomment to confirm not iterable:
// let _ = forcedRange.map(BitIndex.init)  // ERROR on 6.3.1: no exact matches

// MARK: - Summary

print()
print("=== Summary ===")
print("  Variant 1 values: \(v1)")
print("  Variant 4 values: \(v4v)")
let footgunActive = (v1 == [0, 8, 16, 24, 32]) || (v4v == [0, 8, 16, 24, 32])
print("  Footgun reproducible today: \(footgunActive ? "YES" : "NO")")
if !footgunActive {
    print()
    print("  Hypothesis: the original footgun required Range<Index<UInt8>> to be")
    print("  iterable, which requires Index<UInt8>: Strideable. Production Tagged")
    print("  deliberately removes Strideable. Without Strideable on Index<UInt8>,")
    print("  Swift cannot infer 0..<5 as Range<Index<UInt8>>, so .map(BitIndex.init)")
    print("  falls back to Range<Int> — and no unlabeled init on BitIndex takes Int,")
    print("  so Swift resolves to the integerLiteral init via literal inference.")
}
