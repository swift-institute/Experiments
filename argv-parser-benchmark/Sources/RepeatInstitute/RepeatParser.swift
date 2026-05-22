//
//  RepeatParser.swift — institute Parser.Protocol variant
//
//  Leaf Parser.Protocol implementation parsing argv into a Repeat value.
//  Verbatim copy from argv-parser-protocol-spike/Sources/ArgvParserSpike/RepeatParser.swift.
//
//  Walks argv element-by-element, using checkpoint/restore for backtracking.
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

        while !input.isEmpty {
            let checkpoint = input.checkpoint

            let element: String
            do {
                element = try input.advance()
            } catch {
                throw .endOfInput(expected: "argv element")
            }

            switch element {
            case "--count":
                guard !input.isEmpty else {
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
