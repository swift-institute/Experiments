//
//  LawTests.swift
//  coder-unification-spike
//
//  The empirical evidence for the B2 entry-gate verdict. Three law families
//  per combinator:
//
//  L-EQ    forward-append emission is byte-equal to prepend emission
//          (the L1 printer where it instantiates over Substring; the
//          line-for-line mirrored Prepend baseline otherwise).
//  L-RT    parse(serialize(x)) == x with empty remainder.
//  L-REST  the non-empty-rest law in both orientations:
//          - prepend: print(x, into: &rest) yields x ++ rest; parsing
//            recovers x with remainder == rest (the L1 Printer contract,
//            Parser.Printer.swift:16-17,60).
//          - append: an already-emitted PREFIX stays put; serialize
//            appends after it; parsing the whole buffer recovers the
//            prefix's value then x. Same observable law, mirrored
//            orientation.
//

import Testing
import Parser_Primitives
@testable import coder_unification_spike

// MARK: - Shared fixtures

/// `/users/:id/:name` — literal + integer + word, the sequential builder shape.
private var forwardRoute: Forward.Take3<Leaf.Literal, Leaf.Integer, Forward.SkipFirst<Leaf.Literal, Leaf.Word>> {
    Forward.Take3(
        Leaf.Literal("/users/"),
        Leaf.Integer(),
        Forward.SkipFirst(Leaf.Literal("/"), Leaf.Word())
    )
}

private enum Tag: Equatable, Sendable {
    case number(Int)
    case word(String)
}

private var forwardTagged: Forward.OneOf2<
    Forward.Converted<Leaf.Integer, Tag>,
    Forward.Converted<Leaf.Word, Tag>
> {
    Forward.OneOf2(
        Forward.Converted(
            Leaf.Integer(),
            apply: { Tag.number($0) },
            unapply: { if case .number(let v) = $0 { v } else { nil } }
        ),
        Forward.Converted(
            Leaf.Word(),
            apply: { Tag.word($0) },
            unapply: { if case .word(let w) = $0 { w } else { nil } }
        )
    )
}

// MARK: - Sequential conjunction (Take2 / Take3, the builder-body shape)

@Suite("Take — sequential conjunction")
struct TakeLaws {
    @Test("L-EQ: forward Take2 == L1 Parser.Take.Two prepend print, byte-equal")
    func take2MatchesL1() throws {
        let l1 = Parser.Take.Two(Leaf.Literal("id="), Leaf.Integer())
        let forward = Forward.Take2(Leaf.Literal("id="), Leaf.Integer())

        var prepended: Substring = ""
        try l1.print(((), 42), into: &prepended)

        var appended: Substring = ""
        try forward.serialize(((), 42), into: &appended)

        #expect(String(prepended) == "id=42")
        #expect(String(appended) == String(prepended))
    }

    @Test("L-RT: Take3 route round-trips", arguments: [(7, "alice"), (0, "b"), (123456, "zz")])
    func take3RoundTrips(_ id: Int, _ name: String) throws {
        var buffer: Substring = ""
        try forwardRoute.serialize(((), id, name), into: &buffer)
        #expect(String(buffer) == "/users/\(id)/\(name)")

        var cursor = buffer
        let parsed = try forwardRoute.parse(&cursor)
        #expect(parsed.1 == id)
        #expect(parsed.2 == name)
        #expect(cursor.isEmpty)
    }

    @Test("L-RT: L1 parse accepts the forward-appended bytes (cross-algebra)")
    func l1ParsesForwardOutput() throws {
        // The L1 combinator's own parse consumes what the forward twin emitted.
        let l1 = Parser.Take.Two(Leaf.Literal("id="), Leaf.Integer())
        let forward = Forward.Take2(Leaf.Literal("id="), Leaf.Integer())
        var buffer: Substring = ""
        try forward.serialize(((), 99), into: &buffer)
        let parsed = try l1.parse(&buffer)
        #expect(parsed == 99)
        #expect(buffer.isEmpty)
    }
}

// MARK: - Skip (both orders)

@Suite("Skip — void-dropping conjunction")
struct SkipLaws {
    @Test("L-EQ: forward SkipFirst == L1 Parser.Skip.First (reverse-order prepend)")
    func skipFirstMatchesL1() throws {
        let l1 = Parser.Skip.First(Leaf.Literal("/"), Leaf.Word())
        let forward = Forward.SkipFirst(Leaf.Literal("/"), Leaf.Word())

        var prepended: Substring = ""
        try l1.print("abc", into: &prepended)
        var appended: Substring = ""
        try forward.serialize("abc", into: &appended)

        #expect(String(prepended) == "/abc")
        #expect(String(appended) == String(prepended))
    }

