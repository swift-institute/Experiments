// MARK: - ParserPrinter Codec for RFC 8259
// Purpose: Evaluate ParserPrinter-based JSON codec vs current Lexer/Parser/Encoder pipeline
// Hypothesis: Single ParserPrinter definition provides bidirectional JSON codec
//             with round-trip correctness by construction
//
// Toolchain: (pending execution)
// Status: SUPERSEDED 2026-04-30 — Unicode-escape syntax in string literal no longer accepted; experiment requires re-authoring string content
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: (pending execution)
//
// Result: (PENDING)
// Date: 2026-03-24

import Parser_Primitives

// MARK: - Design Overview

/*
 Current Architecture:
 =====================
 RFC_8259.Lexer<Input>  -> Produces RFC_8259.Token stream
 RFC_8259.Parser<Input> -> Consumes tokens, produces RFC_8259.Value tree
 RFC_8259.Encoder       -> Produces [UInt8] from RFC_8259.Value

 Proposed Architecture (using Parsing Primitives):
 =================================================
 RFC_8259.JSON          -> ParserPrinter for complete JSON values
 RFC_8259.JSON.String   -> ParserPrinter for JSON strings
 RFC_8259.JSON.Number   -> ParserPrinter for JSON numbers
 RFC_8259.JSON.Literal  -> ParserPrinter for null/true/false
 RFC_8259.JSON.Array    -> ParserPrinter for JSON arrays
 RFC_8259.JSON.Object   -> ParserPrinter for JSON objects

 Benefits:
 - Single definition for both parsing and printing
 - Round-trip guarantee by construction
 - Composable via standard combinators
 - Consistent error types

 Trade-offs:
 - Printer protocol prepends (not appends) - may need adapter
 - Additional abstraction layer
 - Need to benchmark against current hand-optimized code
*/

// MARK: - Error Types

extension RFC_8259 {
    /// Unified error type for both parsing and printing.
    ///
    /// Named `PPError` to avoid collision with existing `RFC_8259.Error`.
    enum PPError: Swift.Error, Sendable {
        case unexpectedEndOfInput
        case unexpectedByte(UInt8, expected: String)
        case invalidEscapeSequence
        case invalidUnicodeEscape
        case invalidNumber
        case depthExceeded(Int)
        case unterminatedString
        case controlCharacter(UInt8)
    }
}

// MARK: - JSON Literal ParserPrinter

extension RFC_8259 {
    /// ParserPrinter for JSON literals (null, true, false).
    struct LiteralParserPrinter: Parser_Primitives.Parser.Bidirectional {
        typealias Input = ArraySlice<UInt8>
        typealias Output = Value
        typealias Failure = PPError

        @inlinable
        init() {}

        // MARK: Parser

        @inlinable
        func parse(_ input: inout Input) throws(Failure) -> Value {
            guard let first = input.first else {
                throw .unexpectedEndOfInput
            }

            switch first {
            case .ascii.n:
                try expect([.ascii.n, .ascii.u, .ascii.l, .ascii.l], from: &input)
                return .null

            case .ascii.t:
                try expect([.ascii.t, .ascii.r, .ascii.u, .ascii.e], from: &input)
                return .bool(true)

            case .ascii.f:
                try expect([.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e], from: &input)
                return .bool(false)

            default:
                throw .unexpectedByte(first, expected: "null, true, or false")
            }
        }

        @inlinable
        func expect(_ bytes: [UInt8], from input: inout Input) throws(Failure) {
            for expected in bytes {
                guard let byte = input.first else {
                    throw .unexpectedEndOfInput
                }
                guard byte == expected else {
                    throw .unexpectedByte(byte, expected: String(decoding: bytes, as: UTF8.self))
                }
                input.removeFirst()
            }
        }

        // MARK: Printer

