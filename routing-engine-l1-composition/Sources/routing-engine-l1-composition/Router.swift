//
//  Router.swift
//  routing-engine-l1-composition
//
//  The end-to-end composition under test.
//
//  Each case body is composed with the engine's own machinery:
//    Parser.Take.Sequence { <path> ; <query|body> }   // @Parser.Take.Builder
//      .map(<case conversion>)                          // Parser.Converted
//  giving a `Parser.Printer` (bidirectional in effect) whose Output is `Route`.
//
//  The 3-way alternative is hand-rolled (value-copy backtracking) because the
//  engine's `Parser.OneOf` requires the Input to be an `Input.Protocol` cursor,
//  which the structured `Route.Request` carrier is not. See README friction F1.
//

import Parser_Primitives

// MARK: - Case conversions (Int/Substring <-> Route, partial extract)

// Computed (not `static let`) because `Parser.Conversion.Witness` is not
// `Sendable` — it stores `apply`/`unapply` closures — so a stored global trips
// strict-concurrency's non-Sendable-global-state check. See README friction F3.
extension Route {
    /// `Int` <-> `.user(id:)`. `unapply` throws `.wrongCase` for other cases.
    static var userConversion: Parser.Conversion.Witness<Int, Route, Route.Mismatch> {
        .init(
            apply: { Route.user(id: $0) },
            unapply: { route throws(Route.Mismatch) in
                guard case let .user(id) = route else { throw .wrongCase }
                return id
            }
        )
    }

    /// `Substring` <-> `.search(term:)`.
    static var searchConversion: Parser.Conversion.Witness<Substring, Route, Route.Mismatch> {
        .init(
            apply: { Route.search(term: String($0)) },
            unapply: { route throws(Route.Mismatch) in
                guard case let .search(term) = route else { throw .wrongCase }
                return Substring(term)
            }
        )
    }

    /// `Substring` <-> `.create(body:)`.
    static var createConversion: Parser.Conversion.Witness<Substring, Route, Route.Mismatch> {
        .init(
            apply: { Route.create(body: String($0)) },
            unapply: { route throws(Route.Mismatch) in
                guard case let .create(body) = route else { throw .wrongCase }
                return Substring(body)
            }
        )
    }
}

// MARK: - Router

extension Route {
    /// A parser-printer `Route.Request <-> Route`, composed from the three
    /// case bodies. Conforms to `Parser.Bidirectional`: `parse` selects the
    /// matching case, `print` renders the route back into a fresh carrier.
    public struct Router: Parser.Bidirectional {
        public typealias Input = Route.Request
        public typealias Output = Route
        public typealias Failure = Route.Router.Fault

        /// The router's own error surface (distinct from the leaves' errors,
        /// which are swallowed by the value-copy backtracking).
        public enum Fault: Swift.Error, Equatable, Sendable {
            case noRouteMatched
            case routeNotPrintable
        }

        // Each case body is a full engine composition:
        //   Take.Sequence (Skip.First of the leaves) -> Converted (via .map).
        // Types are inferred; the concrete Failure is a nested Either but never
        // named because `parse`/`print` reach it only through the L1 protocols.
        let user = Parser.Take.Sequence {
            Route.Path.Literal("users")
            Route.Path.Integer()
        }
        .map(Route.userConversion)

        let search = Parser.Take.Sequence {
            Route.Path.Literal("search")
            Route.Query.Field("q")
        }
        .map(Route.searchConversion)

        let create = Parser.Take.Sequence {
            Route.Path.Literal("posts")
            Route.Body()
        }
        .map(Route.createConversion)

        public init() {}

        // parse: try each case with value-copy backtracking; first success wins.
        public func parse(_ input: inout Route.Request) throws(Fault) -> Route {
            var attempt = input
            if let route = try? user.parse(&attempt) { input = attempt; return route }
            attempt = input
            if let route = try? search.parse(&attempt) { input = attempt; return route }
            attempt = input
            if let route = try? create.parse(&attempt) { input = attempt; return route }
            throw .noRouteMatched
        }

        // print: try each case printer; the case conversion's `unapply` throws
        // `.wrongCase` for non-matching routes, so the first that succeeds wins.
        public func print(_ output: Route, into input: inout Route.Request) throws(Fault) {
            var attempt = input
            if (try? user.print(output, into: &attempt)) != nil { input = attempt; return }
            attempt = input
            if (try? search.print(output, into: &attempt)) != nil { input = attempt; return }
            attempt = input
            if (try? create.print(output, into: &attempt)) != nil { input = attempt; return }
            throw .routeNotPrintable
        }
    }
}
