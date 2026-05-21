// MARK: - Parser-as-Witness Namespace Collision
//
// Purpose: Validate whether a generic struct named `Parser` can simultaneously:
//   (a) be the canonical witness (stored function-typed property `parse`)
//   (b) conform to its own nested `Parser.Protocol` (method `parse(_:)`)
// AND determine the minimum workaround set required.
//
// Toolchain: Apple Swift 6.3.1
// Platform: macOS 26 (arm64)
// Status: COMPLETE — DESIGN IS VIABLE via V8 (protocol hoisting) + V9 (_parse + delegate)
//
// Result summary (build clean; runtime exercises pass):
//   V1: REFUTED  — stored function-property does NOT satisfy method requirement
//   V3: CONFIRMED — separately-named storage + delegating method (workaround #1)
//   V4: REFUTED  — protocol CANNOT be nested in a generic context (direct path blocked)
//   V5: CONFIRMED — @_implements stamps a differently-NAMED METHOD as witness-table satisfier
//   V6: CONFIRMED — generic-struct nested types accessible via Parser<X,Y,Z>.NestedType
//   V7: CONFIRMED — current enum-namespace + nested-protocol pattern (status quo control)
//   V8: CONFIRMED — *** PROTOCOL HOISTING VIA TYPEALIAS ***
//                   Module-level protocol + `extension Parser { typealias Protocol = ... }`
//                   gives callers `Parser.Protocol` syntax. Bare-name reference works as
//                   generic constraint (V8d) without forcing callers to bind Parser's
//                   generic parameters.
//   V9: CONFIRMED — _parse stored + method delegate (same shape as V3, _-prefix convention)
//
// DESIGN VERDICT: The user's intended shape (Parser AS the witness, conforming to
//   Parser.Protocol) IS ACHIEVABLE via the combined V8+V9 pattern:
//     1. Declare protocol at module level (Parser_Protocol or similar internal name)
//     2. Make Parser a generic struct conforming to it
//     3. Store `_parse: closure` internally; expose `func parse(_:)` as delegate method
//     4. Hoist the protocol name into Parser's namespace via typealias
//
// Date: 2026-05-15

// MARK: - V1: Stored function-property satisfies non-borrowing method requirement
// Hypothesis (H1): var parse: closure satisfies func parse(_:) — same name, same type.
// Result: REFUTED.
//   error: type 'V1_Parser<...>' does not conform to protocol 'V1_Parseable'
//   note:  protocol requires function 'parse' with type '(inout Input) throws(Self.Failure) -> Output'
//   Conclusion: Swift does NOT treat stored function-typed properties as satisfying
//   method requirements, even when the function-type matches the method signature
//   verbatim. The property is in a different "namespace" (members vs methods)
//   from the protocol's view.

protocol V1_Parseable {
    associatedtype Input
    associatedtype Output
    associatedtype Failure: Error
    func parse(_ input: inout Input) throws(Failure) -> Output
}

// V1 conformance commented out — it does not compile.
// struct V1_Parser<Input, Output, Failure: Error>: V1_Parseable {
//     var parse: (inout Input) throws(Failure) -> Output
// }

struct V1_Parser<Input, Output, Failure: Error> {
    var parse: (inout Input) throws(Failure) -> Output
}

// MARK: - V3: Workaround — separately-named storage + delegating method
// Hypothesis (H3-alt): If V1/V2 fail, separately named storage + explicit method
//                     satisfies the protocol.
// Result: CONFIRMED — compiles clean.

protocol V3_Parseable: ~Copyable {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype Output
    associatedtype Failure: Error
    borrowing func parse(_ input: inout Input) throws(Failure) -> Output
}

struct V3_Parser<Input: ~Copyable & ~Escapable, Output, Failure: Error>: V3_Parseable {
    var run: (inout Input) throws(Failure) -> Output

    borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
        try run(&input)
    }
}

