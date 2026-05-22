//
//  Repeat.swift — Apple swift-argument-parser variant
//
//  Equivalent to swift-argument-parser/Examples/repeat/Repeat.swift.
//  Verbatim copy of the canonical ParsableCommand shape; serves as the
//  baseline for binary-size, compile-time, and parse-latency comparison.
//

import ArgumentParser

@main
struct Repeat: ParsableCommand {
  @Option(help: "The number of times to repeat 'phrase'.")
  var count: Int? = nil

  @Flag(help: "Include a counter with each repetition.")
  var includeCounter = false

  @Argument(help: "The phrase to repeat.")
  var phrase: String

  mutating func run() throws {
    let repeatCount = count ?? 2

    for i in 1...repeatCount {
      if includeCounter {
        print("\(i): \(phrase)")
      } else {
        print(phrase)
      }
    }
  }
}
