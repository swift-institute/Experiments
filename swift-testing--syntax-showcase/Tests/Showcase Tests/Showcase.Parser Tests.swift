// ===----------------------------------------------------------------------===//
//
// Syntax Showcase — Parser Tests
//
// Demonstrates trait composition: combining .timed with .tag,
// .serialized with .timeLimit, and snapshot strategies for
// structured data.
//
// ===----------------------------------------------------------------------===//

import Testing
import Showcase

// Default snapshot configuration (recording: .missing)

extension Showcase.Parser {
    #Tests
}

// MARK: - Unit Tests

extension Showcase.Parser.Test.Unit {
    @Test
    func parses_words() {
        let tokens = Showcase.Parser().parse("hello world")

        #expect(tokens.count == 2)
        #expect(tokens[0].value == "hello")
        #expect(tokens[1].value == "world")
    }

    @Test
    func empty_input_yields_no_tokens() {
        let tokens = Showcase.Parser().parse("")

        #expect(tokens.isEmpty)
    }
}

// MARK: - Edge Case Tests

extension Showcase.Parser.Test.EdgeCase {
    @Test
    func consecutive_spaces_produce_empty_tokens() {
        let tokens = Showcase.Parser().parse("a  b")

        // split(separator:) omits empty subsequences by default
        #expect(tokens.count == 2)
    }

    @Test
    func single_word_input() {
        let tokens = Showcase.Parser().parse("hello")

        #expect(tokens.count == 1)
        #expect(tokens[0].value == "hello")
    }
}

// MARK: - Performance Tests with Trait Composition

extension Showcase.Parser.Test.Performance {

    // .timed + .tag: tagged for CI benchmark filtering
    @Test(.timed(iterations: 50, warmup: 5), .tag("benchmark"))
    func tokenization_throughput() {
        let parser = Showcase.Parser()
        let input = (0..<100).map { "word\($0)" }.joined(separator: " ")

        for _ in 0..<1_000 {
            _ = parser.parse(input)
        }
    }

    // .timed + .timeLimit: fail fast if a single run exceeds the limit
    @Test(.timed(iterations: 20), .timeLimit(.seconds(5)))
    func does_not_hang_on_large_input() {
        let parser = Showcase.Parser()
        let input = String(repeating: "word ", count: 10_000)

        _ = parser.parse(input)
    }
}

// MARK: - Snapshot Tests

extension Showcase.Parser.Test.Snapshot {

    // Snapshot token list via pullback from [Token] → String
    @Test
    func token_output_format() {
        let strategy = Test.Snapshot.Strategy<String, String>.lines
            .pullback { (tokens: [Showcase.Parser.Token]) in
                tokens.enumerated().map { i, token in
                    "[\(i)] \(token.value)"
                }.joined(separator: "\n")
            }

        let tokens = Showcase.Parser().parse("the quick brown fox")

        snapshot(tokens, as: strategy)
    }

    // Named snapshots for different input classes
    @Test
    func input_categories() {
        let parser = Showcase.Parser()

        let format: (String) -> String = { input in
            let tokens = parser.parse(input)
            return tokens.map(\.value).joined(separator: " | ")
        }

        snapshot(format("hello world"), as: .lines, named: "simple")
        snapshot(format("a b c d e"), as: .lines, named: "many_tokens")
        snapshot(format("single"), as: .lines, named: "single_token")
    }
}
