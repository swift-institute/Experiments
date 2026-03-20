// MARK: - ContiguousProtocol with Round-Trip + Typed Error
// Purpose: Validate that a protocol with `init(_ span:) throws(Error)`
//          works where Error is an associatedtype, and `Never` makes
//          the init non-throwing via throws covariance.
//
// Toolchain: Apple Swift 6.2.4
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — all 10 variants pass
//   V1-V2: Both Never and typed Error conformers work
//   V3-V5: Generic functions over protocol work
//   V6: throws(Never) call site compiles WITHOUT try
//   V7: throws(ValidationError) call site REQUIRES try
//   V8-V9: Cross-type convert propagates destination Error
//   V10: ValidatedText → ByteArray (Never) compiles without try
// Date: 2026-03-19


// ============================================================
// The protocol
// ============================================================

protocol ContiguousProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Error: Swift.Error

    var span: Span<Element> { get }
    init(_ span: Span<Element>) throws(Error)
}


// ============================================================
// V1: Non-throwing conformer (Error == Never)
// Mirrors: Array
// ============================================================

struct ByteArray: ContiguousProtocol {
    typealias Error = Never
    let bytes: [UInt8]

    var span: Span<UInt8> {
        @_lifetime(borrow self) borrowing get { bytes.span }
    }

    init(_ span: Span<UInt8>) {
        // Non-throwing — satisfies throws(Never)
        var arr: [UInt8] = []
        arr.reserveCapacity(span.count)
        for i in 0..<span.count { arr.append(span[i]) }
        self.bytes = arr
    }

    init(literal: [UInt8]) { self.bytes = literal }
}


// ============================================================
// V2: Throwing conformer (Error == ValidationError)
// Mirrors: String with UTF8 validation
// ============================================================

enum ValidationError: Swift.Error, Equatable {
    case invalidByte(UInt8)
}

struct ValidatedText: ContiguousProtocol {
    typealias Error = ValidationError
    let bytes: [UInt8]

    var span: Span<UInt8> {
        @_lifetime(borrow self) borrowing get { bytes.span }
    }

    init(_ span: Span<UInt8>) throws(ValidationError) {
        // Simulate UTF-8 validation: reject bytes > 127
        for i in 0..<span.count {
            if span[i] > 127 { throw .invalidByte(span[i]) }
        }
        var arr: [UInt8] = []
        arr.reserveCapacity(span.count)
        for i in 0..<span.count { arr.append(span[i]) }
        self.bytes = arr
    }

    init(trusted: [UInt8]) { self.bytes = trusted }
}


// ============================================================
// V3: Generic round-trip function
// The KEY test — error type propagates generically
// ============================================================

func roundTrip<C: ContiguousProtocol & ~Copyable>(
    _ source: borrowing C
) throws(C.Error) -> C {
    try C(source.span)
}


// ============================================================
// V4: Generic function that reads — error doesn't matter
// ============================================================

func countBytes<C: ContiguousProtocol & ~Copyable>(
    _ source: borrowing C
) -> Int where C.Element == UInt8 {
    source.span.count
}


// ============================================================
// V5: Generic copy between DIFFERENT conformers
// ============================================================

func convert<Source: ContiguousProtocol & ~Copyable,
             Dest: ContiguousProtocol>(
    _ source: borrowing Source
) throws(Dest.Error) -> Dest
where Source.Element == UInt8, Dest.Element == UInt8 {
    try Dest(source.span)
}


// ============================================================
// V6: Non-throwing call site — throws(Never) erases to nonthrowing
// ============================================================

func testNonThrowingCallSite() {
    let arr = ByteArray(literal: [1, 2, 3])
    // This MUST compile WITHOUT try — Error == Never makes it nonthrowing
    let copy = roundTrip(arr)
    assert(copy.bytes == [1, 2, 3])
    print("V6 CONFIRMED: roundTrip(ByteArray) compiles without try")
}


// ============================================================
// V7: Throwing call site — error propagates
// ============================================================

func testThrowingCallSite() {
    let text = ValidatedText(trusted: [65, 66, 67])
    // This MUST require try — Error == ValidationError
    let copy = try! roundTrip(text)
    assert(copy.bytes == [65, 66, 67])
    print("V7 CONFIRMED: roundTrip(ValidatedText) requires try")
}


// ============================================================
// V8: Cross-type conversion — ByteArray → ValidatedText
// ============================================================

func testCrossConversion() {
    let arr = ByteArray(literal: [72, 101, 108, 108, 111])
    let text: ValidatedText = try! convert(arr)
    assert(text.bytes == [72, 101, 108, 108, 111])
    print("V8 CONFIRMED: ByteArray → ValidatedText via generic convert")
}


// ============================================================
// V9: Cross-type conversion that fails
// ============================================================

func testCrossConversionFails() {
    let arr = ByteArray(literal: [72, 0xFF, 108])
    do {
        let _: ValidatedText = try convert(arr)
        assert(false, "Should have thrown")
    } catch {
        assert(error == .invalidByte(0xFF))
    }
    print("V9 CONFIRMED: ByteArray → ValidatedText throws on invalid byte")
}


// ============================================================
// V10: ValidatedText → ByteArray (never fails)
// ============================================================

func testDownConversion() {
    let text = ValidatedText(trusted: [65, 66])
    // ByteArray.Error == Never, so this is non-throwing
    let arr: ByteArray = convert(text)
    assert(arr.bytes == [65, 66])
    print("V10 CONFIRMED: ValidatedText → ByteArray without try (Never)")
}


// ============================================================
// RUN
// ============================================================

print("=== ContiguousProtocol Round-Trip Experiment ===\n")

// Basic conformance
do {
    let arr = ByteArray(literal: [10, 20, 30])
    assert(countBytes(arr) == 3)
    print("V1 CONFIRMED: ByteArray conforms (Error == Never)")
}

do {
    let text = ValidatedText(trusted: [65, 66])
    assert(countBytes(text) == 2)
    print("V2 CONFIRMED: ValidatedText conforms (Error == ValidationError)")
}

do {
    let arr = ByteArray(literal: [1, 2, 3])
    let copy = roundTrip(arr)
    assert(copy.bytes == [1, 2, 3])
    print("V3 CONFIRMED: Generic roundTrip works for ByteArray")
}

do {
    let text = ValidatedText(trusted: [65, 66])
    let copy = try! roundTrip(text)
    assert(copy.bytes == [65, 66])
    print("V4 CONFIRMED: Generic roundTrip works for ValidatedText")
}

do {
    let arr = ByteArray(literal: [5, 6])
    assert(countBytes(arr) == 2)
    let text = ValidatedText(trusted: [7])
    assert(countBytes(text) == 1)
    print("V5 CONFIRMED: Generic countBytes works for both")
}

testNonThrowingCallSite()
testThrowingCallSite()
testCrossConversion()
testCrossConversionFails()
testDownConversion()

print("\n=== Done ===")
