// MARK: - Suppressed Associated Types for ~Escapable
// Purpose: Verify whether SuppressedAssociatedTypes enables ~Escapable
//          constraints on associated types, not just ~Copyable.
//          If confirmed, Parser.Protocol could declare `associatedtype Input: ~Escapable`
//          allowing Span<UInt8> directly as parser input.
//
// Hypothesis:
//   H1: `associatedtype Input: ~Escapable` compiles with SuppressedAssociatedTypes
//   H2: A conformer with a ~Escapable Input type (e.g. Span) can satisfy the constraint
//   H3: A conformer with a standard Escapable Input type still works (Escapable < ~Escapable)
//   H4: Combined `~Copyable & ~Escapable` suppression on a single associated type compiles
//   H5: `inout Input` works when Input: ~Escapable (matching Parser.Protocol.parse signature)
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — H1-H5 all pass. ~Escapable works on associated types.
//   V6 (returning ~Escapable from protocol method) is REFUTED — language limitation.
// Output:
//   V2 String parser: Optional("h")
//   V3 Byte parser:   Optional(72)
//   V4 Int processor: 42
//   V5 canParse:      true
//   V7 inout parser:  65 (remaining: 1)
// Date: 2026-02-13

// =============================================================================
// MARK: - Variant 1: Basic ~Escapable associated type
// =============================================================================
// Hypothesis: `associatedtype Input: ~Escapable` compiles
// Result: CONFIRMED — compiles with SuppressedAssociatedTypes flag

protocol ParserV1: ~Copyable {
    associatedtype Input: ~Escapable
    associatedtype Output
    mutating func parse(_ input: borrowing Input) -> Output?
}

// =============================================================================
// MARK: - Variant 2: Escapable conformer (String satisfies ~Escapable)
// =============================================================================
// Hypothesis: Standard Escapable types satisfy the ~Escapable constraint
// Result: CONFIRMED — String satisfies Input: ~Escapable (Escapable < ~Escapable)

struct StringParserV2: ParserV1 {
    typealias Input = String
    typealias Output = Character

    mutating func parse(_ input: borrowing String) -> Character? {
        input.first
    }
}

// =============================================================================
// MARK: - Variant 3: ~Escapable conformer using Span
// =============================================================================
// Hypothesis: Span<UInt8> (which is ~Escapable) satisfies `Input: ~Escapable`
// Result: CONFIRMED — Span<UInt8> satisfies Input: ~Escapable, parse works at runtime

struct ByteParserV3: ParserV1 {
    typealias Input = Span<UInt8>
    typealias Output = UInt8

    mutating func parse(_ input: borrowing Span<UInt8>) -> UInt8? {
        input.isEmpty ? nil : input[0]
    }
}

// =============================================================================
// MARK: - Variant 4: Combined ~Copyable & ~Escapable on single associated type
// =============================================================================
// Hypothesis: Both suppressions can coexist on one associated type
// Result: CONFIRMED — `Value: ~Copyable & ~Escapable` compiles and works
// Finding: With legacy SuppressedAssociatedTypes, Value is ALWAYS ~Copyable
//          AND ~Escapable, so `borrowing` + `copy` needed for Copyable conformers.

protocol ProcessorV4: ~Copyable {
    associatedtype Value: ~Copyable & ~Escapable
    func process(_ value: borrowing Value) -> Int
}

struct IntProcessor: ProcessorV4 {
    typealias Value = Int
    func process(_ value: borrowing Int) -> Int { copy value }
}

// =============================================================================
// MARK: - Variant 5: Protocol extension with ~Escapable element
// =============================================================================
// Hypothesis: Protocol extensions can provide defaults using ~Escapable associated types
// Result: CONFIRMED — default method using `borrowing Input` works in extension

extension ParserV1 {
    mutating func canParse(_ input: borrowing Input) -> Bool {
        parse(input) != nil
    }
}