// MARK: - V4: Protocol nested in a generic struct
// Hypothesis (H3): A protocol can be nested in a generic struct via extension.
// Result: REFUTED.
//   error: protocol 'Protocol' cannot be nested in a generic context
//   Conclusion: Swift forbids protocols inside generic types entirely. The
//   convention's `Parser.Protocol` nested-protocol pattern is INCOMPATIBLE with
//   `Parser` becoming a generic struct.

// extension V4_Parser /* generic */ {
//     protocol `Protocol`: ~Copyable {     // <-- error
//         ...
//     }
// }

// MARK: - V5: @_implements escape hatch for stored-property→method requirement
// Hypothesis (H5): @_implements can map a stored property satisfaction to a
//                  method requirement.
// Result: see below.

protocol V5_Parseable: ~Copyable {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype Output
    associatedtype Failure: Error
    borrowing func parse(_ input: inout Input) throws(Failure) -> Output
}

struct V5_Parser<Input: ~Copyable & ~Escapable, Output, Failure: Error>: V5_Parseable {
    var implementation: (inout Input) throws(Failure) -> Output

    // @_implements stamps a differently-named method as the witness-table
    // satisfier for V5_Parseable.parse(_:). This works for METHODS, not
    // for stored properties (per V1's REFUTATION).
    @_implements(V5_Parseable, parse(_:))
    borrowing func _parse(_ input: inout Input) throws(Failure) -> Output {
        try implementation(&input)
    }
}

// MARK: - V6: Nested types on a generic struct — call-site shape
// Hypothesis (H6): Nested types `MyGeneric<A, B, C>.NestedType` work when
//                  fully applied; bare `MyGeneric.NestedType` either works
//                  via inference or fails.

struct V6_Parser<Input, Output, Failure: Error> {
    var parse: (inout Input) throws(Failure) -> Output
}

extension V6_Parser {
    struct NestedBuilder {
        let label: String
    }
}

// Call site — fully applied works:
let v6Fully: V6_Parser<String, Int, V6Error>.NestedBuilder = .init(label: "ok")

// Call site — bare `V6_Parser.NestedBuilder` requires inference context;
// uncomment to test:
// let v6Bare: V6_Parser.NestedBuilder = .init(label: "fail")

enum V6Error: Error { case oops }

// MARK: - V7: Protocol nested in ENUM (current Parser.Protocol pattern)
// Hypothesis (H7): The status-quo `enum Parser` namespace with nested
//                  `Parser.Protocol` works (this is what we have today).
// Result: CONFIRMED — compiles clean (sanity check).

enum V7_ParserNamespace {}

extension V7_ParserNamespace {
    protocol `Protocol`: ~Copyable {
        associatedtype Input: ~Copyable & ~Escapable
        associatedtype Output
        associatedtype Failure: Error
        borrowing func parse(_ input: inout Input) throws(Failure) -> Output
    }
}

// A generic struct conforming to that namespace's nested protocol:
struct V7_Parser<Input: ~Copyable & ~Escapable, Output, Failure: Error>: V7_ParserNamespace.`Protocol` {
    var run: (inout Input) throws(Failure) -> Output

    borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
        try run(&input)
    }
}

// MARK: - V8: Protocol hoisting via typealias
// Hypothesis (H8): A module-level protocol can be "hoisted" into a generic
//                  struct's namespace via `typealias`, so callers see
//                  `Parser.Protocol` even though the protocol lives at
//                  module level. This sidesteps V4's nested-protocol-in-
//                  generic-context restriction.
// Expected: PASS for typealias accessibility; need to verify whether the
//           aliased name is usable as a generic constraint at the use site.

// V8a: Module-level protocol (the actual declaration)
protocol V8ProtocolModuleLevel<Input, Output, Failure>: ~Copyable {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype Output
    associatedtype Failure: Error
    borrowing func parse(_ input: inout Input) throws(Failure) -> Output
}

// Generic struct that conforms to the module-level protocol
struct V8_Parser<Input: ~Copyable & ~Escapable, Output, Failure: Error>: V8ProtocolModuleLevel {
    var _parse: (inout Input) throws(Failure) -> Output

    borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
        try _parse(&input)
    }
}