    @Test("L-EQ: forward SkipSecond == L1 Parser.Skip.Second (value-then-skip)")
    func skipSecondMatchesL1() throws {
        let l1 = Parser.Skip.Second(Leaf.Word(), Leaf.Literal(";"))
        let forward = Forward.SkipSecond(Leaf.Word(), Leaf.Literal(";"))

        var prepended: Substring = ""
        try l1.print("abc", into: &prepended)
        var appended: Substring = ""
        try forward.serialize("abc", into: &appended)

        #expect(String(prepended) == "abc;")
        #expect(String(appended) == String(prepended))
    }

    @Test("L-RT: both Skip orders round-trip")
    func skipRoundTrips() throws {
        let forward = Forward.SkipSecond(
            Forward.SkipFirst(Leaf.Literal("<"), Leaf.Word()),
            Leaf.Literal(">")
        )
        var buffer: Substring = ""
        try forward.serialize("tag", into: &buffer)
        #expect(String(buffer) == "<tag>")
        var cursor = buffer
        #expect(try forward.parse(&cursor) == "tag")
        #expect(cursor.isEmpty)
    }
}

// MARK: - Optionally (present + absent)

@Suite("Optionally")
struct OptionallyLaws {
    @Test("L-EQ present: forward == mirrored L1 prepend")
    func presentMatches() throws {
        let baseline = Prepend.Optionally(Leaf.Integer())
        let forward = Forward.Optionally(Leaf.Integer())

        var prepended: Substring = ""
        baseline.print(42, into: &prepended)
        var appended: Substring = ""
        try forward.serialize(42, into: &appended)
        #expect(String(appended) == String(prepended))
        #expect(String(appended) == "42")
    }

    @Test("L-EQ absent: both emit nothing")
    func absentMatches() throws {
        let baseline = Prepend.Optionally(Leaf.Integer())
        let forward = Forward.Optionally(Leaf.Integer())

        var prepended: Substring = ""
        baseline.print(nil, into: &prepended)
        var appended: Substring = ""
        try forward.serialize(nil, into: &appended)
        #expect(prepended.isEmpty)
        #expect(appended.isEmpty)
    }

    @Test("L-RT: optional-in-sequence round-trips both ways")
    func roundTripsInContext() throws {
        // "v" ("=" int)? — presence changes shape, absence backtracks.
        let coder = Forward.Take2(
            Leaf.Literal("v"),
            Forward.Optionally(Forward.SkipFirst(Leaf.Literal("="), Leaf.Integer()))
        )
        for value in [Int?.some(7), nil] {
            var buffer: Substring = ""
            try coder.serialize(((), value), into: &buffer)
            #expect(String(buffer) == (value.map { "v=\($0)" } ?? "v"))
            var cursor = buffer
            let parsed = try coder.parse(&cursor)
            #expect(parsed.1 == value)
            #expect(cursor.isEmpty)
        }
    }
}

// MARK: - OneOf (first branch and later branch)

@Suite("OneOf")
struct OneOfLaws {
    @Test("L-EQ: forward OneOf2 == mirrored L1 prepend, both branch selections")
    func branchesMatch() throws {
        let baseline = Prepend.OneOf2(
            Parser.Converted(
                upstream: Leaf.Integer(),
                downstream: Parser.Conversion.Witness<Int, Tag, Leaf.Fault>(
                    apply: { .number($0) },
                    unapply: { if case .number(let v) = $0 { return v } else { throw .unapplyFailed } }
                )
            ),
            Parser.Converted(
                upstream: Leaf.Word(),
                downstream: Parser.Conversion.Witness<String, Tag, Leaf.Fault>(
                    apply: { .word($0) },
                    unapply: { if case .word(let w) = $0 { return w } else { throw .unapplyFailed } }
                )
            )
        )
        let forward = forwardTagged

        for tag in [Tag.number(42), Tag.word("abc")] {
            var prepended: Substring = ""
            try baseline.print(tag, into: &prepended)
            var appended: Substring = ""
            try forward.serialize(tag, into: &appended)
            #expect(String(appended) == String(prepended))
        }
    }