// =============================================================================
// MARK: - Variant 6: ~Escapable return type from protocol method
// =============================================================================
// Hypothesis: A protocol method can return a ~Escapable value derived from input
// Result: REFUTED — "a method cannot return a ~Escapable result"
//   Swift 6.2.3 does not support ~Escapable return types from protocol methods.
//   The associatedtype declaration itself compiles (V1 confirmed), but using a
//   ~Escapable associated type as a return type does not.
//   This limits ~Escapable associated types to borrowing/inout parameter position.
//
// protocol SlicerV6: ~Copyable {
//     associatedtype Input: ~Escapable
//     associatedtype Slice: ~Escapable
//     func slice(_ input: borrowing Input) -> Slice
//                                             ^ error: a method cannot return a ~Escapable result
// }

// =============================================================================
// MARK: - Variant 7: inout with ~Escapable associated type (Parser.Protocol shape)
// =============================================================================
// Hypothesis: `func parse(_ input: inout Input) throws(Failure) -> Output`
//   compiles when Input: ~Escapable — matching the real Parser.Protocol signature
// Result: CONFIRMED — inout Input works with ~Escapable, typed throws works,
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   exact Parser.Protocol method shape is compatible

enum ParseError: Error, Sendable { case unexpected }

protocol InoutParserV7: ~Copyable {
    associatedtype Input: ~Escapable
    associatedtype Output
    associatedtype Failure: Swift.Error & Sendable
    func parse(_ input: inout Input) throws(Failure) -> Output
}

struct IntArrayParser: InoutParserV7 {
    typealias Input = [UInt8]
    typealias Output = UInt8
    typealias Failure = ParseError

    func parse(_ input: inout [UInt8]) throws(ParseError) -> UInt8 {
        guard !input.isEmpty else { throw .unexpected }
        return input.removeFirst()
    }
}

// =============================================================================
// MARK: - Execution
// =============================================================================

var stringParser = StringParserV2()
let stringResult = stringParser.parse("hello")
print("V2 String parser: \(stringResult as Any)")

var byteParser = ByteParserV3()
let bytes: [UInt8] = [0x48, 0x65, 0x6C]
let byteResult = bytes.withUnsafeBufferPointer { buf in
    let span = Span(_unsafeElements: buf)
    return byteParser.parse(span)
}
print("V3 Byte parser:   \(byteResult as Any)")

let intProcessor = IntProcessor()
let intResult = intProcessor.process(42)
print("V4 Int processor: \(intResult)")

let canParse = stringParser.canParse("world")
print("V5 canParse:      \(canParse)")

let inoutParser = IntArrayParser()
var inputBytes: [UInt8] = [0x41, 0x42]
let parsed = try! inoutParser.parse(&inputBytes)
print("V7 inout parser:  \(parsed) (remaining: \(inputBytes.count))")

// =============================================================================
// MARK: - Results Summary
// =============================================================================
// V1: CONFIRMED — `associatedtype Input: ~Escapable` compiles
// V2: CONFIRMED — Escapable type (String) satisfies ~Escapable constraint
// V3: CONFIRMED — ~Escapable type (Span<UInt8>) satisfies constraint, runs correctly
// V4: CONFIRMED — `~Copyable & ~Escapable` combined suppression compiles
// V5: CONFIRMED — protocol extension default methods work with ~Escapable associated type
// V6: REFUTED   — cannot return ~Escapable from protocol method (language limitation)
// V7: CONFIRMED — inout Input with ~Escapable compiles, typed throws works,
//                 exact Parser.Protocol method shape is compatible
//
// Key Findings:
// 1. SuppressedAssociatedTypes enables BOTH ~Copyable AND ~Escapable on associated types
// 2. ~Escapable associated types work in borrowing and inout parameter positions
// 3. ~Escapable associated types CANNOT be used as return types from protocol methods
// 4. Combined `~Copyable & ~Escapable` suppression works on a single associated type
// 5. With legacy flag, suppressed types are ALWAYS non-escapable — no inference defaults
//
// Implications for Parser.Protocol:
// - `associatedtype Input: ~Escapable` is viable TODAY
// - `func parse(_ input: inout Input) throws(Failure) -> Output` compiles as-is
//   since Input is inout (not returned), and Output remains Escapable
// - This would allow conformers to use Span<UInt8> as Input directly,
//   eliminating the need for the `Parser.Bytes.Input` escapable cursor wrapper
// - Caveat: with legacy flag, ALL conformers see Input as ~Escapable,
//   which means escapable Input types (String, [UInt8]) need no changes
//   but protocol extensions operating on Input may need borrowing annotations
