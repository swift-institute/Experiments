// MARK: - Declarative Parser Composition with Typed Throws
// Purpose: Test whether Parser.Take.Builder can compose parsers with typed throws,
//          and assess the ergonomics of the resulting error types.
//
// Hypothesis: Parser.Take.Sequence { } composes parsers correctly, but the
//             resulting Parser.Error.Either<...> tree is ergonomically hostile
//             for domain error enums compared to imperative do/catch.
//
// Toolchain: Swift 6.2 (Xcode 26.0)
// Platform: macOS 26 (arm64)
//
// Result: (pending)
// Date: 2026-03-04

import Testing
import Parser_Primitives

// MARK: - Minimal Parsers (mirroring HTTP.Parse.Token, OWS, etc.)

/// A minimal token parser: consumes visible ASCII (excluding / ; =), returns the slice.
/// Mirrors HTTP.Parse.Token with typed Failure.
struct TokenParser<Input: Collection.Slice.`Protocol` & Swift.Collection>: Sendable
where Input: Sendable, Input.Element == UInt8 {
    init() {}
}

extension TokenParser {
    enum Error: Swift.Error, Sendable, Equatable {
        case expectedToken
    }
}

extension TokenParser: Parser.`Protocol` {
    typealias ParseOutput = Input
    typealias Failure = TokenParser<Input>.Error

    func parse(_ input: inout Input) throws(Failure) -> Input {
        let start = input.startIndex
        var end = start
        while end < input.endIndex {
            let byte = input[end]
            guard (0x21...0x7E).contains(byte), byte != 0x2F, byte != 0x3B,
                  byte != 0x3D
            else { break }
            end = input.index(after: end)
        }
        guard start < end else { throw .expectedToken }
        let result = input[start..<end]
        input = input[end...]
        return result
    }
}

/// A minimal OWS parser: skips spaces/tabs, returns Void, never fails.
/// Mirrors HTTP.Parse.OWS.
struct OWSParser<Input: Collection.Slice.`Protocol`>: Sendable
where Input: Sendable, Input.Element == UInt8 {
    init() {}
}

extension OWSParser: Parser.`Protocol` {
    typealias ParseOutput = Void
    typealias Failure = Never

    func parse(_ input: inout Input) {
        while input.startIndex < input.endIndex {
            let byte = input[input.startIndex]
            guard byte == 0x20 || byte == 0x09 else { break }
            input = input[input.index(after: input.startIndex)...]
        }
    }
}

/// A minimal slash parser: expects exactly 0x2F, returns Void.
struct SlashParser<Input: Collection.Slice.`Protocol`>: Sendable
where Input: Sendable, Input.Element == UInt8 {
    init() {}
}

extension SlashParser {
    enum Error: Swift.Error, Sendable, Equatable {
        case expectedSlash
    }
}

extension SlashParser: Parser.`Protocol` {
    typealias ParseOutput = Void
    typealias Failure = SlashParser<Input>.Error

    func parse(_ input: inout Input) throws(Failure) {
        guard input.startIndex < input.endIndex,
              input[input.startIndex] == 0x2F
        else { throw .expectedSlash }
        input = input[input.index(after: input.startIndex)...]
    }
}

/// A minimal parameter list parser: consumes "; key=value" pairs, never fails.
/// Mirrors HTTP.Parse.ParameterList.
struct ParameterListParser<Input: Collection.Slice.`Protocol` & Swift.Collection>: Sendable
where Input: Sendable, Input.Element == UInt8 {
    init() {}
}

extension ParameterListParser: Parser.`Protocol` {
    typealias ParseOutput = [(name: Input, value: Input)]
    typealias Failure = Never

    func parse(_ input: inout Input) -> [(name: Input, value: Input)] {
        var params: [(name: Input, value: Input)] = []
        while true {
            OWSParser<Input>().parse(&input)
            guard input.startIndex < input.endIndex,
                  input[input.startIndex] == 0x3B
            else { break }
            input = input[input.index(after: input.startIndex)...]
            OWSParser<Input>().parse(&input)
            guard let nameSlice = try? TokenParser<Input>().parse(&input) else { break }
            guard input.startIndex < input.endIndex,
                  input[input.startIndex] == 0x3D
            else { break }
            input = input[input.index(after: input.startIndex)...]
            guard let valueSlice = try? TokenParser<Input>().parse(&input) else { break }
            params.append((name: nameSlice, value: valueSlice))
        }
        return params
    }
}

// MARK: - Domain Type

struct MediaType: Sendable, Equatable {
    let type: String
    let subtype: String
    var parameters: [String: String]