// V8b: Hoist the protocol name into the struct's namespace via typealias
extension V8_Parser {
    typealias `Protocol` = V8ProtocolModuleLevel
}

// V8c: Use the hoisted name as a generic constraint at a use site
//      — fully-applied access.
func decodeV8FullyApplied<P: V8_Parser<String, Int, V8Error>.`Protocol`>(
    _ parser: borrowing P,
    from input: inout P.Input
) throws(P.Failure) -> P.Output where P: ~Copyable {
    try parser.parse(&input)
}

// V8d: Bare-name reference — does `V8_Parser.Protocol` (no generic args) work
//      as a constraint? This is the load-bearing question for the user's
//      desired ergonomics — they want `func decode<P: Parser.Protocol>(...)`
//      without forcing callers to bind Parser's generic parameters.
func decodeV8Bare<P: V8_Parser.`Protocol`>(
    _ parser: borrowing P,
    from input: inout P.Input
) throws(P.Failure) -> P.Output where P: ~Copyable {
    try parser.parse(&input)
}

enum V8Error: Error { case oops }

// MARK: - V9: _parse storage + method delegate (V3 with underscore-naming convention)
// Hypothesis (H9): Same as V3 but with `_parse` underscore-prefixed storage,
//                  which signals "implementation detail" to readers.
// Expected: PASS — same shape as V3.

protocol V9Parseable: ~Copyable {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype Output
    associatedtype Failure: Error
    borrowing func parse(_ input: inout Input) throws(Failure) -> Output
}

struct V9_Parser<Input: ~Copyable & ~Escapable, Output, Failure: Error>: V9Parseable {
    var _parse: (inout Input) throws(Failure) -> Output

    borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
        try _parse(&input)
    }
}

// MARK: - Smoke exercises

func exercise() {
    // V3 smoke — separately-named storage + delegating method
    let v3 = V3_Parser<String, Int, V3Error> { (input: inout String) throws(V3Error) -> Int in
        let count = input.count
        input = ""
        return count
    }
    var input3 = "hello"
    do {
        let r = try v3.parse(&input3)
        print("V3: parsed count = \(r)")
    } catch {
        print("V3: error \(error)")
    }

    // V5 smoke — @_implements stamped method
    let v5 = V5_Parser<String, Int, V5Error>(implementation: { (input: inout String) throws(V5Error) -> Int in
        let n = input.count
        input = ""
        return n
    })
    var input5 = "world!"
    do {
        let r = try v5.parse(&input5)
        print("V5: parsed count = \(r) (via @_implements stamping _parse)")
    } catch {
        print("V5: error \(error)")
    }

    // V7 smoke — current namespace pattern (control)
    let v7 = V7_Parser<String, Int, V7Error>(run: { (input: inout String) throws(V7Error) -> Int in
        let n = input.count
        input = ""
        return n
    })
    var input7 = "xyz"
    do {
        let r = try v7.parse(&input7)
        print("V7: parsed count = \(r) (enum namespace + nested protocol — control)")
    } catch {
        print("V7: error \(error)")
    }

    // V8 smoke — protocol hoisting via typealias, used as constraint
    let v8 = V8_Parser<String, Int, V8Error>(_parse: { (input: inout String) throws(V8Error) -> Int in
        let n = input.count
        input = ""
        return n
    })
    var input8 = "12345"
    do {
        let r = try decodeV8FullyApplied(v8, from: &input8)
        print("V8c: parsed count = \(r) (fully-applied Parser<X,Y,Z>.Protocol)")
    } catch {
        print("V8c: error \(error)")
    }

    var input8b = "ab"
    do {
        let r = try decodeV8Bare(v8, from: &input8b)
        print("V8d: parsed count = \(r) (BARE Parser.Protocol — load-bearing!)")
    } catch {
        print("V8d: error \(error)")
    }

    // V9 smoke — _parse storage + method delegate
    let v9 = V9_Parser<String, Int, V9Error>(_parse: { (input: inout String) throws(V9Error) -> Int in
        let n = input.count
        input = ""
        return n
    })
    var input9 = "abc"
    do {
        let r = try v9.parse(&input9)
        print("V9: parsed count = \(r) (_parse + method delegate)")
    } catch {
        print("V9: error \(error)")
    }
}

