// MARK: - Parseable Associatedtype + Nested Generic Parser Collision
//
// Purpose: Validate that `@_implements(Parseable, Parser)` on a differently-
// named typealias lets a type with a generic nested `Parser<Input>` type
// conform to a `Parseable` protocol whose `associatedtype Parser` would
// otherwise collide with the nested type's name at conformance-synthesis
// time.
//
// V1 / V2 mirror the swift-version-primitives Version.Semantic shape —
// module-scope `Parser` namespace (mimics `Parser_Primitives.Parser`),
// nested generic `Type.Parser<Input>`, extension-based conformance.
//
// Toolchain: Apple Swift 6.3 (whatever's on PATH; macOS arm64)
// Platform: macOS .v26
// Module name: parseable_associatedtype_implements
//
// Result: CONFIRMED — `@_implements(Parseable, Parser)` on a differently-
// named typealias (`_ParseableParser`) makes the conformance compile.
// `swift build` and `swift build -c release` both succeed; `swift run`
// prints "V2: CONFIRMED" and the nested `Parser<Input>` generic type
// remains usable as `V2SemanticVersion.Parser<SomeInput>` for non-
// Parseable purposes.
//
// V1 caveat — partial reproduction: the simulated V1 with module-scope
// `Parser` namespace, public nested generic `Parser<Input>` conforming
// to `Parser.\`Protocol\`` via extension, and `@inlinable` public
// `static var parser` returning a specific `Parser<String>` does NOT
// reproduce the synthesis-redeclaration error my simulated shape was
// expected to expose. The real Version.Semantic case (verified at
// `swift-version-primitives` HEAD this date) DOES produce the error
// "invalid redeclaration of synthesized implementation for protocol
// requirement 'Parser'" without `@_implements`. The structural
// discriminator between the experiment and the real case is not yet
// isolated; the V2 fix is empirically confirmed on the real case
// regardless, which is the load-bearing result for the
// version-primitives Parseable conformance.
//
// Date: 2026-05-14
// Applied at: swift-primitives/swift-version-primitives/Sources/Version Primitives/Version.Semantic+Parseable.swift

// ==========================================================================
// Shared shapes — mimic swift-parser-primitives' Parseable + Parser.`Protocol`
// (standalone, no dep on swift-parser-primitives so the experiment is
// self-contained).
// ==========================================================================

// Module-scope `Parser` namespace — mirrors `Parser_Primitives.Parser`.
public enum Parser {
    public protocol `Protocol`<Input, Output> {
        associatedtype Input
        associatedtype Output
    }
}

// Mirrors `Parser_Primitives_Core.Parseable`.
public protocol Parseable {
    associatedtype Parser: parseable_associatedtype_implements.Parser.`Protocol` where Parser.Output == Self
    static var parser: Parser { get }
}

// ==========================================================================
// MARK: - V1 — Baseline: nested generic `Parser<Input>` + plain conformance
//
// Toggle V1_ENABLED to reproduce the failure.
// ==========================================================================

#if V1_ENABLED
public struct V1SemanticVersion {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public struct Parser<Input> {
        public init() {}
    }
}

extension V1SemanticVersion.Parser: parseable_associatedtype_implements.Parser.`Protocol` {
    public typealias Output = V1SemanticVersion
}

extension V1SemanticVersion: Parseable {
    @inlinable
    public static var parser: V1SemanticVersion.Parser<Swift.String> {
        V1SemanticVersion.Parser<Swift.String>()
    }
}
#endif

// ==========================================================================
// MARK: - V2 — `@_implements(Parseable, Parser)` on differently-named typealias
//
// Hypothesis: CONFIRMED — the stamp binds Parseable.Parser to a specific
// concrete instantiation of the generic nested Parser, without redeclaring
// the `Parser` name at V2SemanticVersion scope.
// ==========================================================================

public struct V2SemanticVersion {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public struct Parser<Input> {
        public init() {}
    }
}

extension V2SemanticVersion.Parser: parseable_associatedtype_implements.Parser.`Protocol` {
    public typealias Output = V2SemanticVersion
}

extension V2SemanticVersion: Parseable {
    @_implements(Parseable, Parser)
    public typealias _ParseableParser = V2SemanticVersion.Parser<Swift.String>

    @inlinable
    public static var parser: _ParseableParser { _ParseableParser() }
}

// ==========================================================================
// MARK: - Smoke test
// ==========================================================================

func smokeTest() {
    let _: V2SemanticVersion.Parser<Swift.String> = V2SemanticVersion.parser
    let _ = V2SemanticVersion.Parser<[Swift.UInt8]>()  // nested generic still usable
    print("V2: CONFIRMED — conformance compiles, nested Parser<Input> still usable")
}

smokeTest()