    @Test("L-RT: both branches round-trip; later branch requires emission backtrack")
    func roundTrips() throws {
        let forward = forwardTagged
        for tag in [Tag.number(7), Tag.word("hello")] {
            var buffer: Substring = ""
            try forward.serialize(tag, into: &buffer)
            var cursor = buffer
            #expect(try forward.parse(&cursor) == tag)
            #expect(cursor.isEmpty)
        }
    }

    @Test("emission backtrack leaves no residue in a non-empty buffer")
    func backtrackIsClean() throws {
        // Serialize a later-branch value into a buffer that already holds a
        // prefix: the failed first branch must not corrupt the prefix.
        let forward = forwardTagged
        var buffer: Substring = "prefix:"
        try forward.serialize(.word("abc"), into: &buffer)
        #expect(String(buffer) == "prefix:abc")
    }
}

// MARK: - Many (0, 1, n) and Many-with-separator

@Suite("Many")
struct ManyLaws {
    @Test("L-EQ: forward Many == mirrored L1 reversed-prepend", arguments: [[], [5], [1, 2, 3]])
    func manyMatches(_ values: [Int]) throws {
        let element = Forward.SkipSecond(Leaf.Integer(), Leaf.Literal(";"))
        let baselineElement = Parser.Skip.Second(Leaf.Integer(), Leaf.Literal(";"))
        let baseline = Prepend.Many(baselineElement)
        let forward = Forward.Many(element)

        var prepended: Substring = ""
        try baseline.print(values, into: &prepended)
        var appended: Substring = ""
        try forward.serialize(values, into: &appended)
        #expect(String(appended) == String(prepended))
    }

    @Test("L-RT: forward Many round-trips", arguments: [[], [5], [1, 2, 3]])
    func manyRoundTrips(_ values: [Int]) throws {
        let forward = Forward.Many(Forward.SkipSecond(Leaf.Integer(), Leaf.Literal(";")))
        var buffer: Substring = ""
        try forward.serialize(values, into: &buffer)
        var cursor = buffer
        #expect(try forward.parse(&cursor) == values)
        #expect(cursor.isEmpty)
    }

    @Test("L-EQ: forward ManySeparated == mirrored L1", arguments: [[], [5], [1, 2, 3]])
    func separatedMatches(_ values: [Int]) throws {
        let baseline = Prepend.ManySeparated(Leaf.Integer(), separator: Leaf.Literal(","))
        let forward = Forward.ManySeparated(Leaf.Integer(), separator: Leaf.Literal(","))

        var prepended: Substring = ""
        try baseline.print(values, into: &prepended)
        var appended: Substring = ""
        try forward.serialize(values, into: &appended)
        #expect(String(appended) == String(prepended))
        if values == [1, 2, 3] { #expect(String(appended) == "1,2,3") }
    }

    @Test("L-RT: forward ManySeparated round-trips", arguments: [[], [5], [1, 2, 3]])
    func separatedRoundTrips(_ values: [Int]) throws {
        let forward = Forward.ManySeparated(Leaf.Integer(), separator: Leaf.Literal(","))
        var buffer: Substring = ""
        try forward.serialize(values, into: &buffer)
        var cursor = buffer
        #expect(try forward.parse(&cursor) == values)
        #expect(cursor.isEmpty)
    }
}

// MARK: - Conversion seam

@Suite("Conversion")
struct ConversionLaws {
    struct User: Equatable { let id: Int }

    @Test("L-EQ + L-RT: unapply-then-emit is order-agnostic")
    func convertedMatches() throws {
        let l1 = Parser.Take.Two(Leaf.Literal("u"), Leaf.Integer())
            .map(
                Parser.Conversion.Witness<(Void, Int), User, Leaf.Fault>(
                    apply: { User(id: $0.1) },
                    unapply: { ((), $0.id) }
                )
            )
        let forward = Forward.Converted(
            Forward.Take2(Leaf.Literal("u"), Leaf.Integer()),
            apply: { User(id: $0.1) },
            unapply: { ((), $0.id) }
        )

        var prepended: Substring = ""
        try l1.print(User(id: 8), into: &prepended)
        var appended: Substring = ""
        try forward.serialize(User(id: 8), into: &appended)
        #expect(String(appended) == String(prepended))
        #expect(String(appended) == "u8")

        var cursor = appended
        #expect(try forward.parse(&cursor) == User(id: 8))
        #expect(cursor.isEmpty)
    }
}

// MARK: - Rest / Prefix / End / Always

@Suite("Rest, Prefix, End, Always")
struct LeafShapeLaws {
    @Test("L-RT: Word (Prefix.While shape) then Rest round-trips")
    func prefixThenRest() throws {
        let forward = Forward.Take3(Leaf.Word(), Leaf.Literal(":"), Leaf.Rest())
        var buffer: Substring = ""
        try forward.serialize(("key", (), "the rest, verbatim"), into: &buffer)
        #expect(String(buffer) == "key:the rest, verbatim")
        var cursor = buffer
        let parsed = try forward.parse(&cursor)
        #expect(parsed.0 == "key")
        #expect(parsed.2 == "the rest, verbatim")
        #expect(cursor.isEmpty)
    }