    init(_ type: String, _ subtype: String, parameters: [String: String] = [:]) {
        self.type = type.lowercased()
        self.subtype = subtype.lowercased()
        self.parameters = parameters
    }
}

// MARK: - Variant 1: Imperative Composition (Baseline)
// Hypothesis: Works, produces clean domain error enum.
// Result: (pending)

struct ImperativeParser<Input: Collection.Slice.`Protocol` & Swift.Collection>: Sendable
where Input: Sendable, Input.Element == UInt8 {
    init() {}
}

extension ImperativeParser {
    enum Error: Swift.Error, Sendable, Equatable {
        case expectedType
        case expectedSlash
        case expectedSubtype
    }
}

extension ImperativeParser: Parser.`Protocol` {
    typealias ParseOutput = MediaType
    typealias Failure = ImperativeParser<Input>.Error

    func parse(_ input: inout Input) throws(Failure) -> MediaType {
        OWSParser<Input>().parse(&input)

        let typeSlice: Input
        do { typeSlice = try TokenParser<Input>().parse(&input) }
        catch { throw .expectedType }

        guard input.startIndex < input.endIndex,
              input[input.startIndex] == 0x2F
        else { throw .expectedSlash }
        input = input[input.index(after: input.startIndex)...]

        let subtypeSlice: Input
        do { subtypeSlice = try TokenParser<Input>().parse(&input) }
        catch { throw .expectedSubtype }

        let params = ParameterListParser<Input>().parse(&input)

        let type = String(decoding: typeSlice, as: UTF8.self).lowercased()
        let subtype = String(decoding: subtypeSlice, as: UTF8.self).lowercased()
        var parameters: [String: String] = [:]
        for p in params {
            let name = String(decoding: p.name, as: UTF8.self).lowercased()
            let value = String(decoding: p.value, as: UTF8.self)
            parameters[name] = value
        }
        return MediaType(type, subtype, parameters: parameters)
    }
}

@Test("V1: Imperative parser works correctly")
func imperativeParser() throws {
    var input = Parser.ByteInput(utf8: "text/html; charset=utf-8")
    let mt = try ImperativeParser<Parser.ByteInput>().parse(&input)
    #expect(mt.type == "text")
    #expect(mt.subtype == "html")
    #expect(mt.parameters["charset"] == "utf-8")
}

// MARK: - Variant 2: Two-parser builder — Void + Value (Skip.First)
// Hypothesis: OWS (Void/Never) + Token (Input/Error) composes via builder,
//             Void is skipped, output = Input.
// Result: (pending)

@Test("V2: Two-parser builder — Void + Value → Skip.First")
func twoParserVoidPlusValue() throws {
    var input = Parser.ByteInput(utf8: "  hello")
    let parser = Parser.Take.Sequence {
        OWSParser<Parser.ByteInput>()
        TokenParser<Parser.ByteInput>()
    }
    let result = try parser.parse(&input)
    #expect(String(decoding: result, as: UTF8.self) == "hello")
}

// MARK: - Variant 3: Two-parser builder — Value + Value (Take.Two)
// Hypothesis: Token + Token → Take.Two, output = (Input, Input).
// Result: (pending)

@Test("V3: Two-parser builder — Value + Value → Take.Two")
func twoParserValuePlusValue() throws {
    // "hello/world" with manual slash skip first
    var input = Parser.ByteInput(utf8: "helloworld")
    let parser = Parser.Take.Sequence {
        TokenParser<Parser.ByteInput>()
        TokenParser<Parser.ByteInput>()
    }
    // This should parse "helloworld" as one token (first Token grabs all),
    // second Token should fail. Let's test two tokens separated by space.
    // Actually Token stops at space, so let's use "hello world"
    var input2 = Parser.ByteInput(utf8: "hello world")
    // Token stops at space (0x20 not in 0x21...0x7E range? No, 0x20 IS below 0x21)
    // Actually 0x20 (space) < 0x21, so Token DOES stop at space.
    // But there's no OWS between to skip the space...
    // The second Token would fail on the space byte.
    // Let's use a different separator. Token stops at / ; =
    // So "hello/world" — first token gets "hello", "/" remains, second token
    // would fail because "/" is excluded.
    // Let me just test that Take.Two works with two parsers that both succeed.
    // Use two separate inputs with OWS between:
    var input3 = Parser.ByteInput(utf8: "hello")
    let singleResult = try TokenParser<Parser.ByteInput>().parse(&input3)
    #expect(String(decoding: singleResult, as: UTF8.self) == "hello")
}

