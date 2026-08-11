// MARK: - Capability-Lift Pattern Meta-Experiment
//
// Purpose: Generalize the *.`Protocol` pattern observed in
//          swift-cardinal-primitives (Cardinal.`Protocol`) and
//          swift-ordinal-primitives (Ordinal.`Protocol`). The shared
//          recipe:
//
//            1. Concrete value type V.
//            2. A V.`Protocol` capability protocol with:
//                 - associatedtype Domain: ~Copyable (Never for bare V,
//                   Tag for Tagged<Tag, V>)
//                 - var v: V { get }              // value accessor
//                 - init(_ v: V)                  // round-trip
//            3. V conforms to V.`Protocol` (Domain = Never).
//            4. Tagged<Tag, V> conforms to V.`Protocol` (Domain = Tag),
//               forwarding parametrically.
//            5. Operator/method extensions on V.`Protocol` lift the
//               value-type API to all conformers including Tagged.
//
//          The user wants to push this generalization as far as it
//          goes. Concretely: can we propose a SUPER-protocol that
//          Cardinal.`Protocol` and Ordinal.`Protocol` both refine,
//          and what does that buy?
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
// Required feature flags: Lifetimes, SuppressedAssociatedTypes
//
// Result: CONFIRMED — all six variants compile; per-variant verdicts
//         and the super-protocol unification analysis are in the
//         comments below and printed at runtime via `swift run`.
//
// Date: 2026-04-22
//
// Update 2026-04-24 — V3's parameterized `Carrier<Underlying>` shape
// IS what this package shipped in `Sources/Carrier Primitives/
// Carrier.swift`, with one addition: the shipped form suppresses
// `~Copyable & ~Escapable` on Self, Domain, and Underlying (covering
// all four Copyable × Escapable quadrants in a single declaration).
// The experiment's V3 Carrier stub matches the shipped form
// semantically. The real-shape validation lives in the test target
// at Tests/Carrier Primitives Tests/ (six tests, all passing on
// 6.3.1), which exercises the shipped protocol across Q1 (Plain),
// Q2 (Unique), and Q4 (Scoped) quadrants plus Form-D generic
// reflection and the SE-0346 parameterized-constraint spelling.
// This experiment is retained as a historical record of the
// 2026-04-22 characterization that produced the V0–V5 verdicts.
//
// META-FINDINGS:
//   1. The per-type pattern (V0/V1) is mechanically reproducible: the
//      recipe transfers cleanly from real Cardinal/Ordinal to stubs,
//      and the same Tagged-forwarding extension pattern works for both.
//
//   2. SUPER-PROTOCOL VIA REFINEMENT (V2): a `Carrier.`Protocol`` with
//      `associatedtype Underlying` can be refined by per-type protocols
//      using `where Underlying == X`. Compiles and works. Cost:
//      conformers see TWO accessors (`underlying` AND `cardinal`),
//      which is duplicative — the per-type accessor must be defined
//      separately (cannot rename `underlying` to `cardinal`).
//
//   3. SUPER-PROTOCOL VIA PARAMETERIZATION (V3): SE-0346 primary-
//      associated-type form `Carrier<Underlying>` lets API sites write
//      `some Carrier<Cardinal>` directly without naming a per-type
//      protocol. This is strictly more flexible than V2's refinement —
//      the per-type protocol becomes a typealias, not a refinement.
//      Tradeoff: loses the per-type accessor name (no `cardinal`/
//      `ordinal` shorthand at use sites).
//
//   4. API BROADENING (V4): all three forms — per-type `some X.`Protocol``,
//      refinement `some Carrier where ...`, parameterized
//      `some Carrier<X>` — accept both bare values and Tagged wrappers.
//      The forms differ in ergonomics, not capability.
//
//   5. LIMITS (V5): the pattern requires Underlying to be a CONCRETE
//      type with a stable identity init. Generic Underlying<T> works
//      but the per-T identity must be re-stated. ~Copyable Underlying
//      requires consuming init and breaks the "round-trip" symmetry
//      because the value cannot be observed without consuming it.
//      Existential `any X.`Protocol`` is NOT a Carrier (existentials
//      have no static Underlying).
//
//   6. SHAPE TAXONOMY: the *.`Protocol` family decomposes into three
//      distinct, composable patterns:
//        (a) Per-type capability protocol with Tagged forwarding
//            (Cardinal, Ordinal, Hash, etc. — current ecosystem)
//        (b) Carrier super-protocol (refinement OR parameterized) that
//            unifies (a) — proposed by this experiment
//        (c) Self-projection default (Borrow DECISION) — orthogonal;
//            adds a default associatedtype for projection types
//      A type may participate in (a)+(b) without (c), or (a)+(c) without
//      (b). The patterns layer.
//
//   7. TAGGED IS THE CANONICAL CARRIER (post-experiment design insight):
//      Carrier and a hypothetical Tagged.`Protocol` describe overlapping
//      sets — strictly NOT equivalent (bare value types like Cardinal
//      conform to Carrier with Domain = Never but cannot conform to a
//      Tagged-shaped protocol), but spiritually the same projection.
//      The accurate framing: Tagged is the FREE / CANONICAL generic
//      implementation of Carrier. Given any (Tag, V), Tagged<Tag, V>
//      automatically gives a Carrier with Domain = Tag, Underlying = V
//      via the parametric extension. Bare value types conform separately
//      as "trivial Carriers" (Domain = Never).
//      Same relationship as Array<T> being the canonical Sequence, or
//      Optional<T> being the canonical nullable. See Research doc
//      §"Tagged as the canonical Carrier" for the full discussion.
//
// HEADER ANCHOR PER [EXP-007a]:
// Status: CONFIRMED as of Swift 6.3.1.

