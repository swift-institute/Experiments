// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
//
//  InlineParseErgonomicsTests.swift
//  inline-parse-ergonomics
//
//  Experiment: Validate inline parsing ergonomics proposals from
//  Research/parser-syntax-ergonomics-comparison.md
//
//  Hypotheses:
//    H1: `input.parse { ... }` works with <_, UInt16> placeholder inference
//    H2: `buildExpression` for Byte.Literal.Parser works in Parser.Take.Builder
//        (not just in test-local extensions)
//    H3: `.parsing { ... }` non-mutating variant compiles with typed throws
//    H4: Protocol composition typealias compiles and constrains correctly
//    H5: Nested parser composition works in inline context
//    H6: Error mapping works in inline context
//

import Testing
import Parser_Primitives
import Parser_Primitives_Test_Support
import ASCII_Decimal_Parser_Primitives
import Byte_Parser_Primitives
import Collection_Primitives
import Input_Primitives

// ════════════════════════════════════════════════════════════
// PROPOSAL: buildExpression for Byte.Literal.Parser (Priority 1)
//
// This belongs in Parser Take Primitives or Parser Literal Primitives.
// Currently only validated in test code. Placing it here simulates
// "production" placement (outside the test file that uses it).
// ════════════════════════════════════════════════════════════

extension Parser.Take.Builder
where Input: Input_Primitives.Input.Streaming & Sendable, Input.Element == UInt8 {
    // Concrete overload enables bare string literals (":" → Byte.Literal.Parser).
    static func buildExpression(
        _ literal: Byte.Literal.Parser<Input>
    ) -> Byte.Literal.Parser<Input> {
        literal
    }

    // Re-declare generic pass-through to prevent the Literal overload
    // from shadowing the unconstrained extension's buildExpression.
    static func buildExpression<P: Parser.`Protocol`>(
        _ parser: P
    ) -> P where P.Input == Input {
        parser
    }
}

// ════════════════════════════════════════════════════════════
// PROPOSAL: input.parse { ... } (Priority 5)
//
// Mutating — advances input past consumed portion.
// Input type provides builder context, enabling <_, T> inference.
// ════════════════════════════════════════════════════════════

extension Collection.Slice.`Protocol` where Self: Input_Primitives.Input.Streaming & Sendable {
    /// Parse inline using a builder closure. Input type is inferred from `self`.
    ///
    /// ```swift
    /// var input = Byte.Input(utf8: "80:443")
    /// let (host, port) = try input.parse {
    ///     ASCII.Decimal.Parser<_, UInt16>()
    ///     ":"
    ///     ASCII.Decimal.Parser<_, UInt16>()
    /// }
    /// ```
    @inlinable
    mutating func parse<Body: Parser.`Protocol`>(
        @Parser.Take.Builder<Self> _ build: () -> Body
    ) throws(Body.Failure) -> Body.Output where Body.Input == Self {
        try build().parse(&self)
    }
}

// ════════════════════════════════════════════════════════════
// PROPOSAL: .parsing { ... } non-mutating (Priority 5)
//
// One-shot convenience. Copies input, discards remainder.
// ════════════════════════════════════════════════════════════

extension Collection.Slice.`Protocol` where Self: Input_Primitives.Input.Streaming & Sendable {
    /// Parse inline, discarding remaining input. One-shot convenience.
    ///
    /// ```swift
    /// let (host, port) = try Byte.Input(utf8: "80:443").parsing {
    ///     ASCII.Decimal.Parser<_, UInt16>()
    ///     ":"
    ///     ASCII.Decimal.Parser<_, UInt16>()
    /// }
    /// ```
    @inlinable
    func parsing<Body: Parser.`Protocol`>(
        @Parser.Take.Builder<Self> _ build: () -> Body
    ) throws(Body.Failure) -> Body.Output where Body.Input == Self {
        var copy = self
        return try build().parse(&copy)
    }
}

// ════════════════════════════════════════════════════════════
// (H4 originally tested a `Parser.Input.Stream` typealias which was
//  deleted in the byte-extraction sister arc — Parser.Input.*
//  re-exports removed. H4's constraint test now lives inline in
//  H4Tests below, using the canonical Collection.Slice.Protocol &
//  Input.Streaming bundle directly.)
// ════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════
// Tests
// ════════════════════════════════════════════════════════════

