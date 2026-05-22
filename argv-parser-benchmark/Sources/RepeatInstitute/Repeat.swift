//
//  Repeat.swift — institute Parser.Protocol variant
//
//  Result struct mirroring the swift-argument-parser canonical Repeat shape:
//    <positional String>
//    [--count <Int>]      (default 2)
//    [--include-counter]  (default false)
//
//  Verbatim copy from argv-parser-protocol-spike/Sources/ArgvParserSpike/Repeat.swift.
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