        @inlinable
        func print(_ output: Value, into input: inout Input) throws(Failure) {
            switch output {
            case .null:
                // Prepend "null" (reversed for prepend semantics)
                input.insert(contentsOf: [.ascii.n, .ascii.u, .ascii.l, .ascii.l], at: input.startIndex)
            case .bool(true):
                input.insert(contentsOf: [.ascii.t, .ascii.r, .ascii.u, .ascii.e], at: input.startIndex)
            case .bool(false):
                input.insert(contentsOf: [.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e], at: input.startIndex)
            default:
                fatalError("LiteralParserPrinter cannot print \(output)")
            }
        }
    }
}

// MARK: - JSON String ParserPrinter

extension RFC_8259 {
    /// ParserPrinter for JSON strings.
    struct StringParserPrinter: Parser_Primitives.Parser.Bidirectional {
        typealias Input = ArraySlice<UInt8>
        typealias Output = String
        typealias Failure = PPError

        @inlinable
        init() {}

        // MARK: Parser

        @inlinable
        func parse(_ input: inout Input) throws(Failure) -> String {
            guard input.first == .ascii.quotationMark else {
                throw .unexpectedByte(input.first ?? 0, expected: "\"")
            }
            input.removeFirst() // consume "

            var result: [UInt8] = []

            while let byte = input.first {
                switch byte {
                case .ascii.quotationMark:
                    input.removeFirst() // consume closing "
                    return String(decoding: result, as: UTF8.self)

                case .ascii.reverseSlant:
                    input.removeFirst() // consume \
                    try result.append(contentsOf: parseEscape(&input))

                case 0x00...0x1F:
                    throw .controlCharacter(byte)

                default:
                    result.append(byte)
                    input.removeFirst()
                }
            }

            throw .unterminatedString
        }

        @inlinable
        func parseEscape(_ input: inout Input) throws(Failure) -> [UInt8] {
            guard let byte = input.first else {
                throw .unexpectedEndOfInput
            }
            input.removeFirst()

            switch byte {
            case .ascii.quotationMark: return [.ascii.quotationMark]
            case .ascii.reverseSlant:  return [.ascii.reverseSlant]
            case .ascii.solidus:       return [.ascii.solidus]
            case .ascii.b:             return [.ascii.bs]
            case .ascii.f:             return [.ascii.ff]
            case .ascii.n:             return [.ascii.lf]
            case .ascii.r:             return [.ascii.cr]
            case .ascii.t:             return [.ascii.htab]
            case .ascii.u:             return try parseUnicodeEscape(&input)
            default:
                throw .invalidEscapeSequence
            }
        }

        @inlinable
        func parseUnicodeEscape(_ input: inout Input) throws(Failure) -> [UInt8] {
            var hex: UInt32 = 0
            for _ in 0..<4 {
                guard let byte = input.first else {
                    throw .unexpectedEndOfInput
                }
                guard let digit = hexValue(byte) else {
                    throw .invalidUnicodeEscape
                }
                hex = hex * 16 + UInt32(digit)
                input.removeFirst()
            }

            // Handle surrogate pairs
            if hex >= 0xD800 && hex <= 0xDBFF {
                // High surrogate - expect \uXXXX low surrogate
                guard input.first == .ascii.reverseSlant else {
                    throw .invalidUnicodeEscape
                }
                input.removeFirst()
                guard input.first == .ascii.u else {
                    throw .invalidUnicodeEscape
                }
                input.removeFirst()

                var lowHex: UInt32 = 0
                for _ in 0..<4 {
                    guard let byte = input.first, let digit = hexValue(byte) else {
                        throw .invalidUnicodeEscape
                    }
                    lowHex = lowHex * 16 + UInt32(digit)
                    input.removeFirst()
                }

                guard lowHex >= 0xDC00 && lowHex <= 0xDFFF else {
                    throw .invalidUnicodeEscape
                }

                let combined = 0x10000 + ((hex - 0xD800) << 10) + (lowHex - 0xDC00)
                guard let scalar = Unicode.Scalar(combined) else {
                    throw .invalidUnicodeEscape
                }
                return [UInt8](String(scalar).utf8)
            }

            guard let scalar = Unicode.Scalar(hex) else {
                throw .invalidUnicodeEscape
            }
            return [UInt8](String(scalar).utf8)
        }

