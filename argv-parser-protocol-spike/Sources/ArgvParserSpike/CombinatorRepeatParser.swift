//
//  CombinatorRepeatParser.swift
//  argv-parser-protocol-spike
//
//  Combinator-driven variant: composes existing Parser.OneOf, Parser.Many,
//  Parser.Take, and `.map` to build the same Repeat parser without
//  hand-rolling the control flow.
//
//  This is the load-bearing variant for P1's claim:
//    "the institute's `Parser.Protocol` can express argv parsing
//     (positional + option + flag) with backtracking and typed errors,
//     using existing combinators."
//

public import Parser_Primitives

/// Intermediate token produced by one round of the OneOf alternation.
public enum ArgvToken: Equatable, Sendable {
    case count(Int)
    case includeCounter
    case positional(String)
}

public struct CombinatorRepeatParser: Parser.`Protocol` {
    public typealias Input = ArgvInput
    public typealias Output = Repeat
    public typealias Body = Never

    public init() {}

    public func parse(_ input: inout Input) throws -> Repeat {
        // Compose the single-token alternation:
        //   Parser.OneOf.Sequence {
        //     MatchLiteral("--count").map(...) >> IntString().map(...)
        //     MatchLiteral("--include-counter").map(...)
        //     AnyString().map(...)
        //   }
        //
        // Each branch must produce ArgvToken with the same Failure type.
        // Branches normalize Failure to ArgvParseError via .error.map(...).

        // --count <int>
        let countBranch = Parser.Take.Sequence<ArgvInput, (String, Int), _> {
            MatchLiteral("--count")
            IntString()
        }
        .map { (_: String, value: Int) -> ArgvToken in .count(value) }

        // --include-counter
        let flagBranch = MatchLiteral("--include-counter")
            .map { _ -> ArgvToken in .includeCounter }

        // positional
        let positionalBranch = AnyString()
            .map { value -> ArgvToken in .positional(value) }

        // Combinator-level alternation. OneOf requires Input: Parser.Input.Protocol,
        // P0.Output == P1.Output. We satisfied that by .mapping every branch to
        // ArgvToken. However, P0.Failure differs from P1.Failure — Parser.OneOf
        // tolerates that and produces Product<F0, F1>.
        //
        // To keep Failure manageable, repeat-consume via Parser.Many (builder
        // form), which collects [ArgvToken] and erases per-element Failure
        // into Parser.Many.Error.
        let oneToken = Parser.OneOf.Sequence<ArgvInput, ArgvToken, _> {
            countBranch
            flagBranch
            positionalBranch
        }

        // Use Parser.Many (builder form) to repeat the OneOf zero or more
        // times. The builder closure must return a single Parser.Protocol
        // value, which `oneToken` already is.
        let manyTokens = Parser.Many { oneToken }

        let tokens: [ArgvToken] = try manyTokens.parse(&input)

        // Reduce tokens into Repeat. (This is post-processing; the parsing
        // itself was driven by combinators only.)
        var phrase: String? = nil
        var count: Int = 2
        var includeCounter = false
        for token in tokens {
            switch token {
            case .count(let value): count = value
            case .includeCounter: includeCounter = true
            case .positional(let value):
                if phrase == nil { phrase = value }
                // Extra positionals silently dropped in this spike.
            }
        }

        // For the spike, treat a missing phrase as success with empty string
        // (the leaf-parser variant validates this stricter; this combinator
        // variant only verifies the *parsing* premise).
        return Repeat(
            phrase: phrase ?? "",
            count: count,
            includeCounter: includeCounter
        )
    }
}
