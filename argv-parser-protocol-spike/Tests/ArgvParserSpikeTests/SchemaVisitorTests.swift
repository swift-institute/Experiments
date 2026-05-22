//
//  SchemaVisitorTests.swift
//  argv-parser-protocol-spike
//
//  Tests for P2: a visitor over the parsed Schema can emit (a) formatted
//  help text and (b) a minimal bash-completion script for the same
//  `Repeat` example without ad-hoc reflection or string-tag dispatch.
//

import ArgvParserSpike
import Testing

@Suite("HelpVisitor (P2 verification — help-text emission)")
struct HelpVisitorTests {

    @Test("Help visitor produces expected help text for Repeat")
    func helpTextForRepeat() throws {
        var visitor = HelpVisitor()
        RepeatSchema.command.accept(&visitor)
        let helpText = visitor.render(for: RepeatSchema.command)

        let expected = """
        USAGE: repeat [--count <count>] [--include-counter] <phrase>

        ARGUMENTS:
          <phrase>                  The phrase to repeat.

        OPTIONS:
          --count <count>           The number of times to repeat 'phrase'. (default: 2)
          --include-counter         Include a counter with each repetition.
          -h, --help                Show help information.

        """

        #expect(helpText == expected)
    }
}

@Suite("BashCompletionVisitor (P2 verification — completion-script emission)")
struct BashCompletionVisitorTests {

    @Test("Bash completion visitor produces well-formed completion script")
    func bashCompletionForRepeat() throws {
        var visitor = BashCompletionVisitor()
        RepeatSchema.command.accept(&visitor)
        let script = visitor.render(for: RepeatSchema.command)

        // Well-formed checks:
        // 1. Has a shebang line.
        #expect(script.hasPrefix("#!/usr/bin/env bash\n"))

        // 2. Declares the per-command completion function.
        #expect(script.contains("_repeat_completion() {"))

        // 3. References the option/flag long-names from the Schema.
        #expect(script.contains("--count"))
        #expect(script.contains("--include-counter"))
        #expect(script.contains("--help"))

        // 4. Registers the function against the command.
        #expect(script.contains("complete -F _repeat_completion repeat"))

        // 5. Uses compgen for prefix-filtered completion.
        #expect(script.contains("compgen -W"))
    }
}

@Suite("Schema bidirectionality (P2 — single source of truth)")
struct SchemaBidirectionalityTests {

    @Test("Same Schema drives both parsing and emission")
    func schemaDrivesParseAndEmit() throws {
        // The same `RepeatSchema.command` instance is consulted for:
        //   (a) parsing argv into a Repeat value, and
        //   (b) emitting help text and completion script.
        // No metadata duplication, no string-tag dispatch out of band.

        // (a) Parse argv using the schema-driven parser.
        let parser = SchemaDrivenRepeatParser()
        var input = ArgvInput(argv: ["--count", "5", "--include-counter", "hello"])
        let parsed = try parser.parse(&input)
        #expect(parsed == Repeat(phrase: "hello", count: 5, includeCounter: true))

        // (b1) Emit help text from the same schema instance.
        var help = HelpVisitor()
        parser.command.accept(&help)
        let helpText = help.render(for: parser.command)
        #expect(helpText.contains("--count <count>"))
        #expect(helpText.contains("--include-counter"))
        #expect(helpText.contains("<phrase>"))

        // (b2) Emit a completion script from the same schema instance.
        var completion = BashCompletionVisitor()
        parser.command.accept(&completion)
        let script = completion.render(for: parser.command)
        #expect(script.contains("--count"))
        #expect(script.contains("--include-counter"))
        #expect(script.contains("complete -F _repeat_completion repeat"))

        // (c) Sanity: the schema instance is by value-identity the same
        // canonical RepeatSchema.command — no parallel copies were
        // introduced. (Equality of nodes by name as a structural proxy.)
        #expect(parser.command.name == RepeatSchema.command.name)
        #expect(parser.command.nodes.count == RepeatSchema.command.nodes.count)
        // The parser's option name comes from the schema, not a literal.
        #expect(parser.countOption.name == "--count")
        #expect(parser.includeCounterFlag.name == "--include-counter")
    }

    @Test("Parsing with default count uses Schema's defaultValue")
    func defaultCountFromSchema() throws {
        // Verifies that the default consumed by the schema-driven parser
        // is the same one the help visitor advertises.
        let parser = SchemaDrivenRepeatParser()
        var input = ArgvInput(argv: ["hi"])
        let parsed = try parser.parse(&input)
        #expect(parsed.count == 2)
        #expect(parsed.count == RepeatSchema.count.defaultValue)
    }
}