        @inlinable
        func hexValue(_ byte: UInt8) -> UInt8? {
            switch byte {
            case .ascii.`0`...(.ascii.`9`): return byte - .ascii.`0`
            case .ascii.a...(.ascii.f): return byte - .ascii.a + 10
            case .ascii.A...(.ascii.F): return byte - .ascii.A + 10
            default: return nil
            }
        }

        // MARK: Printer

        @inlinable
        func print(_ output: String, into input: inout Input) throws(Failure) {
            // Build escaped string
            var escaped: [UInt8] = [.ascii.quotationMark] // opening "

            for byte in output.utf8 {
                switch byte {
                case .ascii.quotationMark:
                    escaped.append(contentsOf: [.ascii.reverseSlant, .ascii.quotationMark])
                case .ascii.reverseSlant:
                    escaped.append(contentsOf: [.ascii.reverseSlant, .ascii.reverseSlant])
                case .ascii.bs:
                    escaped.append(contentsOf: [.ascii.reverseSlant, .ascii.b])
                case .ascii.ff:
                    escaped.append(contentsOf: [.ascii.reverseSlant, .ascii.f])
                case .ascii.lf:
                    escaped.append(contentsOf: [.ascii.reverseSlant, .ascii.n])
                case .ascii.cr:
                    escaped.append(contentsOf: [.ascii.reverseSlant, .ascii.r])
                case .ascii.htab:
                    escaped.append(contentsOf: [.ascii.reverseSlant, .ascii.t])
                case 0x00...0x1F:
                    // Control character -> \uXXXX
                    escaped.append(contentsOf: [.ascii.reverseSlant, .ascii.u, .ascii.`0`, .ascii.`0`])
                    escaped.append(hexDigit(byte >> 4))
                    escaped.append(hexDigit(byte & 0x0F))
                default:
                    escaped.append(byte)
                }
            }

            escaped.append(.ascii.quotationMark) // closing "

            // Prepend to input (Printer semantics)
            input.insert(contentsOf: escaped, at: input.startIndex)
        }

        @inlinable
        func hexDigit(_ value: UInt8) -> UInt8 {
            value < 10 ? .ascii.`0` + value : .ascii.a + value - 10
        }
    }
}

// MARK: - JSON Number ParserPrinter

extension RFC_8259 {
    /// ParserPrinter for JSON numbers.
    struct NumberParserPrinter: Parser_Primitives.Parser.Bidirectional {
        typealias Input = ArraySlice<UInt8>
        typealias Output = Number
        typealias Failure = PPError

        @inlinable
        init() {}

        // MARK: Parser