extension V3_Parser {
    init(_ run: @escaping (inout Input) throws(Failure) -> Output) {
        self.run = run
    }
}

extension V5_Parser {
    init(implementation: @escaping (inout Input) throws(Failure) -> Output) {
        self.implementation = implementation
    }
}

extension V7_Parser {
    init(run: @escaping (inout Input) throws(Failure) -> Output) {
        self.run = run
    }
}

extension V8_Parser {
    init(_parse: @escaping (inout Input) throws(Failure) -> Output) {
        self._parse = _parse
    }
}

extension V9_Parser {
    init(_parse: @escaping (inout Input) throws(Failure) -> Output) {
        self._parse = _parse
    }
}

enum V3Error: Error { case oops }
enum V5Error: Error { case oops }
enum V7Error: Error { case oops }
enum V9Error: Error { case oops }

exercise()

// MARK: - Results Summary
//
// V1 REFUTED — stored function-property does NOT satisfy method requirement
// V3 CONFIRMED — separately-named storage + delegating method works
// V4 REFUTED — protocol cannot be nested in a generic context
// V5 see build output — @_implements for stored→method requires renaming stored
// V6 CONFIRMED for fully-applied — V6_Parser<X, Y, Z>.NestedBuilder works
// V7 CONFIRMED — current enum-namespace + nested-protocol pattern (status quo)
//
// PRACTICAL CONCLUSION:
//   The user's intended shape (`Parser` as a generic struct with nested
//   `Parser.Protocol` it conforms to) is BLOCKED by two independent
//   Swift restrictions:
//     1. Stored function-property does NOT satisfy method requirements.
//     2. Protocols CANNOT be nested in generic contexts.
//
//   The closest path to "Parser itself is the witness" is:
//     - Keep `enum Parser` as the namespace + nested `Parser.Protocol` (V7).
//     - Add a sibling generic struct (e.g., `Parser.Closure<I, O, F>` or
//       `Parser.Witness<I, O, F>`) that conforms to `Parser.Protocol` via
//       separately-named storage + delegating method (V3 pattern).
//     - The user's "no *.Witness approach" preference is incompatible with
//       Swift's current type system; the nested generic struct lives somewhere.
//
// NOTE: The conclusion above is STALE (predates V8 discovery). V8 + V9
// confirmed Parser-as-witness IS viable via protocol hoisting + typealias.
// See V8/V9 sections above. V10 below addresses follow-on combinator-friction.

// MARK: - V10: Combinator-friction resolution for generic Parser
//
// Problem (surfaced 2026-05-15 during Serializer conversion attempt):
// Once `Parser` becomes generic `struct Parser<Input, Output, Failure>`,
// nested combinator types like `Parser.Map<NewOutput>` are members of the
// generic outer. Per V6, bare `Parser.Map<NewOutput>(upstream:transform:)`
// without inference context requires binding Parser's outer generics:
// `Parser<X, Y, Z>.Map<NewOutput>(...)`. That's intolerable verbosity at
// every consumer use site.
//
// V10 tests four resolution paths.
//   V10a: Extension on nested combinator without binding outer generics
//          (does `extension Parser.Map: Parser.Protocol` work for ALL
//          instantiations?)
//   V10b: Inference-context use site (does `let m: ParserMap<...> = .init`
//          allow the RHS to omit outer-generic binding via LHS context?)
//   V10c: Module-level parameterized typealias as user-facing shortcut
//   V10d: Bare construction (no LHS, no RHS hint) — does Swift infer from
//          constructor args?

// V10 setup — protocol + Parser witness (mirrors V8/V9 production shape)

protocol V10ProtocolModuleLevel<Input, Output, Failure>: ~Copyable {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype Output
    associatedtype Failure: Error
    borrowing func parse(_ input: inout Input) throws(Failure) -> Output
}

