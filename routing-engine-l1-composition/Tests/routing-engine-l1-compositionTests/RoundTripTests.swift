//
//  RoundTripTests.swift
//  routing-engine-l1-composition
//
//  The empirical evidence for the spike verdict. Two round-trip contracts,
//  both directions, over the L1-composed router; plus a direct check that the
//  engine's `Parser.Take.Two` prints multi-value tuples (the escape hatch for
//  the builder tuple-flatten friction, README F2).
//

import Testing
import Parser_Primitives
@testable import routing_engine_l1_composition

// MARK: - Contract 1: print then parse == identity on the route value

@Suite("print ∘ parse round-trips on the route value")
struct PrintThenParse {
    let router = Route.Router()

    @Test("all three cases recover after print → parse", arguments: [
        Route.user(id: 42),
        Route.search(term: "swift"),
        Route.create(body: "hello world"),
    ])
    func recovers(_ route: Route) throws {
        var data = Route.Request()
        try router.print(route, into: &data)          // route value -> carrier
        var cursor = data
        let parsed = try router.parse(&cursor)         // carrier -> route value
        #expect(parsed == route)
    }
}

// MARK: - Contract 2: parse then print == identity on the carrier

@Suite("parse ∘ print round-trips on the request carrier")
struct ParseThenPrint {
    let router = Route.Router()

    @Test("all three canonical carriers recover after parse → print", arguments: [
        Route.Request(path: ["users", "42"]),
        Route.Request(path: ["search"], query: ["q": "swift"]),
        Route.Request(path: ["posts"], body: "hello world"),
    ])
    func recovers(_ carrier: Route.Request) throws {
        let original = carrier
        var cursor = carrier
        let route = try router.parse(&cursor)          // carrier -> route value
        var rebuilt = Route.Request()
        try router.print(route, into: &rebuilt)        // route value -> carrier
        #expect(rebuilt == original)
    }
}

// MARK: - Case-specific parse checks (the composition actually discriminates)

@Suite("router discriminates the three cases")
struct Discrimination {
    let router = Route.Router()

    @Test func parsesUser() throws {
        var data = Route.Request(path: ["users", "7"])
        #expect(try router.parse(&data) == .user(id: 7))
    }

    @Test func parsesSearch() throws {
        var data = Route.Request(path: ["search"], query: ["q": "combinators"])
        #expect(try router.parse(&data) == .search(term: "combinators"))
    }

    @Test func parsesCreate() throws {
        var data = Route.Request(path: ["posts"], body: "payload")
        #expect(try router.parse(&data) == .create(body: "payload"))
    }

    @Test func rejectsUnknown() {
        var data = Route.Request(path: ["nope"])
        #expect(throws: Route.Router.Fault.self) {
            try router.parse(&data)
        }
    }
}

// MARK: - Multi-value printing via explicit Take.Two (README friction F2)

@Suite("explicit Parser.Take.Two prints a 2-value tuple")
struct MultiValuePrinting {
    // The @Parser.Builder tuple-flatten path (Take.Two.Map) is PARSE-ONLY, so a
    // route capturing >= 2 values via the builder loses printability. Building
    // the pair explicitly with `Parser.Take.Two` keeps it a printer. This test
    // is the positive control proving multi-value printing is achievable at L1
    // — just not through the result builder.
    @Test func twoPathIntegersRoundTrip() throws {
        let pair = Parser.Take.Two(Route.Path.Integer(), Route.Path.Integer())

        var data = Route.Request(path: ["3", "14"])
        let parsed = try pair.parse(&data)
        #expect(parsed == (3, 14))

        var rebuilt = Route.Request()
        try pair.print((3, 14), into: &rebuilt)
        #expect(rebuilt == Route.Request(path: ["3", "14"]))
    }
}