        @inlinable
        func parse(_ input: inout Input) throws(Failure) -> Number {
            var bytes: [UInt8] = []

            // Optional minus
            if input.first == .ascii.hyphen {
                bytes.append(input.removeFirst())
            }

            // Integer part
            guard let first = input.first, first.ascii.isDigit else {
                throw .invalidNumber
            }

            if first == .ascii.`0` {
                bytes.append(input.removeFirst())
                // No leading zeros allowed
                if let next = input.first, next.ascii.isDigit {
                    throw .invalidNumber
                }
            } else {
                while let byte = input.first, byte.ascii.isDigit {
                    bytes.append(input.removeFirst())
                }
            }

            var isFloat = false

            // Optional fraction
            if input.first == .ascii.period {
                isFloat = true
                bytes.append(input.removeFirst())

                guard let fracDigit = input.first, fracDigit.ascii.isDigit else {
                    throw .invalidNumber
                }

                while let byte = input.first, byte.ascii.isDigit {
                    bytes.append(input.removeFirst())
                }
            }

            // Optional exponent
            if let e = input.first, e == .ascii.e || e == .ascii.E {
                isFloat = true
                bytes.append(input.removeFirst())

                if let sign = input.first, sign == .ascii.plusSign || sign == .ascii.hyphen {
                    bytes.append(input.removeFirst())
                }

                guard let expDigit = input.first, expDigit.ascii.isDigit else {
                    throw .invalidNumber
                }

                while let byte = input.first, byte.ascii.isDigit {
                    bytes.append(input.removeFirst())
                }
            }

            let original = Number.Original(bytes)
            let numStr = String(decoding: bytes, as: UTF8.self)

            if isFloat {
                guard let value = Double(numStr), value.isFinite else {
                    throw .invalidNumber
                }
                return Number(value, original: original)
            } else {
                if let value = Int64(numStr) {
                    return Number(value, original: original)
                } else if let value = UInt64(numStr) {
                    return Number(value, original: original)
                } else if let value = Double(numStr), value.isFinite {
                    return Number(value, original: original)
                } else {
                    throw .invalidNumber
                }
            }
        }

        // MARK: Printer

        @inlinable
        func print(_ output: Number, into input: inout Input) throws(Failure) {
            // Use original representation for lossless round-trip
            input.insert(contentsOf: output.original.bytes, at: input.startIndex)
        }
    }
}

// MARK: - Whitespace Parser (no printer - whitespace is not preserved)

extension RFC_8259 {
    /// Parser for optional JSON whitespace.
    struct WhitespaceParser: Parser_Primitives.Parser.`Protocol` {
        typealias Input = ArraySlice<UInt8>
        typealias Output = Void
        typealias Failure = Never

        @inlinable
        init() {}

        @inlinable
        func parse(_ input: inout Input) throws(Never) {
            while let byte = input.first, RFC_8259.isWhitespace(byte) {
                input.removeFirst()
            }
        }
    }
}

// MARK: - JSON Value ParserPrinter (Recursive)

extension RFC_8259 {
    /// ParserPrinter for any JSON value.
    ///
    /// This is the top-level parser/printer that handles all JSON value types.
    /// It uses mutual recursion with ArrayParserPrinter and ObjectParserPrinter.
    struct ValueParserPrinter: Parser_Primitives.Parser.Bidirectional {
        typealias Input = ArraySlice<UInt8>
        typealias Output = Value
        typealias Failure = PPError

        @usableFromInline
        let maxDepth: Int

        @usableFromInline
        var currentDepth: Int

        @inlinable
        init(maxDepth: Int = 512) {
            self.maxDepth = maxDepth
            self.currentDepth = 0
        }

        // MARK: Parser

        @inlinable
        func parse(_ input: inout Input) throws(Failure) -> Value {
            // Skip leading whitespace
            skipWhitespace(&input)

            guard let first = input.first else {
                throw .unexpectedEndOfInput
            }

            switch first {
            case .ascii.n, .ascii.t, .ascii.f:
                return try LiteralParserPrinter().parse(&input)

            case .ascii.quotationMark:
                let str = try StringParserPrinter().parse(&input)
                return .string(str)

            case .ascii.hyphen, .ascii.`0`...(.ascii.`9`):
                let num = try NumberParserPrinter().parse(&input)
                return .number(num)

            case .ascii.leftBracket:
                return try parseArray(&input)

            case .ascii.leftBrace:
                return try parseObject(&input)

            default:
                throw .unexpectedByte(first, expected: "JSON value")
            }
        }

        @inlinable
        func skipWhitespace(_ input: inout Input) {
            while let byte = input.first, RFC_8259.isWhitespace(byte) {
                input.removeFirst()
            }
        }

