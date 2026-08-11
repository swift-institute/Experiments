// MARK: - Tagged Literal Negative Ordinal Verification
// Purpose:  Verify that blanket ExpressibleByIntegerLiteral on Tagged
//           rejects negative literals when RawValue is UInt-backed (Ordinal/Cardinal).
// Hypothesis: Tagged<Tag, Ordinal> = -100 is a compile-time error because
//             IntegerLiteralType chains to UInt, which rejects negative literals.
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT
// Platform:  macOS 26.0 (arm64)
//
// Result: CONFIRMED — negative literals rejected for UInt-backed Tagged types.
//         Compiler emits: "negative integer '-100' overflows when stored into
//         unsigned type 'Tagged<SomeTag, Ordinal>'"
//         See reject-test.swift.txt for the rejected code (compiled standalone).
// Date:   2026-02-09

// ============================================================================
// Minimal reproductions
// ============================================================================

struct Tagged<Tag, RawValue> {
    var rawValue: RawValue
    init(__unchecked: Void, _ rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

// Blanket conformance under test
extension Tagged: ExpressibleByIntegerLiteral
where RawValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: RawValue.IntegerLiteralType) {
        self.init(__unchecked: (), RawValue(integerLiteral: value))
    }
}

extension Tagged: ExpressibleByFloatLiteral
where RawValue: ExpressibleByFloatLiteral {
    init(floatLiteral value: RawValue.FloatLiteralType) {
        self.init(__unchecked: (), RawValue(floatLiteral: value))
    }
}

// Minimal Ordinal (UInt-backed, mirrors production)
struct Ordinal: ExpressibleByIntegerLiteral {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    init(integerLiteral value: UInt) { self.init(value) }
}

// Minimal Cardinal (UInt-backed, mirrors production)
struct Cardinal: ExpressibleByIntegerLiteral {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    init(integerLiteral value: UInt) { self.init(value) }
}

enum SomeTag {}

// MARK: - Variant 1: Positive literal with Ordinal
// Hypothesis: Tagged<SomeTag, Ordinal> = 5 compiles
// Result: CONFIRMED — Output: 5

let v1: Tagged<SomeTag, Ordinal> = 5
print("V1 - Ordinal positive literal: \(v1.rawValue.rawValue)")

// MARK: - Variant 2: Positive literal with Cardinal
// Hypothesis: Tagged<SomeTag, Cardinal> = 10 compiles
// Result: CONFIRMED — Output: 10

let v2: Tagged<SomeTag, Cardinal> = 10
print("V2 - Cardinal positive literal: \(v2.rawValue.rawValue)")

// MARK: - Variant 3: Zero literal with Ordinal
// Hypothesis: Tagged<SomeTag, Ordinal> = 0 compiles (common default)
// Result: CONFIRMED — Output: 0

let v3: Tagged<SomeTag, Ordinal> = 0
print("V3 - Ordinal zero literal: \(v3.rawValue.rawValue)")

// MARK: - Variant 4: Double-backed literal (the ViewBox case)
// Hypothesis: Tagged<SomeTag, Double> = 0 compiles
// Result: CONFIRMED — Output: 0.0

let v4: Tagged<SomeTag, Double> = 0
print("V4 - Double zero literal: \(v4.rawValue)")

// MARK: - Variant 5: Float literal for Double-backed
// Hypothesis: Tagged<SomeTag, Double> = 3.14 compiles via ExpressibleByFloatLiteral
// Result: CONFIRMED — Output: 3.14

let v5: Tagged<SomeTag, Double> = 3.14
print("V5 - Double float literal: \(v5.rawValue)")

// MARK: - Variant 6: Int-backed with negative (permitted — Int allows negatives)
// Hypothesis: Tagged<SomeTag, Int> = -100 compiles (Int accepts negative literals)
// Result: CONFIRMED — Output: -100

let v6: Tagged<SomeTag, Int> = -100
print("V6 - Int negative literal: \(v6.rawValue)")

// MARK: - Variant 7: Negative Ordinal literal (MUST BE REJECTED)
// Hypothesis: Tagged<SomeTag, Ordinal> = -100 is a compile-time error
// Result: CONFIRMED — Compile error:
//   "negative integer '-100' overflows when stored into unsigned type 'Tagged<SomeTag, Ordinal>'"
// Evidence: See reject-test.swift.txt (standalone compilation test)
//
// NOT included here because it would prevent this file from compiling.
// Tested via: swiftc reject-test.swift.txt

// MARK: - Variant 8: Negative Cardinal literal (MUST BE REJECTED)
// Hypothesis: Tagged<SomeTag, Cardinal> = -1 is a compile-time error
// Result: CONFIRMED — Compile error:
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   "negative integer '-1' overflows when stored into unsigned type 'Tagged<SomeTag, Cardinal>'"
// Evidence: See reject-test.swift.txt (standalone compilation test)

// MARK: - Results Summary
// V1: CONFIRMED — Ordinal positive literal accepted
// V2: CONFIRMED — Cardinal positive literal accepted
// V3: CONFIRMED — Ordinal zero literal accepted
// V4: CONFIRMED — Double integer literal accepted
// V5: CONFIRMED — Double float literal accepted
// V6: CONFIRMED — Int negative literal accepted (Int allows negatives)
// V7: CONFIRMED — Ordinal negative literal REJECTED at compile time
// V8: CONFIRMED — Cardinal negative literal REJECTED at compile time
//
// Conclusion: IntegerLiteralType cascades correctly through Tagged.
//   UInt-backed types (Ordinal, Cardinal) reject negative literals.
//   Int-backed types accept them (as Int itself does).
//   The blanket conformance preserves the RawValue's safety properties.
