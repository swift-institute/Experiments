// MARK: - Canonical + Witness Capability Attachment
// Purpose: Validate that protocol canonical + witness alternatives pattern works:
//          - Parseable/Serializable/Codable protocols with single canonical
//          - Additional witness properties for alternatives
//          - Generic constrainability via protocols
//          - Codable shadowing stdlib
//          - Multiple protocol conformances on same type
//          - Parameterized witness factories
//
// Hypothesis: All 10 variants compile and produce correct results
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — 10/10 variants pass
// Date: 2026-03-04

// ============================================================================
// MARK: - Simulated Protocol Definitions
// ============================================================================

// Simulated Parser.Protocol (minimal — just the contract)
enum Parser {}
extension Parser {
    protocol `Protocol` {
        associatedtype Input
        associatedtype Output
        associatedtype Failure: Error & Sendable
        func parse(_ input: inout Input) throws(Failure) -> Output
    }
}

// Simulated Serializer.Protocol
enum Serializer {}
extension Serializer {
    protocol `Protocol` {
        associatedtype Output
        associatedtype Buffer
        associatedtype Failure: Error & Sendable
        func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure)
    }
}

// Simulated Coder.Protocol (separate failure types)
enum Coder {}
extension Coder {
    protocol `Protocol` {
        associatedtype DecodeInput
        associatedtype EncodeBuffer
        associatedtype Output
        associatedtype DecodeFailure: Error & Sendable
        associatedtype EncodeFailure: Error & Sendable
        func decode(_ input: inout DecodeInput) throws(DecodeFailure) -> Output
        func encode(_ output: Output, into buffer: inout EncodeBuffer) throws(EncodeFailure)
    }
}

// ============================================================================
// MARK: - Associated-Type Protocols (Canonical)
// ============================================================================

protocol Parseable {
    associatedtype ValueParser: Parser.`Protocol`
    static var parser: ValueParser { get }
}

protocol Serializable {
    associatedtype ValueSerializer: Serializer.`Protocol`
    static var serializer: ValueSerializer { get }
}

// Shadows stdlib Codable
protocol Codable {
    associatedtype ValueCoder: Coder.`Protocol`
    static var coder: ValueCoder { get }
}

// ============================================================================
// MARK: - Concrete Implementations
// ============================================================================

enum ParseError: Error, Sendable {
    case invalidInput
    case unexpectedEnd
}

enum SerializeError: Error, Sendable {
    case bufferFull
}

// A simple parser that reads a UInt32 from 4 bytes (little-endian)
struct LEUInt32Parser: Parser.`Protocol` {
    typealias Input = ArraySlice<UInt8>
    typealias Output = UInt32
    typealias Failure = ParseError

    func parse(_ input: inout ArraySlice<UInt8>) throws(ParseError) -> UInt32 {
        guard input.count >= 4 else { throw .unexpectedEnd }
        let b0 = UInt32(input[input.startIndex])
        let b1 = UInt32(input[input.startIndex + 1])
        let b2 = UInt32(input[input.startIndex + 2])
        let b3 = UInt32(input[input.startIndex + 3])
        input = input.dropFirst(4)
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }
}

// A big-endian parser (alternative witness)
struct BEUInt32Parser: Parser.`Protocol` {
    typealias Input = ArraySlice<UInt8>
    typealias Output = UInt32
    typealias Failure = ParseError

    func parse(_ input: inout ArraySlice<UInt8>) throws(ParseError) -> UInt32 {
        guard input.count >= 4 else { throw .unexpectedEnd }
        let b0 = UInt32(input[input.startIndex])
        let b1 = UInt32(input[input.startIndex + 1])
        let b2 = UInt32(input[input.startIndex + 2])
        let b3 = UInt32(input[input.startIndex + 3])
        input = input.dropFirst(4)
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }
}

// A simple serializer
struct LEUInt32Serializer: Serializer.`Protocol` {
    typealias Output = UInt32
    typealias Buffer = [UInt8]
    typealias Failure = Never

    func serialize(_ output: UInt32, into buffer: inout [UInt8]) throws(Never) {
        buffer.append(UInt8(truncatingIfNeeded: output))
        buffer.append(UInt8(truncatingIfNeeded: output >> 8))
        buffer.append(UInt8(truncatingIfNeeded: output >> 16))
        buffer.append(UInt8(truncatingIfNeeded: output >> 24))
    }
}