        @inlinable
        func parseArray(_ input: inout Input) throws(Failure) -> Value {
            guard currentDepth < maxDepth else {
                throw .depthExceeded(maxDepth)
            }

            input.removeFirst() // consume [
            var elements: [Value] = []

            skipWhitespace(&input)

            if input.first == .ascii.rightBracket {
                input.removeFirst()
                return .array(RFC_8259.Array(elements))
            }

            // Parse first element
            var nested = ValueParserPrinter(maxDepth: maxDepth)
            nested.currentDepth = currentDepth + 1
            elements.append(try nested.parse(&input))

            // Parse remaining elements
            skipWhitespace(&input)
            while input.first == .ascii.comma {
                input.removeFirst() // consume ,
                elements.append(try nested.parse(&input))
                skipWhitespace(&input)
            }

            guard input.first == .ascii.rightBracket else {
                throw .unexpectedByte(input.first ?? 0, expected: "] or ,")
            }
            input.removeFirst()

            return .array(RFC_8259.Array(elements))
        }

        @inlinable
        func parseObject(_ input: inout Input) throws(Failure) -> Value {
            guard currentDepth < maxDepth else {
                throw .depthExceeded(maxDepth)
            }

            input.removeFirst() // consume {
            var members: [(key: String, value: Value)] = []

            skipWhitespace(&input)

            if input.first == .ascii.rightBrace {
                input.removeFirst()
                return .object(RFC_8259.Object(members))
            }

            // Parse first member
            var nested = ValueParserPrinter(maxDepth: maxDepth)
            nested.currentDepth = currentDepth + 1

            members.append(try parseMember(&input, nested: nested))

            // Parse remaining members
            skipWhitespace(&input)
            while input.first == .ascii.comma {
                input.removeFirst() // consume ,
                members.append(try parseMember(&input, nested: nested))
                skipWhitespace(&input)
            }

            guard input.first == .ascii.rightBrace else {
                throw .unexpectedByte(input.first ?? 0, expected: "} or ,")
            }
            input.removeFirst()

            return .object(RFC_8259.Object(members))
        }

        @inlinable
        func parseMember(_ input: inout Input, nested: ValueParserPrinter) throws(Failure) -> (key: String, value: Value) {
            skipWhitespace(&input)
            let key = try StringParserPrinter().parse(&input)

            skipWhitespace(&input)
            guard input.first == .ascii.colon else {
                throw .unexpectedByte(input.first ?? 0, expected: ":")
            }
            input.removeFirst()

            let value = try nested.parse(&input)

            return (key, value)
        }

        // MARK: Printer

        @inlinable
        func print(_ output: Value, into input: inout Input) throws(Failure) {
            switch output {
            case .null, .bool:
                try LiteralParserPrinter().print(output, into: &input)

            case .string(let str):
                try StringParserPrinter().print(str, into: &input)

            case .number(let num):
                try NumberParserPrinter().print(num, into: &input)

            case .array(let arr):
                try printArray(arr, into: &input)

            case .object(let obj):
                try printObject(obj, into: &input)
            }
        }

        @inlinable
        func printArray(_ array: RFC_8259.Array, into input: inout Input) throws(Failure) {
            var result: [UInt8] = [.ascii.leftBracket]

            var first = true
            for element in array {
                if !first {
                    result.append(.ascii.comma)
                }
                first = false

                // Print element into temporary buffer
                var elementBuffer: ArraySlice<UInt8> = []
                var nested = ValueParserPrinter(maxDepth: maxDepth)
                nested.currentDepth = currentDepth + 1
                try nested.print(element, into: &elementBuffer)
                result.append(contentsOf: elementBuffer)
            }

            result.append(.ascii.rightBracket)
            input.insert(contentsOf: result, at: input.startIndex)
        }