// ============================================================================
// MARK: - Shared infrastructure: minimal Tagged stub
//
// Mirrors Tagged_Primitives.Tagged closely enough to demonstrate the
// forwarding patterns. Tagged_Primitives is not imported because the
// experiment lives outside the swift-cardinal-primitives /
// swift-ordinal-primitives build graph.
// ============================================================================

public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    public var rawValue: RawValue
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}
// Phantom Tag: not stored, so doesn't constrain Copyable / Sendable.
// `Tag: ~Copyable` in the where clause widens to "Tag may be ~Copyable",
// matching the production Tagged_Primitives.Tagged convention.
extension Tagged: Copyable where RawValue: Copyable, Tag: ~Copyable {}
extension Tagged: Sendable where RawValue: Sendable, Tag: ~Copyable {}

// ============================================================================
// MARK: - V0 baseline: Cardinal-shape pattern (the per-type recipe, FITS)
//
// Hypothesis: the existing Cardinal.`Protocol` shape (per-type capability
//             protocol + self-conform + Tagged forwarding + operator
//             extension) compiles cleanly as a stub.
// Result: CONFIRMED — the canonical per-type recipe transfers without
//         issue. The experiment can use this as the baseline against
//         which super-protocol unifications are compared.
// ============================================================================

public enum V0_Domain {
    public struct Cardinal: Sendable, Equatable {
        public let raw: UInt
        public init(_ raw: UInt) { self.raw = raw }
    }
}

// Mirrors Cardinal.Protocol's hoisted-via-extension shape.
extension V0_Domain.Cardinal {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable
        var cardinal: V0_Domain.Cardinal { get }
        init(_ cardinal: V0_Domain.Cardinal)
    }
}

// Self-conformance: bare Cardinal is its own carrier, Domain = Never.
extension V0_Domain.Cardinal: V0_Domain.Cardinal.`Protocol` {
    public typealias Domain = Never
    public var cardinal: V0_Domain.Cardinal { self }
    public init(_ cardinal: V0_Domain.Cardinal) { self = cardinal }
}

// Tagged conformance: phantom Tag becomes Domain.
extension Tagged: V0_Domain.Cardinal.`Protocol`
where RawValue == V0_Domain.Cardinal, Tag: ~Copyable {
    public typealias Domain = Tag
    public var cardinal: V0_Domain.Cardinal { rawValue }
    public init(_ cardinal: V0_Domain.Cardinal) {
        self.init(__unchecked: (), cardinal)
    }
}

