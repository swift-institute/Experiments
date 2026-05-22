// MARK: - Variadic Parser.OneOf<each P> — Same-Element-Requirement Blocker
//
// Blog: BLOG-IDEA-103 "Three diagnostics, one wall: same-element requirements
//       and variadic parser combinators" — see
//       swift-institute/Blog/Draft/three-diagnostics-one-wall.md
//
// Purpose: Verify whether parser-primitives' per-arity OneOf.Two / OneOf.Three
// types can be unified into a single variadic-generic `Parser.OneOf<each P>`
// today (Swift 6.3.2), with shared Input/Output and Failure aggregated as
// `Product<repeat (each P).Failure>`.
//
// Hypothesis: A variadic OneOf with same-typed Input/Output across the pack
// is expressible via either (a) same-element where-clause requirements over
// the pack, or (b) primary-associated-type constraints with placeholder.
//
// Toolchain: Swift 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED on the unification path. The single structural blocker is
// V1 (same-element requirements). V2 documents a constraint-side workaround
// attempt that also fails. V3 isolates a sub-question (pack-member
// associated-type access) and CONFIRMS it works on its own — narrowing the
// blocker to V1 alone.
//
// The existing per-arity types (`Parser.OneOf.Two`, `Parser.OneOf.Three`)
// and the `buildPartialBlock`-based left-fold chain in
// `Parser.OneOf.Builder` cover the design surface that variadic generics
// would otherwise occupy. Refactor to variadic deferred until same-element
// requirements ship in Swift; this is the same family of pack-related
// upstream gaps that also gates `Coproduct<each T>` (see "The missing fourth
// corner" blog).
//
// Date: 2026-05-13
//
// V1: REFUTED — `repeat (each P).Input == Input` fails with
//     "same-element requirements are not yet supported". This is the
//     structural blocker — without it, OneOf's shared-Input/shared-Output
//     contract (mirrored from `Parser.OneOf.Two`'s
//     `P0.Input == P1.Input` requirement) is not expressible.
// V2: REFUTED — `each P: Parseable<Input, Output, _>` fails with
//     "type placeholder not allowed here". Constraint-side workaround for
//     V1's where-clause failure does not work.
// V3: CONFIRMED — `(each P).Failure` in type expression compiles cleanly
//     when isolated from V2's placeholder error. Pack-member
//     associated-type access is NOT a blocker; the variadic-OneOf
//     unification turns on V1 alone.
//
// Reproduce per variant:
//   swift build -Xswiftc -DVARIANT1   # same-element requirement attempt
//   swift build -Xswiftc -DVARIANT2   # primary-associated-type placeholder
//   swift build -Xswiftc -DVARIANT3   # pack-member assoc-type access
//
// Default build (no flags) compiles cleanly: only the shared mock types
// (`Parseable`, `Product`) and a `print` confirming infrastructure is sound.

// MARK: - Shared Mock Types (compile cleanly in all builds)

/// Mock of `Parser.Protocol` (parser-primitives) reduced to the minimum
/// associatedtypes the variadic experiment needs.
public protocol Parseable<Input, Output, Failure> {
    associatedtype Input
    associatedtype Output
    associatedtype Failure: Error
    func parse(_ input: inout Input) throws(Failure) -> Output
}

/// Mock of `Product<each Element>` (swift-product-primitives) — n-ary product
/// over a parameter pack. Conforms to `Error` when every element does.
public struct Product<each Element>: Sendable
where repeat each Element: Sendable {
    public let values: (repeat each Element)
    public init(_ values: repeat each Element) {
        self.values = (repeat each values)
    }
}
extension Product: Error where repeat each Element: Error {}

// MARK: - Variant 1 — Same-Element Requirement (REFUTED)
//
// Hypothesis: Same-element constraints over a pack express the shared-Input,
// shared-Output requirement that `Parser.OneOf.Two` enforces via
// `P0.Input == P1.Input` and `P0.Output == P1.Output`.
//
// Result: REFUTED
//
// Primary diagnostic:
//   error: same-element requirements are not yet supported
//     repeat (each P).Input == Input
//                           ^
//   error: same-element requirements are not yet supported
//     repeat (each P).Output == Output
//                            ^
//
// What this rules out: the natural where-clause form for "every pack member
// shares Input/Output" — the most idiomatic shape and the one that mirrors
// the binary `where P0.Input == P1.Input` pattern in `Parser.OneOf.Two`.

#if VARIANT1
public struct OneOf_V1<Input, Output, each P: Parseable>: Parseable
where
    repeat (each P).Input == Input,    // ❌ same-element not yet supported
    repeat (each P).Output == Output   // ❌ same-element not yet supported
{
    public typealias Failure = Never
    public let parsers: (repeat each P)
    public init(_ parsers: repeat each P) { self.parsers = (repeat each parsers) }
    public func parse(_ input: inout Input) throws(Never) -> Output {
        fatalError()
    }
}
#endif

// MARK: - Variant 2 — Primary-Associated-Type Placeholder (REFUTED)
//
// Hypothesis: Lifting the shared-Input/Output constraint into the conformance
// position via primary associated types — `each P: Parseable<Input, Output, _>`
// where `_` is the wildcard placeholder for the free `Failure` — sidesteps
// the same-element-requirements gap.
//
// Result: REFUTED
//
// Primary diagnostic:
//   error: type placeholder not allowed here
//     each P: Parseable<Input, Output, _>
//                                      ^
//
// What this rules out: SE-0346 (Primary Associated Types) admits `_`
// placeholders in constraint position for the all-or-prefix specification,
// but the compiler rejects `_` inside a pack-element constraint. Combined
// with V1, this closes the constraint-side route to expressing the shared
// Input/Output bound across a pack.

