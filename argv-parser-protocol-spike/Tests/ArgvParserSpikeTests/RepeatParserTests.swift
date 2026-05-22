//
//  RepeatParserTests.swift
//  argv-parser-protocol-spike
//

import ArgvParserSpike
import Testing

// MARK: - Leaf-style parser

@Suite("RepeatParser (leaf variant, P1 verification)")
struct RepeatParserTests {

    @Test("positional only: [hello]")
    func positionalOnly() throws {
        let parser = RepeatParser()
        var input = ArgvInput(argv: ["hello"])

        let result = try parser.parse(&input)

        #expect(result == Repeat(phrase: "hello", count: 2, includeCounter: false))
    }

    @Test("option then positional: [--count, 3, hello]")
    func optionThenPositional() throws {
        let parser = RepeatParser()
        var input = ArgvInput(argv: ["--count", "3", "hello"])

        let result = try parser.parse(&input)

        #expect(result == Repeat(phrase: "hello", count: 3, includeCounter: false))
    }

    @Test("flag then positional: [--include-counter, hi]")
    func flagThenPositional() throws {
        let parser = RepeatParser()
        var input = ArgvInput(argv: ["--include-counter", "hi"])

        let result = try parser.parse(&input)

        #expect(result == Repeat(phrase: "hi", count: 2, includeCounter: true))
    }
}

// MARK: - Combinator-driven parser

@Suite("CombinatorRepeatParser (combinator variant, P1 verification)")
struct CombinatorRepeatParserTests {

    @Test("positional only: [hello]")
    func positionalOnly() throws {
        let parser = CombinatorRepeatParser()
        var input = ArgvInput(argv: ["hello"])

        let result = try parser.parse(&input)

        #expect(result == Repeat(phrase: "hello", count: 2, includeCounter: false))
    }

    @Test("option then positional: [--count, 3, hello]")
    func optionThenPositional() throws {
        let parser = CombinatorRepeatParser()
        var input = ArgvInput(argv: ["--count", "3", "hello"])

        let result = try parser.parse(&input)

        #expect(result == Repeat(phrase: "hello", count: 3, includeCounter: false))
    }

    @Test("flag then positional: [--include-counter, hi]")
    func flagThenPositional() throws {
        let parser = CombinatorRepeatParser()
        var input = ArgvInput(argv: ["--include-counter", "hi"])

        let result = try parser.parse(&input)

        #expect(result == Repeat(phrase: "hi", count: 2, includeCounter: true))
    }
}