@Suite("Inline Parse Ergonomics")
struct InlineParseErgonomicsTests {}

// MARK: - H1: input.parse { ... } with <_, UInt16> inference

extension InlineParseErgonomicsTests {
    @Suite("H1: input.parse with type placeholder inference")
    struct H1Tests {
        @Test
        func `two values with colon delimiter`() throws {
            var input = Byte.Input(utf8: "80:443")

            let (host, port) = try input.parse {
                ASCII.Decimal.Parser<_, UInt16>()
                ":"
                ASCII.Decimal.Parser<_, UInt16>()
            }

            #expect(host == 80)
            #expect(port == 443)
            #expect(input.isEmpty)
        }

        @Test
        func `three values with comma delimiter`() throws {
            var input = Byte.Input(utf8: "10,20,30")

            let (x, y, z) = try input.parse {
                ASCII.Decimal.Parser<_, UInt16>()
                ","
                ASCII.Decimal.Parser<_, UInt16>()
                ","
                ASCII.Decimal.Parser<_, UInt16>()
            }

            #expect(x == 10)
            #expect(y == 20)
            #expect(z == 30)
            #expect(input.isEmpty)
        }

        @Test
        func `preserves remaining input`() throws {
            var input = Byte.Input(utf8: "80:443/path")

            let (host, port) = try input.parse {
                ASCII.Decimal.Parser<_, UInt16>()
                ":"
                ASCII.Decimal.Parser<_, UInt16>()
            }

            #expect(host == 80)
            #expect(port == 443)
            #expect(input.first == UInt8(ascii: "/"))
        }
    }
}

// MARK: - H2: buildExpression for Byte.Literal.Parser

extension InlineParseErgonomicsTests {
    @Suite("H2: buildExpression for Byte.Literal.Parser")
    struct H2Tests {
        @Test
        func `bare string literal in builder body`() throws {
            var input = Byte.Input(utf8: "42:99")

            // If buildExpression doesn't work, this won't compile —
            // the compiler won't infer Byte.Literal.Parser<Input.Bytes> from ":"
            let (a, b) = try input.parse {
                ASCII.Decimal.Parser<_, UInt16>()
                ":"
                ASCII.Decimal.Parser<_, UInt16>()
            }

            #expect(a == 42)
            #expect(b == 99)
        }

        @Test
        func `multiple different delimiters`() throws {
            var input = Byte.Input(utf8: "1-2")

            let (a, b) = try input.parse {
                ASCII.Decimal.Parser<_, UInt16>()
                "-"
                ASCII.Decimal.Parser<_, UInt16>()
            }

            #expect(a == 1)
            #expect(b == 2)
        }
    }
}

// MARK: - H3: .parsing { ... } non-mutating with typed throws

extension InlineParseErgonomicsTests {
    @Suite("H3: .parsing non-mutating variant")
    struct H3Tests {
        @Test
        func `one-shot parsing discards remainder`() throws {
            let (host, port) = try Byte.Input(utf8: "80:443").parsing {
                ASCII.Decimal.Parser<_, UInt16>()
                ":"
                ASCII.Decimal.Parser<_, UInt16>()
            }

            #expect(host == 80)
            #expect(port == 443)
        }

        @Test
        func `typed error propagation`() {
            // Verify that the error type is concrete, not any Error
            let result: Result<(UInt16, UInt16), _> = Result {
                try Byte.Input(utf8: "abc:443").parsing {
                    ASCII.Decimal.Parser<_, UInt16>()
                    ":"
                    ASCII.Decimal.Parser<_, UInt16>()
                }
            }

            switch result {
            case .success:
                Issue.record("Should have failed")
            case .failure:
                break // Expected — typed error propagated
            }
        }

        @Test
        func `three values one-shot`() throws {
            let (x, y, z) = try Byte.Input(utf8: "1,2,3").parsing {
                ASCII.Decimal.Parser<_, UInt16>()
                ","
                ASCII.Decimal.Parser<_, UInt16>()
                ","
                ASCII.Decimal.Parser<_, UInt16>()
            }

            #expect(x == 1)
            #expect(y == 2)
            #expect(z == 3)
        }
    }
}

