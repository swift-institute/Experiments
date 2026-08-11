// Typealias nested inside generic struct
extension Parser.Error.Located {
    public typealias `Protocol` = __ParserErrorLocatedProtocol
}

// Conformance uses hoisted name directly (avoids self-referential cycle)
extension Parser.Error.Located: __ParserErrorLocatedProtocol {}
