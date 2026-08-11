extension Showcase {
    public struct Parser: Sendable {
        public init() {}

        public func parse(_ input: String) -> [Token] {
            input.split(separator: " ").map { word in
                Token(value: String(word))
            }
        }
    }
}

extension Showcase.Parser {
    public struct Token: Sendable, Equatable {
        public var value: String
    }
}
