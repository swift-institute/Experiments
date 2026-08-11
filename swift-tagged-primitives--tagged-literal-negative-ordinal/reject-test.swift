// MARK: - Rejection Test: Negative Ordinal Literal
// Purpose:  Verify that Tagged<SomeTag, Ordinal> = -100 is a compile-time error.
// Hypothesis: Compile error because IntegerLiteralType = UInt rejects negative.
//
// This file is NOT compiled as part of the package. It is compiled standalone:
//   swiftc -typecheck reject-test.swift.txt
//
// Result: <PENDING>

struct Tagged<Tag, RawValue> {
    var rawValue: RawValue
    init(__unchecked: Void, _ rawValue: RawValue) { self.rawValue = rawValue }
}
extension Tagged: ExpressibleByIntegerLiteral
where RawValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: RawValue.IntegerLiteralType) {
        self.init(__unchecked: (), RawValue(integerLiteral: value))
    }
}

struct Ordinal: ExpressibleByIntegerLiteral {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    init(integerLiteral value: UInt) { self.init(value) }
}

struct Cardinal: ExpressibleByIntegerLiteral {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    init(integerLiteral value: UInt) { self.init(value) }
}

enum SomeTag {}

// These lines should ALL fail to compile:
let bad1: Tagged<SomeTag, Ordinal> = -100    // Negative Ordinal
let bad2: Tagged<SomeTag, Cardinal> = -1     // Negative Cardinal
let bad3: Tagged<SomeTag, Ordinal> = -1      // Negative Ordinal (small)