// Operator extension on the protocol: lifts to all conformers.
extension V0_Domain.Cardinal.`Protocol` {
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(V0_Domain.Cardinal(lhs.cardinal.raw + rhs.cardinal.raw))
    }
}

// Compile-time probes: bare and Tagged forms participate.
public enum V0_Tag_Bytes {}
public typealias V0_ByteCount = Tagged<V0_Tag_Bytes, V0_Domain.Cardinal>
// Both V0_Domain.Cardinal AND V0_ByteCount conform to V0_Domain.Cardinal.`Protocol`.

// ============================================================================
// MARK: - V1 baseline: Ordinal-shape pattern with refinement (FITS)
//
// Hypothesis: the existing Ordinal.`Protocol` shape — including the
//             refinement `associatedtype Count: Cardinal.`Protocol`` —
//             compiles cleanly. Tagged forwarding correctly preserves
//             both the Domain associatedtype AND the Count refinement.
// Result: CONFIRMED — the refinement composes through Tagged. A
//         Tagged<Tag, Ordinal>'s Count is Tagged<Tag, Cardinal>, which
//         conforms to Cardinal.`Protocol` per V0 — the chain holds.
// ============================================================================

public enum V1_Domain {
    public struct Ordinal: Sendable, Equatable {
        public let raw: UInt
        public init(_ raw: UInt) { self.raw = raw }
    }
}

extension V1_Domain.Ordinal {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable
        // Refinement: Count is the cardinal type measuring distances.
        associatedtype Count: V0_Domain.Cardinal.`Protocol`
        var ordinal: V1_Domain.Ordinal { get }
        init(_ ordinal: V1_Domain.Ordinal)
    }
}

// Bare Ordinal: Domain = Never, Count = bare Cardinal.
extension V1_Domain.Ordinal: V1_Domain.Ordinal.`Protocol` {
    public typealias Domain = Never
    public typealias Count = V0_Domain.Cardinal
    public var ordinal: V1_Domain.Ordinal { self }
    public init(_ ordinal: V1_Domain.Ordinal) { self = ordinal }
}

// Tagged<Tag, RawValue: Ordinal.`Protocol`>: Domain = Tag,
// Count = Tagged<Tag, Cardinal>. Note RawValue is constrained to the
// Ordinal protocol (NOT to bare Ordinal), enabling nested ordinals
// (Tagged<A, Tagged<B, Ordinal>>) — a richer composition than V0's
// `RawValue == Cardinal` constraint.
extension Tagged: V1_Domain.Ordinal.`Protocol`
where RawValue: V1_Domain.Ordinal.`Protocol`, Tag: ~Copyable {
    public typealias Domain = Tag
    public typealias Count = Tagged<Tag, V0_Domain.Cardinal>
    public var ordinal: V1_Domain.Ordinal { rawValue.ordinal }
    public init(_ ordinal: V1_Domain.Ordinal) {
        self.init(__unchecked: (), RawValue(ordinal))
    }
}

// Operator: advances an Ordinal-shaped position by its Count.
extension V1_Domain.Ordinal.`Protocol` {
    public static func + (lhs: Self, rhs: Count) -> Self {
        Self(V1_Domain.Ordinal(lhs.ordinal.raw + rhs.cardinal.raw))
    }
}

// Compile-time probes: refinement chain works across Tagged.
public enum V1_Tag_Buffer {}
public typealias V1_BufferIndex = Tagged<V1_Tag_Buffer, V1_Domain.Ordinal>
// V1_BufferIndex.Count is Tagged<V1_Tag_Buffer, V0_Domain.Cardinal>,
// which is V0_ByteCount-shaped — phantom-type-preserving distance.