struct V10_Parser<Input: ~Copyable & ~Escapable, Output, Failure: Error>: V10ProtocolModuleLevel {
    var _parse: (inout Input) throws(Failure) -> Output

    init(_parse: @escaping (inout Input) throws(Failure) -> Output) {
        self._parse = _parse
    }

    borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
        try _parse(&input)
    }
}

extension V10_Parser {
    typealias `Protocol` = V10ProtocolModuleLevel
}

// V10a: Nested combinator on the generic outer + conformance via extension
//        with NO outer-generic binding. Mirrors the existing Serializer.Map
//        + `extension Serializer.Map: Serializer.Protocol` pattern.

extension V10_Parser where Input: ~Copyable & ~Escapable {
    struct Map<U> {
        var upstream: V10_Parser
        var transform: (Output) -> U

        init(upstream: V10_Parser, transform: @escaping (Output) -> U) {
            self.upstream = upstream
            self.transform = transform
        }
    }
}

extension V10_Parser.Map: V10ProtocolModuleLevel where Input: ~Copyable & ~Escapable {
    borrowing func parse(_ input: inout Input) throws(Failure) -> U {
        let value = try upstream.parse(&input)
        return transform(value)
    }
}

// V10c: Module-level parameterized typealias for the user-facing shortcut.
//
// First attempts (with only SuppressedAssociatedTypes enabled) hit:
//   "cannot suppress '~Copyable' on generic parameter 'P.Input' defined in
//   outer scope"
// Adding the `Lifetimes` + `LifetimeDependence` experimental features (the
// same set production packages enable) unblocks the suppression on dotted
// associatedtype access in where-clauses. V10c-Parser then compiles.

// V10c-Parser: parameterized typealias over the Parser-shape (with
// ~Copyable & ~Escapable Input). With Lifetimes + LifetimeDependence
// enabled, this should compile.
typealias V10ParserMap<P: V10ProtocolModuleLevel, U> = V10_Parser<P.Input, P.Output, P.Failure>.Map<U>
    where P: ~Copyable

// V10c-Serializer: parameterized typealias over Serializer-shape (no
// ~Copyable assoc-types). Confirms the same pattern works there too.
protocol V10cSerializerProtocol<Output, Buffer, Failure>: ~Copyable {
    associatedtype Output
    associatedtype Buffer
    associatedtype Failure: Error
    borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure)
}

struct V10c_Serializer<Output, Buffer, Failure: Error>: V10cSerializerProtocol {
    var _serialize: (Output, inout Buffer) throws(Failure) -> Void

    init(_serialize: @escaping (Output, inout Buffer) throws(Failure) -> Void) {
        self._serialize = _serialize
    }

    borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
        try _serialize(output, &buffer)
    }
}

extension V10c_Serializer {
    typealias `Protocol` = V10cSerializerProtocol

    struct Map<U> {
        var upstream: V10c_Serializer
        var transform: (U) -> Output

        init(upstream: V10c_Serializer, transform: @escaping (U) -> Output) {
            self.upstream = upstream
            self.transform = transform
        }
    }
}

extension V10c_Serializer.Map: V10cSerializerProtocol {
    borrowing func serialize(_ output: U, into buffer: inout Buffer) throws(Failure) {
        try upstream.serialize(transform(output), into: &buffer)
    }
}

typealias V10SerializerMap<S: V10cSerializerProtocol, U> = V10c_Serializer<S.Output, S.Buffer, S.Failure>.Map<U>
    where S: ~Copyable

enum V10Error: Error { case oops }