#if VARIANT2
public struct OneOf_V2<Input, Output, each P: Parseable<Input, Output, _>>: Parseable {
    public typealias Failure = Never
    public let parsers: (repeat each P)
    public init(_ parsers: repeat each P) { self.parsers = (repeat each parsers) }
    public func parse(_ input: inout Input) throws(Never) -> Output {
        fatalError()
    }
}
#endif

// MARK: - Variant 3 — Pack-Member Associated-Type Access (CONFIRMED)
//
// Hypothesis: Per-element associated-type access — `(each P).Failure` in
// type-expression position, required to compute
// `Failure = Product<repeat (each P).Failure>` and to drive pack-iteration
// in `parse` — is expressible today, independent of the shared-Input/Output
// question.
//
// Result: CONFIRMED — builds cleanly. `(each P).Failure` resolves in both
// where-clause and typealias position when isolated from V2's placeholder
// error. Earlier (in the parent spike) this appeared to also fail, but the
// "'Failure' is not a member type of type 'each P'" diagnostic was a
// downstream artifact of V2's "type placeholder not allowed here" — once
// V2 is removed, pack-member assoc-type access compiles.
//
// Build evidence: `swift build -Xswiftc -DVARIANT3` succeeds (see
// `Outputs/build-variant3.txt`).
//
// What this narrows: the variadic-OneOf unification turns on V1 alone.
// When same-element requirements ship, the natural shape becomes:
//
//   public struct OneOf<Input, Output, each P: Parseable>: Parseable
//   where
//       repeat (each P).Input == Input,
//       repeat (each P).Output == Output
//   {
//       public typealias Failure = Product<repeat (each P).Failure>
//       public let parsers: (repeat each P)
//       public func parse(_ input: inout Input) throws(Failure) -> Output {
//           // pack iteration: SE-0408 `for parser in repeat each parsers`
//           // failure aggregation: collect per-element failures into a
//           // `Product<each .Failure>`, throw if all fail
//           ...
//       }
//   }
//
// V3 confirms three of the four pieces work today: the variadic-generic
// struct, pack-member assoc-type access on Failure, and variadic Product
// aggregation. The missing fourth piece is same-element constraints from V1.

#if VARIANT3
public struct OneOf_V3<each P: Parseable>: Parseable
where repeat (each P).Failure: Sendable {       // ✓ compiles
    public typealias Input = Never              // intentionally Never —
    public typealias Output = Never             // V3 isolates the per-element
                                                 // access from the shared-I/O
                                                 // question (V1).
    public typealias Failure = Product<repeat (each P).Failure>   // ✓ compiles
    public let parsers: (repeat each P)
    public init(_ parsers: repeat each P) { self.parsers = (repeat each parsers) }
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        fatalError()
    }
}
#endif

// MARK: - Default Build (no VARIANT flag) — infrastructure check

/// Confirms the shared mock types build and a concrete arity-2 conformer
/// constructs cleanly — i.e., the infrastructure is sound; the variant
/// failures are about variadic expression, not about the mock types
/// themselves.
struct DigitParser: Parseable {
    typealias Input = Substring
    typealias Output = Character
    struct E: Error {}
    typealias Failure = E
    func parse(_ input: inout Substring) throws(E) -> Character {
        guard let c = input.first, c.isNumber else { throw E() }
        input.removeFirst()
        return c
    }
}

struct LetterParser: Parseable {
    typealias Input = Substring
    typealias Output = Character
    struct E: Error {}
    typealias Failure = E
    func parse(_ input: inout Substring) throws(E) -> Character {
        guard let c = input.first, c.isLetter else { throw E() }
        input.removeFirst()
        return c
    }
}

let d = DigitParser()
let l = LetterParser()
let p: Product<DigitParser.E, LetterParser.E> = Product(DigitParser.E(), LetterParser.E())
print("infrastructure sound — Product arity-2 constructs cleanly")
print("d: \(type(of: d)), l: \(type(of: l)), p: \(type(of: p))")

// MARK: - Cross-References
//
// - swift-institute/Research/transformation-domain-architecture.md v3.2.0
//   (DECISION 2026-03-04) — the architecture that motivates the variadic
//   question: would Parser.OneOf.Two and Parser.OneOf.Three be expressible
//   as a single Parser.OneOf<each P>?
//
// - swift-institute.org/Swift Institute.docc/Blog/The-Missing-Fourth-Corner.md
//   — companion analysis for Coproduct<each T>. Same family of pack-related
//   compiler blockers: enum_with_pack diagnostic, pack `~Copyable` /
//   `~Escapable` rejection. The variadic-OneOf blockers documented here are
//   the where-clause / constraint-position analogues at the struct-level.
//
// - swift-institute/Skills/modularization/SKILL.md → [MOD-030] — codifies
//   that micro modules (per-arity Parser.OneOf.Two / Parser.OneOf.Three)
//   are deliberate, not workarounds. This experiment is the empirical
//   anchor for that rule's "the variadic shape is upstream-blocked"
//   provenance.
//
// - swift-parser-primitives/Sources/Parser OneOf Primitives/
//   {Parser.OneOf.Two.swift, Parser.OneOf.Three.swift, Parser.OneOf.Builder.swift}
//   — the per-arity types this experiment would have unified, plus the
//   `buildPartialBlock`-based left-fold chain that already absorbs arity ≥ 4
//   via nested `OneOf.Two`.
//
// When to revalidate:
//   On each new Swift toolchain per [META-006]. The day all three diagnostics
//   are FIXED, refactor `Parser.OneOf.Two`/`Parser.OneOf.Three` into a single
//   `Parser.OneOf<each P>` with `Failure = Product<repeat (each P).Failure>`.