// MARK: - H4: Protocol composition constraint

extension InlineParseErgonomicsTests {
    @Suite("H4: Protocol composition constraint")
    struct H4Tests {
        // Originally tested the `Parser.Input.Stream` typealias (deleted in
        // byte-extraction sister arc — Parser.Input.* re-exports removed).
        // Now expanded to the canonical constraint bundle inline.
        struct TestParser<Input: Collection.Slice.`Protocol` & Input_Primitives.Input.Streaming>: Sendable
        where Input.Element == UInt8 {
            init() {}
        }

        @Test
        func `constraint bundle compiles for Byte.Input`() {
            // Byte.Input satisfies both Collection.Slice.Protocol and Input.Streaming.
            let _ = TestParser<Byte.Input>()
        }
    }
}

// MARK: - H5: Nested parser composition in inline context

struct EndpointOutput: Equatable, Sendable {
    let host: UInt16
    let port: UInt16
}

/// A reusable composed parser — leaf implementation (func parse).
/// Tests that reusable parsers can be used inside input.parse { ... }.
struct EndpointParser<Input: Collection.Slice.`Protocol` & Input_Primitives.Input.Streaming>: Sendable
where Input: Sendable, Input.Element == UInt8 {
    init() {}
}

extension EndpointParser: Parser.`Protocol` {
    typealias Output = EndpointOutput
    typealias Failure = Either<
        Either<ASCII.Decimal.Error, Byte.Literal.Parser<Input>.Failure>,
        ASCII.Decimal.Error
    >

    func parse(_ input: inout Input) throws(Failure) -> Output {
        let host: UInt16
        do { host = try ASCII.Decimal.Parser<Input, UInt16>().parse(&input) }
        catch { throw .left(.left(error)) }
        do { try Byte.Literal.Parser<Input>(":").parse(&input) }
        catch { throw .left(.right(error)) }
        let port: UInt16
        do { port = try ASCII.Decimal.Parser<Input, UInt16>().parse(&input) }
        catch { throw .right(error) }
        return EndpointOutput(host: host, port: port)
    }
}

extension InlineParseErgonomicsTests {
    @Suite("H5: Nested composition inline")
    struct H5Tests {
        @Test
        func `nested composed parser in inline parse`() throws {
            var input = Byte.Input(utf8: "80:443/10")

            let (endpoint, weight) = try input.parse {
                EndpointParser<Byte.Input>()
                "/"
                ASCII.Decimal.Parser<_, UInt16>()
            }

            #expect(endpoint == EndpointOutput(host: 80, port: 443))
            #expect(weight == 10)
            #expect(input.isEmpty)
        }

        @Test
        func `nested composed parser one-shot`() throws {
            let (endpoint, weight) = try Byte.Input(utf8: "80:443/10").parsing {
                EndpointParser<Byte.Input>()
                "/"
                ASCII.Decimal.Parser<_, UInt16>()
            }

            #expect(endpoint == EndpointOutput(host: 80, port: 443))
            #expect(weight == 10)
        }
    }
}

// MARK: - H6: Error mapping in inline context

extension InlineParseErgonomicsTests {
    @Suite("H6: Error mapping inline")
    struct H6Tests {
        @Test
        func `error.map works on inline parse result`() throws {
            // Build a parser inline, then map errors
            enum EndpointError: Error, Sendable, Equatable {
                case invalidHost
                case expectedColon
                case invalidPort
            }

            let parser = Parser.Take.Sequence {
                ASCII.Decimal.Parser<Byte.Input, UInt16>()
                ":" as Byte.Literal.Parser<Byte.Input>
                ASCII.Decimal.Parser<Byte.Input, UInt16>()
            }
            .error.map { (either) -> EndpointError in
                switch either {
                case .right:        .invalidPort
                case .left(.left):  .invalidHost
                case .left(.right): .expectedColon
                }
            }

            var input = Byte.Input(utf8: "abc:80")
            #expect(throws: EndpointError.invalidHost) {
                try parser.parse(&input)
            }
        }
    }
}
