//
//  Leaves.swift
//  routing-engine-l1-composition
//
//  Leaf parser-printers over the `Route.Request` carrier. Each conforms to
//  `Parser.Bidirectional` (hence both `Parser.Protocol` and `Parser.Printer`),
//  which is what lets the engine's `Skip`/`Take` sequencing propagate
//  printability up through the composed body.
//

import Parser_Primitives

// MARK: - Namespaces

extension Route {
    /// Namespace for path-component parser-printers.
    public enum Path {}
    /// Namespace for query-field parser-printers.
    public enum Query {}
}

// MARK: - Path.Literal — matches a fixed path segment (Output == Void)

extension Route.Path {
    /// Matches and consumes a single fixed path segment; prints it back.
    public struct Literal: Parser.Bidirectional {
        public typealias Input = Route.Request
        public typealias Output = Void
        public typealias Failure = Parser.Match.Error

        public let value: String

        public init(_ value: String) {
            self.value = value
        }

        public func parse(_ input: inout Route.Request) throws(Parser.Match.Error) {
            guard let first = input.path.first, first == value[...] else {
                throw .literalMismatch(
                    expected: value,
                    found: input.path.first.map(String.init) ?? "<empty>"
                )
            }
            input.path.removeFirst()
        }

        public func print(_ output: Void, into input: inout Route.Request) throws(Parser.Match.Error) {
            input.path.insert(value[...], at: 0)
        }
    }
}

// MARK: - Path.Integer — one path segment as Int (Output == Int)

extension Route.Path {
    /// Consumes a single path segment and parses it as `Int`; prints it back.
    public struct Integer: Parser.Bidirectional {
        public typealias Input = Route.Request
        public typealias Output = Int
        public typealias Failure = Parser.Match.Error

        public init() {}

        public func parse(_ input: inout Route.Request) throws(Parser.Match.Error) -> Int {
            guard let first = input.path.first, let value = Int(first) else {
                throw .predicateFailed(description: "integer path segment")
            }
            input.path.removeFirst()
            return value
        }

        public func print(_ output: Int, into input: inout Route.Request) throws(Parser.Match.Error) {
            input.path.insert(Substring(String(output)), at: 0)
        }
    }
}

// MARK: - Query.Field — a keyed query field (Output == Substring)

extension Route.Query {
    /// Reads and removes a query field by name; prints it back.
    public struct Field: Parser.Bidirectional {
        public typealias Input = Route.Request
        public typealias Output = Substring
        public typealias Failure = Parser.Match.Error

        public let name: String

        public init(_ name: String) {
            self.name = name
        }

        public func parse(_ input: inout Route.Request) throws(Parser.Match.Error) -> Substring {
            guard let value = input.query[name] else {
                throw .predicateFailed(description: "query field '\(name)'")
            }
            input.query[name] = nil
            return value
        }

        public func print(_ output: Substring, into input: inout Route.Request) throws(Parser.Match.Error) {
            input.query[name] = output
        }
    }
}

// MARK: - Body — the request body payload (Output == Substring)

extension Route {
    /// Consumes the request body; prints it back.
    public struct Body: Parser.Bidirectional {
        public typealias Input = Route.Request
        public typealias Output = Substring
        public typealias Failure = Parser.Match.Error

        public init() {}

        public func parse(_ input: inout Route.Request) throws(Parser.Match.Error) -> Substring {
            guard let value = input.body else {
                throw .predicateFailed(description: "request body")
            }
            input.body = nil
            return value
        }

        public func print(_ output: Substring, into input: inout Route.Request) throws(Parser.Match.Error) {
            input.body = output
        }
    }
}