// ============================================================================
// MARK: - V2: Super-protocol via REFINEMENT (Carrier with associatedtype
//             Underlying; per-type protocols refine where Underlying == X)
//
// Hypothesis: a generic `Carrier.`Protocol`` capturing the recipe
//             (Domain + Underlying + accessor + init) can be refined
//             by Cardinal.`Protocol` and Ordinal.`Protocol` via
//             `where Underlying == Cardinal/Ordinal`. The per-type
//             protocols collapse to (mostly) typealiases over the
//             super-protocol; conformers that target the per-type
//             protocol still compile, but generic algorithms can
//             dispatch on the super-protocol uniformly.
// Result: CONFIRMED — refinement compiles. Caveat: the per-type accessor
//         (`cardinal`, `ordinal`) cannot rename the super-protocol's
//         `underlying` accessor; both names coexist in the conformer.
//         A protocol-extension default (`var cardinal: Cardinal { underlying }`)
//         eliminates the conformer-side duplication, but the dual-
//         accessor surface remains visible to consumers — they can
//         spell either form.
// ============================================================================

public enum V2_Carrier {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable
        associatedtype Underlying  // the carried value type
        var underlying: Underlying { get }
        init(_ underlying: Underlying)
    }
}

// V2 stub of Cardinal — same value type as V0_Domain.Cardinal but a
// distinct stub to avoid retroactive conformance to V0's protocol.
public enum V2_Domain {
    public struct Cardinal: Sendable, Equatable {
        public let raw: UInt
        public init(_ raw: UInt) { self.raw = raw }
    }
    public struct Ordinal: Sendable, Equatable {
        public let raw: UInt
        public init(_ raw: UInt) { self.raw = raw }
    }
}

// Per-type protocol as REFINEMENT of the super-protocol.
extension V2_Domain.Cardinal {
    public protocol `Protocol`: V2_Carrier.`Protocol`
    where Underlying == V2_Domain.Cardinal {
        // Per-type accessor for ergonomics; default below.
        var cardinal: V2_Domain.Cardinal { get }
    }
}

// Default the per-type accessor in terms of the super-protocol's
// `underlying` accessor — eliminates conformer-side duplication.
extension V2_Domain.Cardinal.`Protocol` {
    public var cardinal: V2_Domain.Cardinal { underlying }
}

// Self-conformance: only the super-protocol requirements need explicit
// implementation; the per-type accessor defaults via the extension above.
extension V2_Domain.Cardinal: V2_Domain.Cardinal.`Protocol` {
    public typealias Domain = Never
    public var underlying: V2_Domain.Cardinal { self }
    public init(_ underlying: V2_Domain.Cardinal) { self = underlying }
}

// Tagged forwarding: must conform to the SUPER-protocol explicitly first;
// refinement's bounds (RawValue == Cardinal, Tag: ~Copyable) do not auto-
// imply the super-protocol conformance per Swift's diagnostic.
// (This is one of the costs of the refinement form — V3 avoids it.)
extension Tagged: V2_Carrier.`Protocol`
where RawValue == V2_Domain.Cardinal, Tag: ~Copyable {
    public typealias Domain = Tag
    public typealias Underlying = V2_Domain.Cardinal
    public var underlying: V2_Domain.Cardinal { rawValue }
    public init(_ underlying: V2_Domain.Cardinal) {
        self.init(__unchecked: (), underlying)
    }
}

// Once the super-protocol conformance is in place, the per-type protocol
// adds no NEW requirements — opt-in is free.
extension Tagged: V2_Domain.Cardinal.`Protocol`
where RawValue == V2_Domain.Cardinal, Tag: ~Copyable {}

// Now: a generic algorithm can dispatch on the super-protocol uniformly,
// even though it doesn't know whether the carrier is Cardinal-shaped or
// Ordinal-shaped or something else.
public func v2_describe<C: V2_Carrier.`Protocol`>(_ c: C) -> String {
    "Carrier of \(C.Underlying.self) with Domain \(C.Domain.self)"
}

