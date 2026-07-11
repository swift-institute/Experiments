//
//  Model.swift
//  routing-engine-l1-composition
//
//  Spike A — routing-arc W2 de-risk.
//
//  Purpose:    Prove (or refute) that an end-to-end Route body — Path + Query +
//              Body composition — round-trips on the institute L1 parsing engine
//              `swift-parser-primitives` (Parser.Protocol / Parser.Printer /
//              Parser.Bidirectional, @Parser.Builder, Take/Skip/Always,
//              Parser.Conversion.*), in BOTH directions:
//                (1) parse  : URI-request carrier  -> route value
//                (2) print  : route value          -> URI-request carrier
//  Hypothesis: A minimal 3-case route enum (path param / query param / body
//              payload) composes on the L1 engine and round-trips both ways.
//
//  Toolchain:  Apple Swift 6.3.3 (swiftlang-6.3.3.1.3), plain env (no TOOLCHAINS).
//  Platform:   macOS 26 (arm64)
//  Status:     CONFIRMED — see README.md verdict + friction list.
//  Result:     CONFIRMED — round-trip holds in both directions (parse∘print and
//              print∘parse) for all three cases; see RoundTripTests.
//  Date:       2026-07-11
//

import Parser_Primitives

// MARK: - Route model (the "route value")

/// A minimal route enum standing in for a downstream router's `AppRoute`.
///
/// Three cases exercise the three composition axes named by the spike:
///   * `.user`   — a **path parameter**            `/users/:id`
///   * `.search` — a **query parameter**           `/search?q=:term`
///   * `.create` — a **body payload**              `/posts` + request body
///
/// Case embed/extract is closure-based (via `Parser.Conversion.Witness`); the
/// `@Cases` macro is a separate spike and is deliberately not built here.
public enum Route: Equatable, Sendable {
    case user(id: Int)
    case search(term: String)
    case create(body: String)
}

// MARK: - Request carrier (the parser `Input`)

extension Route {
    /// A `URLRequestData`-shaped carrier: the value threaded as the parser
    /// `Input`. Faithful-in-miniature to `RFC_3986.URI.Request.Data` — path
    /// segments consumed front-to-back, keyed query fields, an optional body.
    ///
    /// It is an ordinary `Copyable` value type. That is load-bearing: the
    /// engine's alternative combinator (`Parser.OneOf`) requires the `Input` to
    /// be an `Input.Protocol` cursor (checkpoint/restore over a linear element
    /// stream), which a structured request carrier cannot satisfy — so the
    /// router hand-rolls value-copy backtracking. See README friction F1.
    public struct Request: Equatable, Sendable {
        /// Path segments, consumed from the front on parse, prepended on print.
        public var path: [Substring]
        /// Query fields, read/removed on parse, set on print. Order-independent.
        public var query: [String: Substring]
        /// Request body, consumed on parse, set on print.
        public var body: Substring?

        public init(
            path: [Substring] = [],
            query: [String: Substring] = [:],
            body: Substring? = nil
        ) {
            self.path = path
            self.query = query
            self.body = body
        }
    }
}

// MARK: - Conversion failure (partial case-extract)

extension Route {
    /// Raised by a case conversion's `unapply` when the route is not that case.
    /// This is exactly the signal the router's `print` uses to pick the right
    /// case printer (first `unapply` that does not throw wins).
    public enum Mismatch: Swift.Error, Equatable, Sendable {
        case wrongCase
    }
}
