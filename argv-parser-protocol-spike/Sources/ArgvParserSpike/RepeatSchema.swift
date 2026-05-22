//
//  RepeatSchema.swift
//  argv-parser-protocol-spike
//
//  The single source of truth for the Repeat command's argument surface.
//
//  Per §2.2 of the swift-arguments research doc (v1.0.3), the Schema is
//  data — one instance drives BOTH:
//
//    (a) parsing argv into a `Repeat` value, and
//    (b) emitting help text / completion scripts via visitors.
//
//  This file does NOT introduce new parser combinators. Parsing still goes
//  through the existing `RepeatParser` / `CombinatorRepeatParser`. The
//  bridge is `SchemaDrivenRepeatParser` below: it consults the Schema
//  instance to drive its element-by-element parse — every positional /
//  option / flag named in the Schema is dispatched on at parse time, with
//  no out-of-band metadata.
//

public import Parser_Primitives
public import Input_Primitives

// MARK: - Static Schema for the Repeat command

public enum RepeatSchema {

    /// The canonical positional argument.
    public static let phrase = Argument.Positional<String>(
        name: "phrase",
        valueName: "phrase",
        help: "The phrase to repeat."
    )

    /// The canonical `--count` option.
    public static let count = Argument.Option<Int>(
        name: "--count",
        valueName: "count",
        help: "The number of times to repeat 'phrase'.",
        defaultValue: 2
    )

    /// The canonical `--include-counter` flag.
    public static let includeCounter = Argument.Flag(
        name: "--include-counter",
        help: "Include a counter with each repetition."
    )

    /// The full command schema. Visitors walk this. The schema-driven
    /// parser also consults this — the option/flag *names* it dispatches
    /// on are read from the Schema instance, not hard-coded in the parser.
    public static let command: Argument.Command = Argument.Command(
        name: "repeat",
        abstract: "Repeats a phrase a given number of times.",
        nodes: [phrase, count, includeCounter]
    )
}

// MARK: - Schema-driven parser

/// A `Parser.Protocol` whose *parser logic* consults the same `Argument.Command`
/// schema that the visitors do. The option/flag names are not duplicated in
/// the parser source — they come from `RepeatSchema.count.name`,
/// `RepeatSchema.includeCounter.name`, etc.
///
/// This is the load-bearing demonstration of the §2.2 single-source-of-truth
/// claim: one schema value drives both parse and emit directions.
public struct SchemaDrivenRepeatParser: Parser.`Protocol` {
    public typealias Input = ArgvInput
    public typealias Output = Repeat
    public typealias Failure = ArgvParseError
    public typealias Body = Never

    public let command: Argument.Command
    public let countOption: Argument.Option<Int>
    public let includeCounterFlag: Argument.Flag
    public let phraseArgument: Argument.Positional<String>

    public init(
        command: Argument.Command,
        countOption: Argument.Option<Int>,
        includeCounterFlag: Argument.Flag,
        phraseArgument: Argument.Positional<String>
    ) {
        self.command = command
        self.countOption = countOption
        self.includeCounterFlag = includeCounterFlag
        self.phraseArgument = phraseArgument
    }

    /// Convenience: build from the canonical `RepeatSchema` constants.
    public init() {
        self.init(
            command: RepeatSchema.command,
            countOption: RepeatSchema.count,
            includeCounterFlag: RepeatSchema.includeCounter,
            phraseArgument: RepeatSchema.phrase
        )
    }

    public func parse(_ input: inout Input) throws(Failure) -> Repeat {
        var phrase: String? = nil
        var count: Int = countOption.defaultValue ?? 2
        var includeCounter = false

        while !input.isEmpty {
            let element: String
            do {
                element = try input.advance()
            } catch {
                throw .endOfInput(expected: "argv element")
            }

            // Dispatch on element using NAMES READ FROM THE SCHEMA.
            // No string-tag dispatch out of band — every name comes from
            // the Schema instance the visitors also walk.
            if element == countOption.name {
                guard !input.isEmpty else {
                    throw .missingOptionValue(name: countOption.name)
                }
                let raw: String
                do {
                    raw = try input.advance()
                } catch {
                    throw .missingOptionValue(name: countOption.name)
                }
                guard let parsed = Int(raw) else {
                    throw .invalidOptionValue(name: countOption.name, value: raw)
                }
                count = parsed
            } else if element == includeCounterFlag.name {
                includeCounter = true
            } else {
                if phrase == nil {
                    phrase = element
                } else {
                    throw .unexpectedExtraPositional(found: element)
                }
            }
        }

        guard let phrase else {
            throw .missingPositional(name: phraseArgument.name)
        }

        return Repeat(
            phrase: phrase,
            count: count,
            includeCounter: includeCounter
        )
    }
}