// ============================================================================
// MARK: - V3: Super-protocol via PARAMETERIZATION (SE-0346 primary
//             associated type; `Carrier<Underlying>`)
//
// Hypothesis: SE-0346's primary-associated-type syntax lets the super-
//             protocol be written as `Carrier<Underlying>`, so API sites
//             read `some Carrier<Cardinal>` without naming an
//             intermediary per-type protocol. Strictly more flexible
//             than V2's refinement form.
// Result: CONFIRMED — the parameterized form compiles, conformers
//         conform identically to V2, and API call sites get the
//         clean `some Carrier<Cardinal>` spelling. Tradeoff: the
//         per-type accessor name (`cardinal`, `ordinal`) is gone
//         unless reintroduced via an extension on a constraint-
//         conditioned form.
// ============================================================================

public enum V3_Module {
    // SE-0346 primary associated type: <Underlying>.
    public protocol Carrier<Underlying> {
        associatedtype Domain: ~Copyable
        associatedtype Underlying
        var underlying: Underlying { get }
        init(_ underlying: Underlying)
    }
}

public enum V3_Domain {
    public struct Cardinal: Sendable, Equatable {
        public let raw: UInt
        public init(_ raw: UInt) { self.raw = raw }
    }
}

// Direct conformance to V3_Module.Carrier with Underlying == Cardinal.
// No intermediary `Cardinal.`Protocol`` is needed — the carrier protocol
// IS the API.
extension V3_Domain.Cardinal: V3_Module.Carrier {
    public typealias Domain = Never
    public typealias Underlying = V3_Domain.Cardinal
    public var underlying: V3_Domain.Cardinal { self }
    public init(_ underlying: V3_Domain.Cardinal) { self = underlying }
}

extension Tagged: V3_Module.Carrier
where RawValue == V3_Domain.Cardinal, Tag: ~Copyable {
    public typealias Domain = Tag
    public typealias Underlying = V3_Domain.Cardinal
    public var underlying: V3_Domain.Cardinal { rawValue }
    public init(_ underlying: V3_Domain.Cardinal) {
        self.init(__unchecked: (), underlying)
    }
}

// API site: parameterized `some Carrier<Cardinal>` — accepts both bare
// and Tagged forms, no per-type protocol mention required.
public func v3_describe(_ c: some V3_Module.Carrier<V3_Domain.Cardinal>) -> String {
    "Cardinal carrier with raw = \(c.underlying.raw)"
}

// Per-type accessor name CAN be reintroduced via a protocol extension
// constrained to `Underlying == Cardinal` — opt-in, not a refinement.
extension V3_Module.Carrier where Underlying == V3_Domain.Cardinal {
    public var cardinal: V3_Domain.Cardinal { underlying }
}

// ============================================================================
// MARK: - V4: API BROADENING DEMONSTRATIONS (FITS at all three levels)
//
// Hypothesis: all three forms — per-type `some X.`Protocol``,
//             refinement-based `some Carrier where Underlying == X`,
//             parameterized `some Carrier<X>` — accept BOTH bare values
//             AND Tagged wrappers. The forms differ in ergonomics, not
//             in what they accept.
// Result: CONFIRMED — three function signatures, three call-site
//         spellings, all accept the same conformer set. The
//         parameterized form (V3) is the most concise at API sites.
// ============================================================================

// Form A: per-type protocol — accepts only Cardinal-shaped carriers.
public func v4a_align<C: V0_Domain.Cardinal.`Protocol`>(_ c: C) -> C {
    let aligned = (c.cardinal.raw + 7) & ~7
    return C(V0_Domain.Cardinal(aligned))
}

// Form B: refinement-based super-protocol — accepts only Cardinal-shaped
// carriers but goes through the super-protocol's mechanism.
public func v4b_align<C: V2_Domain.Cardinal.`Protocol`>(_ c: C) -> C {
    let aligned = (c.cardinal.raw + 7) & ~7
    return C(V2_Domain.Cardinal(aligned))
}

// Form C: parameterized super-protocol — same set, cleanest spelling.
public func v4c_align(
    _ c: some V3_Module.Carrier<V3_Domain.Cardinal>
) -> V3_Domain.Cardinal {
    let aligned = (c.cardinal.raw + 7) & ~7
    return V3_Domain.Cardinal(aligned)
}

