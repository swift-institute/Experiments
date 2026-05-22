//
//  ArgvLeafParsers.swift
//  argv-parser-protocol-spike
//
//  Small leaf parsers over `ArgvInput` (`Element == String`). These are the
//  building blocks that the combinator-driven `Repeat.Parser` composes.
//
//  These are intentionally NOT new core combinators — each one only consumes
//  a single `String` element from `Input.Protocol`. Composition is then
//  handled by `Parser.OneOf`, `Parser.Many.Simple`, and `.map` from
//  `swift-parser-primitives` directly.
//

public import Parser_Primitives
public import Input_Primitives

// MARK: - MatchLiteral

/// A leaf parser that consumes the next `String` iff it equals `expected`.
/// On mismatch (or end of input), restores the cursor via the supplied
/// checkpoint and throws.
public struct MatchLiteral: Parser.`Protocol` {
    public typealias Input = ArgvInput
    public typealias Output = String
    public typealias Failure = ArgvParseError
    public typealias Body = Never

    public let expected: String

    public init(_ expected: String) {
        self.expected = expected
    }

    public func parse(_ input: inout Input) throws(Failure) -> String {
        let checkpoint = input.checkpoint
        guard !input.isEmpty else {
            throw .endOfInput(expected: expected)
        }
        let element: String
        do {
            element = try input.advance()
        } catch {
            throw .endOfInput(expected: expected)
        }
        guard element == expected else {
            input.restore.to(__unchecked: (), checkpoint)
            throw .literalMismatch(expected: expected, found: element)
        }
        return element
    }
}

// MARK: - AnyString

/// A leaf parser that consumes the next `String` unconditionally.
public struct AnyString: Parser.`Protocol` {
    public typealias Input = ArgvInput
    public typealias Output = String
    public typealias Failure = ArgvParseError
    public typealias Body = Never

    public init() {}

    public func parse(_ input: inout Input) throws(Failure) -> String {
        guard !input.isEmpty else {
            throw .endOfInput(expected: "any string")
        }
        do {
            return try input.advance()
        } catch {
            throw .endOfInput(expected: "any string")
        }
    }
}

// MARK: - IntString

/// A leaf parser that consumes the next `String` and parses it as `Int`.
public struct IntString: Parser.`Protocol` {
    public typealias Input = ArgvInput
    public typealias Output = Int
    public typealias Failure = ArgvParseError
    public typealias Body = Never

    public init() {}

    public func parse(_ input: inout Input) throws(Failure) -> Int {
        let checkpoint = input.checkpoint
        guard !input.isEmpty else {
            throw .endOfInput(expected: "integer")
        }
        let raw: String
        do {
            raw = try input.advance()
        } catch {
            throw .endOfInput(expected: "integer")
        }
        guard let value = Int(raw) else {
            input.restore.to(__unchecked: (), checkpoint)
            throw .invalidOptionValue(name: "<int>", value: raw)
        }
        return value
    }
}