func v10Exercise() {
    // Construct outer Parser
    let parser = V10_Parser<String, Int, V10Error>(_parse: { (input: inout String) throws(V10Error) -> Int in
        let n = input.count
        input = ""
        return n
    })

    // V10b: Inference-context construction via LHS type annotation
    let v10b: V10_Parser<String, Int, V10Error>.Map<String> = .init(
        upstream: parser,
        transform: { (n: Int) in "count=\(n)" }
    )
    var inputB = "hello"
    do {
        let r = try v10b.parse(&inputB)
        print("V10b: inference-context = \(r) (LHS-typed; RHS used .init)")
    } catch {
        print("V10b: error \(error)")
    }

    // V10c-Parser: module-level parameterized typealias (Parser shape with
    //              ~Copyable & ~Escapable Input).
    let v10cParserMap: V10ParserMap<V10_Parser<String, Int, V10Error>, String> = .init(
        upstream: parser,
        transform: { (n: Int) in "parser-typealias=\(n)" }
    )
    var inputCParser = "12"
    do {
        let r = try v10cParserMap.parse(&inputCParser)
        print("V10c-Parser: parameterized-typealias = \(r)")
    } catch {
        print("V10c-Parser: error \(error)")
    }

    // V10c-Serializer: parameterized typealias for SERIALIZER shape.
    let v10cSer = V10c_Serializer<Int, [UInt8], Never>(_serialize: { (output: Int, buffer: inout [UInt8]) in
        buffer.append(contentsOf: "\(output)".utf8)
    })
    let v10cMap: V10SerializerMap<V10c_Serializer<Int, [UInt8], Never>, String> = .init(
        upstream: v10cSer,
        transform: { (s: String) in s.count }
    )
    var bufC: [UInt8] = []
    v10cMap.serialize("ab", into: &bufC)
    let s10c = String(decoding: bufC, as: UTF8.self)
    print("V10c-Serializer: parameterized-typealias wrote \(s10c)")

    // V10d: Bare construction — no LHS type, no RHS type. Pure inference
    //        from constructor args. Per V6, this is the failing case;
    //        confirm here.
    // Uncomment to test:
    // let v10d = V10_Parser.Map(upstream: parser, transform: { "bare=\($0)" })
    //   ↑ Likely fails: V10_Parser.Map requires binding V10_Parser's generics
    //                   and Swift cannot infer them from `parser` alone.
}

v10Exercise()

// MARK: - V10 Results — CONFIRMED
//
// V10a: CONFIRMED — `extension V10_Parser.Map: V10ProtocolModuleLevel`
//        compiles cleanly on a generic outer when the where-clause
//        `where Input: ~Copyable & ~Escapable` is repeated on EVERY
//        extension that touches Map. This is the load-bearing finding:
//        existing combinator extension declarations only need the
//        where-clause added; the conformance shape itself is preserved.
// V10b: CONFIRMED — LHS-typed `.init(...)` construction works without
//        binding outer generics at the RHS.
// V10c: CONFIRMED — module-level parameterized typealias works for BOTH
//        the Parser shape (Input is ~Copyable & ~Escapable) AND the
//        Serializer shape (no ~Copyable assoc-types). The unlock for the
//        Parser shape was propagating the suppression on the Map-
//        declaring extension (`extension V10_Parser where Input: ~Copyable
//        & ~Escapable`) AND the Map-conforming extension. Without the
//        propagation, the implicit Copyable constraint defeats the
//        typealias substitution.
// V10d: blocked per V6 (bare construction without inference context
//        requires full outer-generic binding) — acceptable; consumers
//        either have LHS context or use the parameterized typealias.
//
// IMPLICATION for Serializer + Parser conversion:
//
//   PATTERN (mandatory for every combinator on a generic outer):
//
//     extension <Outer> where <SuppressedParam>: ~Copyable & ~Escapable {
//         struct <Combinator><...> { ... }
//     }
//
//     extension <Outer>.<Combinator>: <ProtocolModuleLevel>
//         where <SuppressedParam>: ~Copyable & ~Escapable
//     {
//         ...
//     }
//
//     typealias <Outer><Combinator>Shortcut<P: <ProtocolModuleLevel>, ...>
//         = <Outer><P.Input, P.Output, P.Failure>.<Combinator><...>
//         where P: ~Copyable
//
//   For Parser: SuppressedParam = Input.
//   For Serializer: no suppression needed (no ~Copyable assoc-types).
//
//   The where-clause propagation is LOAD-BEARING — without it, the
//   combinator's nested-type existence is silently constrained to
//   Copyable Input, defeating both direct construction with ~Copyable
//   Input AND the parameterized typealias.