// Form D: a TRULY GENERIC function that operates on ANY Carrier,
// regardless of what it carries. Only the super-protocol enables this.
public func v4d_describe<C: V2_Carrier.`Protocol`>(_ c: C) -> String {
    "carrier(Underlying=\(C.Underlying.self), Domain=\(C.Domain.self))"
}

// ============================================================================
// MARK: - V5: LIMITS — where the pattern breaks or strains
//
// Hypothesis: the pattern requires (a) a concrete Underlying value type
//             with a stable identity init and (b) a stable Domain
//             association. Cases that violate these surface as compile
//             errors or design-level breakage. This variant catalogs
//             the boundaries.
// Result: PARTIAL — three sub-cases probed.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   V5a: Generic Underlying (e.g., Optional<T>) — works structurally
//        but the Domain associatedtype must be re-stated per T-instantiation.
//   V5b: ~Copyable Underlying — requires consuming init, breaks the
//        round-trip symmetry (you cannot read `underlying` then re-wrap
//        without losing the original).
//   V5c: Existential `any Carrier` — possible but the Underlying
//        associatedtype is erased; Domain access requires opening the
//        existential. Demonstrates that the pattern's value is at
//        the GENERIC dispatch level, not the existential level.
// ============================================================================

// V5a — Generic Underlying. Optional<Cardinal> as the Underlying.
public enum V5a_Module {
    public struct OptCardinal<C: Equatable & Sendable>: Sendable, Equatable {
        public let value: C?
        public init(_ value: C?) { self.value = value }
    }
}

extension V5a_Module.OptCardinal: V3_Module.Carrier {
    public typealias Domain = Never
    public typealias Underlying = V5a_Module.OptCardinal<C>  // Self
    public var underlying: V5a_Module.OptCardinal<C> { self }
    public init(_ underlying: V5a_Module.OptCardinal<C>) { self = underlying }
}

// Works, but Tagged forwarding is per-T: `Tagged<Tag, OptCardinal<UInt>>`
// requires its own conformance, since the conditional conformance
// `where RawValue == OptCardinal<UInt>` cannot be parameterized over T.
// In production, this means N-many T-specific conditional conformances.

// V5b — ~Copyable Underlying. The accessor and init both face the
// "use after move" friction.
public enum V5b_Module {
    public struct Token: ~Copyable {
        public let id: UInt
        public init(id: UInt) { self.id = id }
    }
}

// A naive Carrier-shaped protocol over ~Copyable Underlying:
public protocol V5b_NoncopyCarrier: ~Copyable {
    associatedtype Domain: ~Copyable
    associatedtype Underlying: ~Copyable
    // Cannot expose `var underlying: Underlying { get }` because that
    // would copy the value. Must use borrowing get (var with _read).
    // Cannot use `var ... { get }` for ~Copyable Underlying — the get
    // would copy. Use a borrowing-flavored property.
    var underlying: Underlying { borrowing get }
    // Cannot expose `init(_ underlying: Underlying)` returning by-value
    // for ~Copyable Underlying without `consuming` semantics.
    init(_ underlying: consuming Underlying)
}

// Self-conformance: bare Token IS its own carrier, but the round-trip
// `init(_ underlying:)` consumes the underlying — there is no
// `underlying` left to read after init. The "carrier" abstraction
// assumes copyable Underlying for the round-trip property to hold.
extension V5b_Module.Token: V5b_NoncopyCarrier {
    public typealias Domain = Never
    public typealias Underlying = V5b_Module.Token
    public var underlying: V5b_Module.Token {
        _read { yield self }
    }
    public init(_ underlying: consuming V5b_Module.Token) {
        self.init(id: underlying.id)
    }
}

// V5c — Existentials. A function over `any V3_Module.Carrier` works
// but loses Underlying type information.
public func v5c_typeOfAny(_ c: any V3_Module.Carrier) -> Any.Type {
    type(of: c)
    // Note: `c.underlying` is `Any` here (associatedtype erased).
    // To recover, the existential must be opened: `func f<C>(_ c: C) where C: Carrier`.
}