        @inlinable
        func printObject(_ object: RFC_8259.Object, into input: inout Input) throws(Failure) {
            var result: [UInt8] = [.ascii.leftBrace]

            var first = true
            for (key, value) in object {
                if !first {
                    result.append(.ascii.comma)
                }
                first = false

                // Print key
                var keyBuffer: ArraySlice<UInt8> = []
                try StringParserPrinter().print(key, into: &keyBuffer)
                result.append(contentsOf: keyBuffer)

                result.append(.ascii.colon)

                // Print value
                var valueBuffer: ArraySlice<UInt8> = []
                var nested = ValueParserPrinter(maxDepth: maxDepth)
                nested.currentDepth = currentDepth + 1
                try nested.print(value, into: &valueBuffer)
                result.append(contentsOf: valueBuffer)
            }

            result.append(.ascii.rightBrace)
            input.insert(contentsOf: result, at: input.startIndex)
        }
    }
}

// MARK: - Usage Example

/*
 Usage with Parsing Primitives approach:
 =======================================

 // Parsing
 let json = """
 {"name": "John", "age": 30}
 """.utf8
 var input = ArraySlice(json)
 let value = try ValueParserPrinter().parse(&input)

 // Printing
 var output: ArraySlice<UInt8> = []
 try ValueParserPrinter().print(value, into: &output)
 let jsonString = String(decoding: output, as: UTF8.self)

 // Or using convenience method:
 let bytes: ArraySlice<UInt8> = try ValueParserPrinter().print(value)


 Trade-offs vs Current Implementation:
 =====================================

 ADVANTAGES:
 1. Single definition for parse + print (ParserPrinter protocol)
 2. Round-trip correctness by construction
 3. Composable - can combine with other parsers
 4. Consistent error types across parse/print
 5. Uses existing swift-parser-primitives infrastructure

 DISADVANTAGES:
 1. Printer protocol prepends (insert at startIndex) which is O(n)
    - Current encoder appends which is O(1) amortized
    - Would need adapter or modified approach for performance
 2. Creates intermediate buffers for nested structures
    - Current encoder writes directly to output buffer
 3. Additional abstraction layer may reduce optimization opportunities
 4. Would need significant refactoring of existing code

 PERFORMANCE CONSIDERATIONS:
 - Prepend-based printing: Each insert at startIndex copies existing elements
 - For large JSON, this could be O(n^2) vs O(n) for append-based
 - Could mitigate with:
   a) Build in reverse order, then reverse final output
   b) Use a rope/gap buffer data structure
   c) Modify Printer protocol to support append mode

 RECOMMENDATION:
 - Keep current optimized implementation for production use
 - Consider Parsing primitives for:
   * New formats where bidirectional codec is valuable
   * Validation/schema-based parsing
   * Streaming/incremental parsing scenarios
*/

// MARK: - Test Harness

let testCases: [(json: String, label: String)] = [
    (#"null"#, "null literal"),
    (#"true"#, "true literal"),
    (#"false"#, "false literal"),
    (#""hello""#, "simple string"),
    (#""hello\"world""#, "escaped string"),
    (#"42"#, "integer"),
    (#"3.14"#, "float"),
    (#"-123"#, "negative integer"),
    (#"1e10"#, "scientific notation"),
    (#"[1,2,3]"#, "simple array"),
    (#"[]"#, "empty array"),
    (#"{"key":"value"}"#, "simple object"),
    (#"{}"#, "empty object"),
    (#"{"a":{"b":{"c":1}}}"#, "nested object"),
    (#"[1,[2,[3]]]"#, "nested array"),
]

var passed = 0
var failed = 0

for (json, label) in testCases {
    var input = ArraySlice(json.utf8)
    do {
        let parsed = try RFC_8259.ValueParserPrinter().parse(&input)

        var output: ArraySlice<UInt8> = []
        try RFC_8259.ValueParserPrinter().print(parsed, into: &output)
        let result = String(decoding: output, as: UTF8.self)

        if json == result {
            print("  PASS: \(label)")
            passed += 1
        } else {
            print("  FAIL: \(label) \u2014 expected \(json), got \(result)")
            failed += 1
        }
    } catch {
        print("  FAIL: \(label) \u2014 \(error)")
        failed += 1
    }
}

print("\nResults: \(passed) passed, \(failed) failed")