// A bidirectional coder (little-endian)
struct LEUInt32Coder: Coder.`Protocol` {
    typealias DecodeInput = ArraySlice<UInt8>
    typealias EncodeBuffer = [UInt8]
    typealias Output = UInt32
    typealias DecodeFailure = ParseError
    typealias EncodeFailure = Never

    func decode(_ input: inout ArraySlice<UInt8>) throws(ParseError) -> UInt32 {
        guard input.count >= 4 else { throw .unexpectedEnd }
        let b0 = UInt32(input[input.startIndex])
        let b1 = UInt32(input[input.startIndex + 1])
        let b2 = UInt32(input[input.startIndex + 2])
        let b3 = UInt32(input[input.startIndex + 3])
        input = input.dropFirst(4)
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    func encode(_ output: UInt32, into buffer: inout [UInt8]) throws(Never) {
        buffer.append(UInt8(truncatingIfNeeded: output))
        buffer.append(UInt8(truncatingIfNeeded: output >> 8))
        buffer.append(UInt8(truncatingIfNeeded: output >> 16))
        buffer.append(UInt8(truncatingIfNeeded: output >> 24))
    }
}

// Big-endian coder (alternative)
struct BEUInt32Coder: Coder.`Protocol` {
    typealias DecodeInput = ArraySlice<UInt8>
    typealias EncodeBuffer = [UInt8]
    typealias Output = UInt32
    typealias DecodeFailure = ParseError
    typealias EncodeFailure = Never

    func decode(_ input: inout ArraySlice<UInt8>) throws(ParseError) -> UInt32 {
        guard input.count >= 4 else { throw .unexpectedEnd }
        let b0 = UInt32(input[input.startIndex])
        let b1 = UInt32(input[input.startIndex + 1])
        let b2 = UInt32(input[input.startIndex + 2])
        let b3 = UInt32(input[input.startIndex + 3])
        input = input.dropFirst(4)
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    func encode(_ output: UInt32, into buffer: inout [UInt8]) throws(Never) {
        buffer.append(UInt8(truncatingIfNeeded: output >> 24))
        buffer.append(UInt8(truncatingIfNeeded: output >> 16))
        buffer.append(UInt8(truncatingIfNeeded: output >> 8))
        buffer.append(UInt8(truncatingIfNeeded: output))
    }
}

// ASCII decimal parser (alternative witness — different format entirely)
struct ASCIIDecimalUInt32Parser: Parser.`Protocol` {
    typealias Input = ArraySlice<UInt8>
    typealias Output = UInt32
    typealias Failure = ParseError

