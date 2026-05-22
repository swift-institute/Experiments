//
//  RepeatParser.swift
//  argv-parser-protocol-spike
//
//  Leaf Parser.Protocol implementation parsing argv into a Repeat value.
//
//  This is a leaf parser (no `body`) — it consumes one `String` at a time
//  from `Input.Protocol`, using checkpoint/restore for backtracking when
//  trying to decide whether the next element is an option, a flag, or
//  the positional phrase.
//
//  The premise we are verifying: `Parser.Protocol` (with `Element == String`)
//  supports CLI argv parsing with backtracking and typed errors.
//

public import Parser_Primitives
public import Input_Primitives

public struct RepeatParser: Parser.`Protocol` {
    public typealias Input = ArgvInput
    public typealias Output = Repeat
    public typealias Failure = ArgvParseError
    public typealias Body = Never

    public init() {}

    public func parse(_ input: inout Input) throws(Failure) -> Repeat {
        var phrase: String? = nil
        var count: Int = 2
        var includeCounter: Bool = false

        // Walk argv element by element. For each, decide:
        //   * "--count" → expect value, parse as Int.
        //   * "--include-counter" → set flag.
        //   * otherwise → positional phrase.
        while !input.isEmpty {
            // Save checkpoint so backtracking is possible if a parse branch
            // chooses incorrectly (not strictly needed for this grammar, but
            // we want the test to exercise the checkpoint machinery to verify
            // P1's backtracking claim).
            let checkpoint = input.checkpoint

            let element: String
            do {
                element = try input.advance()
            } catch {
                // Should not happen because isEmpty was false, but be total.
                throw .endOfInput(expected: "argv element")
            }

            switch element {
            case "--count":
                // Need a value next.
                guard !input.isEmpty else {
                    // Restore and report missing value.
                    input.restore.to(__unchecked: (), checkpoint)
                    throw .missingOptionValue(name: "--count")
                }
                let raw: String
                do {
                    raw = try input.advance()
                } catch {
                    throw .missingOptionValue(name: "--count")
                }
                guard let parsed = Int(raw) else {
                    throw .invalidOptionValue(name: "--count", value: raw)
                }
                count = parsed

            case "--include-counter":
                includeCounter = true

            default:
                if phrase == nil {
                    phrase = element
                } else {
                    throw .unexpectedExtraPositional(found: element)
                }
            }
        }

        guard let phrase else {
            throw .missingPositional(name: "phrase")
        }

        return Repeat(phrase: phrase, count: count, includeCounter: includeCounter)
    }
}

// MARK: - Typed error

public enum ArgvParseError: Error, Equatable, Sendable {
    case endOfInput(expected: String)
    case missingOptionValue(name: String)
    case invalidOptionValue(name: String, value: String)
    case missingPositional(name: String)
    case unexpectedExtraPositional(found: String)
    case literalMismatch(expected: String, found: String)
}