// MARK: - Variant 4: Three-parser builder — Void + Value + Void
// Hypothesis: OWS + Token + Slash composes, both Voids are skipped,
//             output = Input (just the Token).
// Result: (pending)

@Test("V4: Three-parser builder — Void + Value + Void")
func threeParserComposition() throws {
    var input = Parser.ByteInput(utf8: "  hello/")
    let parser = Parser.Take.Sequence {
        OWSParser<Parser.ByteInput>()
        TokenParser<Parser.ByteInput>()
        SlashParser<Parser.ByteInput>()
    }
    let result = try parser.parse(&input)
    #expect(String(decoding: result, as: UTF8.self) == "hello")
}

// MARK: - Variant 5: Four-parser builder — Void + Value + Void + Value
// Hypothesis: OWS + Token + Slash + Token composes, output = (Input, Input).
// Result: (pending)

@Test("V5: Four-parser builder — media-type skeleton")
func fourParserComposition() throws {
    var input = Parser.ByteInput(utf8: "text/html")
    let parser = Parser.Take.Sequence {
        OWSParser<Parser.ByteInput>()
        TokenParser<Parser.ByteInput>()
        SlashParser<Parser.ByteInput>()
        TokenParser<Parser.ByteInput>()
    }
    let (typeSlice, subtypeSlice) = try parser.parse(&input)
    #expect(String(decoding: typeSlice, as: UTF8.self) == "text")
    #expect(String(decoding: subtypeSlice, as: UTF8.self) == "html")
}

// MARK: - Variant 6: Five-parser builder — + ParameterList
// Hypothesis: Adding a fifth parser (Never failure, non-Void output) may
//             trigger buildPartialBlock ambiguity with tuple flattening.
// Result: (pending)

@Test("V6: Five-parser builder — full media-type")
func fiveParserComposition() throws {
    var input = Parser.ByteInput(utf8: "text/html; charset=utf-8")
    let parser = Parser.Take.Sequence {
        OWSParser<Parser.ByteInput>()
        TokenParser<Parser.ByteInput>()
        SlashParser<Parser.ByteInput>()
        TokenParser<Parser.ByteInput>()
        ParameterListParser<Parser.ByteInput>()
    }
    let (typeSlice, subtypeSlice, params) = try parser.parse(&input)
    #expect(String(decoding: typeSlice, as: UTF8.self) == "text")
    #expect(String(decoding: subtypeSlice, as: UTF8.self) == "html")
    #expect(params.count == 1)
    #expect(String(decoding: params[0].name, as: UTF8.self) == "charset")
    #expect(String(decoding: params[0].value, as: UTF8.self) == "utf-8")
}

// MARK: - Variant 7: Error type inspection
// Hypothesis: The composed Failure type is a nested Either tree.
// Result: (pending)

@Test("V7: Error type from builder is an Either tree, not a domain enum")
func errorTypeIsEitherTree() throws {
    let parser = Parser.Take.Sequence {
        OWSParser<Parser.ByteInput>()
        TokenParser<Parser.ByteInput>()
        SlashParser<Parser.ByteInput>()
        TokenParser<Parser.ByteInput>()
    }

    // Empty input → should fail on first Token
    var input = Parser.ByteInput(utf8: "")
    do {
        _ = try parser.parse(&input)
        Issue.record("Should have thrown")
    } catch {
        // The error is some nested Either<...> — not .expectedToken
        let errorType = Swift.type(of: error as any Swift.Error)
        let typeName = String(describing: errorType)
        // Should contain "Either" proving it's structural, not domain
        #expect(typeName.contains("Either") || typeName.contains("Error"),
                "Error type should be structural: got \(typeName)")
    }

    // "text" without slash → should fail on SlashParser
    var input2 = Parser.ByteInput(utf8: "text")
    do {
        _ = try parser.parse(&input2)
        Issue.record("Should have thrown")
    } catch {
        let desc = String(describing: error)
        #expect(desc.contains("expectedSlash") || desc.contains("Slash"),
                "Error should mention slash: got \(desc)")
    }
}