    @Test("L-RT: End and Always emit nothing and round-trip")
    func endAlways() throws {
        let forward = Forward.Take3(Leaf.Word(), Leaf.Always(1), Leaf.End())
        var buffer: Substring = ""
        try forward.serialize(("abc", 1, ()), into: &buffer)
        #expect(String(buffer) == "abc")
        var cursor = buffer
        let parsed = try forward.parse(&cursor)
        #expect(parsed.0 == "abc")
        #expect(parsed.1 == 1)
        #expect(cursor.isEmpty)
    }
}

// MARK: - The crux: printing into a NON-EMPTY rest

@Suite("Non-empty rest — the orientation crux")
struct NonEmptyRestLaws {
    @Test("prepend law (L1 contract): print into non-empty rest, parse recovers value + rest")
    func prependIntoRest() throws {
        // The exact L1 Printer contract (Parser.Printer.swift:16-17,60):
        // print PREPENDS to the existing input; the pre-existing content is
        // the SUFFIX (the not-yet-parsed rest).
        let l1 = Parser.Take.Two(Leaf.Literal("id="), Leaf.Integer())
        var input: Substring = "&remainder"
        try l1.print(((), 42), into: &input)
        #expect(String(input) == "id=42&remainder")

        let parsed = try l1.parse(&input)
        #expect(parsed == 42)
        #expect(String(input) == "&remainder")
    }

    @Test("append law (mirrored): pre-existing content is the PREFIX; same observable")
    func appendAfterPrefix() throws {
        // Under append emission the already-present buffer content is the
        // ALREADY-EMITTED prefix; the value lands after it. Parsing the
        // whole buffer visits the prefix first, then the value — the same
        // "printed value parses back out, surrounding content preserved"
        // observable, mirrored in orientation.
        let head = Forward.Take2(Leaf.Literal("user/"), Leaf.Integer())
        let tail = Forward.SkipFirst(Leaf.Literal("?q="), Leaf.Word())

        var buffer: Substring = ""
        try head.serialize(((), 7), into: &buffer)   // parent emits first...
        try tail.serialize("abc", into: &buffer)     // ...child appends after
        #expect(String(buffer) == "user/7?q=abc")

        var cursor = buffer
        let h = try head.parse(&cursor)
        #expect(h.1 == 7)
        #expect(try tail.parse(&cursor) == "abc")
        #expect(cursor.isEmpty)
    }

    @Test("equivalence: whole-tree prepend and whole-tree append emit identical bytes")
    func wholeTreeEquivalence() throws {
        // Prepend composes by visiting children in REVERSE with each leaf
        // front-inserting; append composes by visiting children FORWARD with
        // each leaf back-inserting. Over the same tree and value the two
        // disciplines are byte-identical — the reordering is total and
        // internal to the combinators, never observable at the emitted-bytes
        // boundary.
        let l1 = Parser.Take.Two(
            Parser.Take.Two(Leaf.Literal("a="), Leaf.Integer()),
            Parser.Skip.First(Leaf.Literal("&b="), Leaf.Word())
        )
        let forward = Forward.Take2(
            Forward.Take2(Leaf.Literal("a="), Leaf.Integer()),
            Forward.SkipFirst(Leaf.Literal("&b="), Leaf.Word())
        )

        var prepended: Substring = ""
        try l1.print((((), 1), "xyz"), into: &prepended)
        var appended: Substring = ""
        try forward.serialize((((), 1), "xyz"), into: &appended)

        #expect(String(prepended) == "a=1&b=xyz")
        #expect(String(appended) == String(prepended))
    }
}