    func parse(_ input: inout ArraySlice<UInt8>) throws(ParseError) -> UInt32 {
        var value: UInt32 = 0
        var consumed = false
        while let byte = input.first, byte >= 0x30, byte <= 0x39 {
            value = value &* 10 &+ UInt32(byte - 0x30)
            input = input.dropFirst()
            consumed = true
        }
        guard consumed else { throw .invalidInput }
        return value
    }
}

// ============================================================================
// MARK: - V1: Basic Parseable conformance
// Hypothesis: Associated-type protocol with Parser.Protocol constraint compiles
// Result: CONFIRMED
// ============================================================================

extension UInt32: Parseable {
    static var parser: LEUInt32Parser { LEUInt32Parser() }
}

func testV1() {
    var input: ArraySlice<UInt8> = [0x78, 0x56, 0x34, 0x12][...]
    let value = try! UInt32.parser.parse(&input)
    assert(value == 0x12345678, "V1: Expected 0x12345678, got \(value)")
    print("V1: CONFIRMED — Parseable conformance works, parsed \(String(value, radix: 16))")
}

// ============================================================================
// MARK: - V2: Generic function constrained on Parseable
// Hypothesis: func f<T: Parseable>() compiles and dispatches correctly
// Result: CONFIRMED
// ============================================================================

func parseCanonical<T: Parseable>(
    _ type: T.Type,
    from input: inout T.ValueParser.Input
) throws(T.ValueParser.Failure) -> T.ValueParser.Output {
    try T.parser.parse(&input)
}

func testV2() {
    var input: ArraySlice<UInt8> = [0x78, 0x56, 0x34, 0x12][...]
    let value: UInt32 = try! parseCanonical(UInt32.self, from: &input)
    assert(value == 0x12345678, "V2: Expected 0x12345678")
    print("V2: CONFIRMED — Generic Parseable constraint works, parsed \(String(value, radix: 16))")
}

// ============================================================================
// MARK: - V3: Canonical + witness alternatives on same type
// Hypothesis: Protocol conformance (canonical) and additional static properties
//             (alternatives) coexist without conflict
// Result: CONFIRMED
// ============================================================================

extension UInt32 {
    // Alternative witnesses — NOT part of Parseable, just static properties
    static var bigEndianParser: BEUInt32Parser { BEUInt32Parser() }
    static var asciiDecimalParser: ASCIIDecimalUInt32Parser { ASCIIDecimalUInt32Parser() }
}

func testV3() {
    // Canonical (via protocol)
    var input1: ArraySlice<UInt8> = [0x78, 0x56, 0x34, 0x12][...]
    let canonical = try! UInt32.parser.parse(&input1)

    // Alternative: big-endian (via witness property)
    var input2: ArraySlice<UInt8> = [0x12, 0x34, 0x56, 0x78][...]
    let bigEndian = try! UInt32.bigEndianParser.parse(&input2)

    // Alternative: ASCII decimal (via witness property)
    var input3: ArraySlice<UInt8> = Array("305419896".utf8)[...]
    let ascii = try! UInt32.asciiDecimalParser.parse(&input3)

    assert(canonical == bigEndian && bigEndian == ascii,
           "V3: All three should produce same value")
    print("V3: CONFIRMED — Canonical (\(String(canonical, radix: 16))) + " +
          "BE (\(String(bigEndian, radix: 16))) + " +
          "ASCII (\(ascii)) coexist")
}

// ============================================================================
// MARK: - V4: Serializable conformance
// Hypothesis: Serializable protocol works identically to Parseable
// Result: CONFIRMED
// ============================================================================

extension UInt32: Serializable {
    static var serializer: LEUInt32Serializer { LEUInt32Serializer() }
}

func testV4() {
    var buffer: [UInt8] = []
    try! UInt32.serializer.serialize(0x12345678, into: &buffer)
    assert(buffer == [0x78, 0x56, 0x34, 0x12], "V4: Wrong bytes")
    print("V4: CONFIRMED — Serializable conformance works, serialized \(buffer)")
}

// ============================================================================
// MARK: - V5: Codable shadowing stdlib
// Hypothesis: Our Codable protocol shadows Swift.Codable without conflict
// Result: CONFIRMED
// ============================================================================

extension UInt32: Codable {
    static var coder: LEUInt32Coder { LEUInt32Coder() }
}

func testV5() {
    // Our Codable
    var input: ArraySlice<UInt8> = [0x78, 0x56, 0x34, 0x12][...]
    let decoded = try! UInt32.coder.decode(&input)

    var buffer: [UInt8] = []
    try! UInt32.coder.encode(0x12345678, into: &buffer)

    assert(decoded == 0x12345678, "V5: decode failed")
    assert(buffer == [0x78, 0x56, 0x34, 0x12], "V5: encode failed")
    print("V5: CONFIRMED — Our Codable shadows stdlib, decode=\(String(decoded, radix: 16)), encode=\(buffer)")
}

// ============================================================================
// MARK: - V6: Type conforming to ALL THREE protocols
// Hypothesis: A type can conform to Parseable, Serializable, and Codable simultaneously
// Result: CONFIRMED
// ============================================================================

func testV6() {
    // UInt32 already conforms to all three (V1 + V4 + V5)
    func requireAll<T: Parseable & Serializable & Codable>(_ type: T.Type) {
        print("V6: CONFIRMED — \(T.self) conforms to Parseable & Serializable & Codable")
    }
    requireAll(UInt32.self)
}

// ============================================================================
// MARK: - V7: Coder with separate failure types (decode throws, encode Never)
// Hypothesis: Coder.Protocol with DecodeFailure != EncodeFailure compiles
// Result: CONFIRMED
// ============================================================================

func testV7() {
    // LEUInt32Coder has DecodeFailure = ParseError, EncodeFailure = Never
    // Verify encode truly can't fail (no try needed)
    var buffer: [UInt8] = []
    UInt32.coder.encode(42, into: &buffer)  // No try! needed — EncodeFailure == Never
    assert(buffer.count == 4, "V7: Expected 4 bytes")
    print("V7: CONFIRMED — Separate failure types work (encode is Never, no try needed)")
}

// ============================================================================
// MARK: - V8: Generic code uses canonical, specific code uses alternative
// Hypothesis: Generic function uses Parseable canonical; call site can also use
//             witness alternatives — both work side by side
// Result: CONFIRMED
// ============================================================================

func testV8() {
    // Generic path (canonical)
    var input1: ArraySlice<UInt8> = [0x78, 0x56, 0x34, 0x12][...]
    let fromGeneric: UInt32 = try! parseCanonical(UInt32.self, from: &input1)

    // Specific path (alternative witness)
    var input2: ArraySlice<UInt8> = [0x12, 0x34, 0x56, 0x78][...]
    let fromAlternative = try! UInt32.bigEndianParser.parse(&input2)

    assert(fromGeneric == fromAlternative, "V8: Both should give same value")
    print("V8: CONFIRMED — Generic canonical (\(String(fromGeneric, radix: 16))) " +
          "and specific alternative (\(String(fromAlternative, radix: 16))) coexist")
}

// ============================================================================
// MARK: - V9: Codable alternative witnesses (parameterized factory)
// Hypothesis: Type can have canonical coder + parameterized factory for alternatives
// Result: CONFIRMED
// ============================================================================

enum Endianness { case little, big }

extension UInt32 {
    static func coder(endianness: Endianness) -> any Coder.`Protocol` {
        switch endianness {
        case .little: return LEUInt32Coder()
        case .big: return BEUInt32Coder()
        }
    }
}

func testV9() {
    let leCoder = UInt32.coder(endianness: .little) as! LEUInt32Coder
    let beCoder = UInt32.coder(endianness: .big) as! BEUInt32Coder

    var leInput: ArraySlice<UInt8> = [0x78, 0x56, 0x34, 0x12][...]
    var beInput: ArraySlice<UInt8> = [0x12, 0x34, 0x56, 0x78][...]
    let leValue = try! leCoder.decode(&leInput)
    let beValue = try! beCoder.decode(&beInput)

    assert(leValue == beValue, "V9: Both should decode to same value")
    print("V9: CONFIRMED — Parameterized factory works, LE=\(String(leValue, radix: 16)) BE=\(String(beValue, radix: 16))")
}

// ============================================================================
// MARK: - V10: Swift.Codable still accessible when shadowed
// Hypothesis: stdlib Codable is accessible as Swift.Codable when our Codable shadows it
// Result: CONFIRMED
// ============================================================================

struct StdlibCodableType: Swift.Codable {
    var value: Int
}

func testV10() {
    // Verify Swift.Codable still works
    let encoder = JSONEncoder()
    let data = try! encoder.encode(StdlibCodableType(value: 42))
    let decoded = try! JSONDecoder().decode(StdlibCodableType.self, from: data)
    assert(decoded.value == 42, "V10: Round-trip failed")
    print("V10: CONFIRMED — Swift.Codable accessible via qualification, value=\(decoded.value)")
}

// ============================================================================
// MARK: - Run All
// ============================================================================

import Foundation  // Only for V10 (JSONEncoder/JSONDecoder — stdlib Codable test)

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()
testV7()
testV8()
testV9()
testV10()

print("\n// MARK: - Results Summary")
print("// V1:  Parseable conformance")
print("// V2:  Generic Parseable constraint")
print("// V3:  Canonical + witness alternatives coexistence")
print("// V4:  Serializable conformance")
print("// V5:  Our Codable shadows stdlib")
print("// V6:  Triple conformance (Parseable & Serializable & Codable)")
print("// V7:  Separate failure types (EncodeFailure = Never)")
print("// V8:  Generic canonical + specific alternative side by side")
print("// V9:  Parameterized coder factory")
print("// V10: Swift.Codable still accessible when shadowed")