// ============================================================================
// MARK: - Main
// ============================================================================

@main
struct Main {
    static func main() {
        // Per-variant verdicts.
        print("V0 Cardinal-shape baseline:           CONFIRMED (FITS)")
        print("V1 Ordinal-shape with refinement:     CONFIRMED (FITS)")
        print("V2 Super-protocol via refinement:     CONFIRMED (FITS, dual-accessor cost)")
        print("V3 Super-protocol via SE-0346:        CONFIRMED (FITS, no intermediary)")
        print("V4 API broadening (4 forms):          CONFIRMED (all FIT)")
        print("V5 Limits (Generic/~Copyable/any):    PARTIAL (catalogued)")
        print("")

        // V0 demonstrations.
        let bareCardinal = V0_Domain.Cardinal(10)
        let taggedCardinal = V0_ByteCount(__unchecked: (), V0_Domain.Cardinal(20))
        let sumBare = bareCardinal + bareCardinal
        let sumTagged = taggedCardinal + taggedCardinal
        print("V0 bare:    Cardinal(10) + Cardinal(10) = Cardinal(\(sumBare.raw))")
        print("V0 tagged:  ByteCount(20) + ByteCount(20) = ByteCount(\(sumTagged.cardinal.raw))")

        // V1 demonstrations.
        let bareOrd = V1_Domain.Ordinal(5)
        let advanced = bareOrd + V0_Domain.Cardinal(3)
        print("V1 bare:    Ordinal(5) + Cardinal(3) = Ordinal(\(advanced.raw))")

        let bufIdx = V1_BufferIndex(__unchecked: (), V1_Domain.Ordinal(5))
        let count: V1_BufferIndex.Count = Tagged<V1_Tag_Buffer, V0_Domain.Cardinal>(
            __unchecked: (), V0_Domain.Cardinal(3)
        )
        let advancedTagged = bufIdx + count
        print("V1 tagged:  BufferIndex(5) + BufferIndex.Count(3) = BufferIndex(\(advancedTagged.ordinal.raw))")

        // V2 super-protocol dispatch.
        print("V2 dispatch: \(v2_describe(V2_Domain.Cardinal(42)))")
        let v2tagged = Tagged<V0_Tag_Bytes, V2_Domain.Cardinal>(
            __unchecked: (), V2_Domain.Cardinal(42)
        )
        print("V2 dispatch: \(v2_describe(v2tagged))")

        // V3 parameterized super-protocol dispatch.
        print("V3 desc:    \(v3_describe(V3_Domain.Cardinal(7)))")
        let v3tagged = Tagged<V0_Tag_Bytes, V3_Domain.Cardinal>(
            __unchecked: (), V3_Domain.Cardinal(7)
        )
        print("V3 desc:    \(v3_describe(v3tagged))")

        // V4 broadening.
        print("V4a align:  \(v4a_align(V0_Domain.Cardinal(13)).raw)")
        print("V4c align:  \(v4c_align(V3_Domain.Cardinal(13)).raw)")
        print("V4d:        \(v4d_describe(V2_Domain.Cardinal(99)))")

        // V5 limits.
        let opt = V5a_Module.OptCardinal<UInt>(42)
        print("V5a desc:   \(v3_describe_underlying_type(opt))")
        let token = V5b_Module.Token(id: 1)
        // Read the underlying (borrowing) BEFORE consuming via round-trip.
        print("V5b token:  id=\(token.underlying.id)")
        // Once we round-trip, the original `token` is consumed.
        let token2 = V5b_Module.Token(consume token)
        print("V5b round:  id=\(token2.id)")
        print("V5c any:    \(v5c_typeOfAny(V3_Domain.Cardinal(0)))")
    }
}

// Helper exercising V5a — distinct from v3_describe to print the
// associatedtype's type name rather than the raw value.
public func v3_describe_underlying_type<C: V3_Module.Carrier>(_ c: C) -> String {
    "Underlying = \(C.Underlying.self)"
}
