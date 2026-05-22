//
//  Repeat.swift
//  argv-parser-protocol-spike
//
//  Result type for the Repeat-style argv parser:
//    <positional String>
//    [--count <Int>]      (default 2)
//    [--include-counter]  (default false)
//

public struct Repeat: Equatable, Sendable {
    public let phrase: String
    public let count: Int
    public let includeCounter: Bool

    public init(phrase: String, count: Int = 2, includeCounter: Bool = false) {
        self.phrase = phrase
        self.count = count
        self.includeCounter = includeCounter
    }
}