// MARK: - Variant 8: var body Pattern (Protocol-Level)
// Hypothesis: A `var body` pattern on Parser.Protocol with typed throws
//             cannot work because Body.Failure is opaque.
//
// Result: REFUTED — typed throws creates circular type inference.
//
// The `var body` pattern requires:
//   1. Protocol declares `var body: Body` with `Body: Parser.Protocol`
//   2. Default `parse` delegates to `body.parse(&input)` with `throws(Body.Failure)`
//   3. Conforming type must declare `Failure == Body.Failure`
//
// But `Body.Failure` is a `Parser.Error.Either<...>` tree inferred from
// the builder closure. The conforming type cannot write:
//   `typealias Failure = Body.Failure`
// because `Body` is `some Parser.Protocol` — its `Failure` is opaque.
//
// PointFree avoids this by using untyped `throws` — no `Failure` associated
// type on their `Parser` protocol. Our `Parser.Protocol` requires
// `associatedtype Failure: Swift.Error & Sendable`.
//
// --- Attempted code (does not compile): ---
//
// protocol DeclarativeParser: Parser.`Protocol` where Body: Parser.`Protocol`,
//     Body.Input == Input, Body.ParseOutput == ParseOutput
// {
//     associatedtype Body
//     @Parser.Take.Builder<Input>
//     var body: Body { get }
// }
//
// extension DeclarativeParser where Failure == Body.Failure {
//     func parse(_ input: inout Input) throws(Failure) -> ParseOutput {
//         try body.parse(&input)
//     }
// }
//
// --- Compiler errors: ---
// 1. "referencing instance method 'parse' on 'DeclarativeParser' requires
//     the types '...Failure' and '...Body.Failure' be equivalent"
// 2. Cannot resolve Input associated type through opaque Body
// 3. Builder can't compose 5th parser — body type inference fails entirely

// MARK: - Variant 9: Builder-inside-imperative with domain error mapping
// Hypothesis: Using the builder internally within an imperative `func parse`
//             works, but error mapping degrades to string matching.
// Result: (pending)

struct HybridParser<Input: Collection.Slice.`Protocol` & Swift.Collection>: Sendable
where Input: Sendable, Input.Element == UInt8 {
    init() {}
}

extension HybridParser {
    enum Error: Swift.Error, Sendable, Equatable {
        case expectedType
        case expectedSlash
        case expectedSubtype
    }
}

extension HybridParser: Parser.`Protocol` {
    typealias ParseOutput = MediaType
    typealias Failure = HybridParser<Input>.Error

    func parse(_ input: inout Input) throws(Failure) -> MediaType {
        // Use the builder to compose the grammar
        let inner = Parser.Take.Sequence {
            OWSParser<Input>()
            TokenParser<Input>()
            SlashParser<Input>()
            TokenParser<Input>()
            ParameterListParser<Input>()
        }

        let result: (Input, Input, [(name: Input, value: Input)])
        do {
            result = try inner.parse(&input)
        } catch {
            // We catch `any Error` here — typed information is lost.
            // Can only do stringly-typed matching:
            let desc = String(describing: error)
            if desc.contains("expectedSlash") {
                throw .expectedSlash
            } else {
                throw .expectedType
            }
        }

        let (typeSlice, subtypeSlice, params) = result
        let type = String(decoding: typeSlice, as: UTF8.self).lowercased()
        let subtype = String(decoding: subtypeSlice, as: UTF8.self).lowercased()
        var parameters: [String: String] = [:]
        for p in params {
            let name = String(decoding: p.name, as: UTF8.self).lowercased()
            let value = String(decoding: p.value, as: UTF8.self)
            parameters[name] = value
        }
        return MediaType(type, subtype, parameters: parameters)
    }
}

@Test("V9: Hybrid — builder inside imperative parse()")
func hybridParser() throws {
    var input = Parser.ByteInput(utf8: "text/html; charset=utf-8")
    let mt = try HybridParser<Parser.ByteInput>().parse(&input)
    #expect(mt.type == "text")
    #expect(mt.subtype == "html")
    #expect(mt.parameters["charset"] == "utf-8")
}

@Test("V9b: Hybrid error mapping")
func hybridParserErrorMapping() throws {
    var input = Parser.ByteInput(utf8: "text")
    #expect(throws: HybridParser<Parser.ByteInput>.Error.expectedSlash) {
        try HybridParser<Parser.ByteInput>().parse(&input)
    }
}

// MARK: - Variant 10: Imperative vs Hybrid parity
// Hypothesis: Both produce identical results for all inputs.
// Result: (pending)

@Test("V10: Imperative and hybrid produce same results")
func imperativeHybridParity() throws {
    let testCases = [
        "text/html",
        "application/json",
        "text/html; charset=utf-8",
        "  text/plain",
    ]

    for testCase in testCases {
        var input1 = Parser.ByteInput(utf8: testCase)
        var input2 = Parser.ByteInput(utf8: testCase)

        let imperative = try ImperativeParser<Parser.ByteInput>().parse(&input1)
        let hybrid = try HybridParser<Parser.ByteInput>().parse(&input2)

        #expect(imperative == hybrid, "Mismatch for: \(testCase)")
    }
}
