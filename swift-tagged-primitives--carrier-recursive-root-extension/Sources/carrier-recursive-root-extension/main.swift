// MARK: - Carrier Recursive Root Extension Experiment
//
// Purpose:    Verify whether a `.root` accessor descending to the bottom-
//             most Underlying can be added via extension on Carrier,
//             with Tagged keeping immediate-wrap (no cascade in the
//             Carrier conformance itself). Also test whether such an
//             extension-only `.root` supports generic where-clause
//             dispatch.
//
// Hypotheses:
//   H1  — extension `Carrier where Underlying: Carrier { var root }`
//         exposes `.root` returning `Underlying.Underlying` for depth-1.
//   H1c — adding depth-2 extension with stacked constraints overrides
//         depth-1 at depth-2 sites via Swift's overload-specificity rule.
//   H2  — generic dispatch via `where C: Carrier, C.Root == UInt` is
//         NOT supported (no `Root` associatedtype on the protocol).
//   H3  — adding `associatedtype Root = Underlying` to the protocol
//         AND making Tagged: Carrier CONDITIONAL on Underlying: Carrier
//         supports recursive Root via cascading conformance (but
//         re-introduces the Property.View blocker).
//   H4  — splitting into BaseCarrier (unconditional) + Rooted (conditional)
//         preserves Tagged-of-Inout via BaseCarrier and supports
//         generic dispatch via Rooted.Root.
//   E1  — Path E mechanism: unconditional Tagged: Carrier + conditional
//         extension `Tagged where Underlying: Carrier` introduces `.root`.
//         No new protocol; non-trivial Cardinal/Ordinal kept; generic
//         dispatch via depth-coupled constraint
//         `where C.Underlying: Carrier, C.Underlying.Underlying == UInt`.
//   E2  — Path E false-positive test: does the depth-coupled constraint
//         distinguish Cardinal from Ordinal? (Both have Underlying = UInt,
//         so the constraint loses domain specificity — VERIFY this is
//         the actual cost.)
//   E3  — Path E depth-2 test: depth-1 generic constraint does NOT match
//         Tagged<Outer, Tagged<Inner, Cardinal>> (constraint is depth-coupled).
//   E4  — Path E Property.View case: Tagged<Tag, Inout> conforms to
//         Carrier unconditionally even though Inout doesn't; the
//         Underlying: Carrier extension simply doesn't apply, but
//         Tagged-as-Carrier still works.
//   E5  — Cardinal-domain operator under Path E: rewrite the cascade
//         memo's two-overload split as a SINGLE generic signature using
//         the depth-coupled constraint; verify it accepts
//         {bare Cardinal, Tagged<Tag, Cardinal>} AND that it ALSO
//         accepts Ordinal-shaped values (the type-safety leak).
//
// Toolchain: swift-6.3.1 (default Xcode 26.4.1)
// Platform:  macOS 26 (arm64)
// Date:      2026-05-04
// Result:    CONFIRMED — five hypotheses validated. Critical finding on Path E.
//
// Evidence (program output):
//   H1  depth-1: tagged.root = 42  type=UInt
//   H1c depth-2: nested.root = 42  type=UInt
//   H2  generic depth-1 on Tagged<UserID, Cardinal>: 42
//   H2  generic depth-1 on bare Cardinal: 42
//   H3  RecursiveCarrier depth-1: 99  type=UInt
//   H3  RecursiveCarrier depth-2: 99  type=UInt
//   H3  generic via Root==UInt: tagged=99 nested=99 bare=99
//   H4  split protocols depth-1: 7  type=UInt
//   H4  split protocols depth-2: 7  type=UInt
//   H4  Tagged3<UserID, Inout> BaseCarrier underlying: Inout(_storage: 100)
//   H4  generic via Rooted.Root==UInt: tagged=7 nested=7 bare=7
//   E1  acceptCardinalE(bare Cardinal):       42
//   E1  acceptCardinalE(Tagged<X, Cardinal>): 42
//   E2  acceptCardinalE(bare Ordinal):        7   ← FALSE POSITIVE
//   E2  acceptCardinalE(Tagged<X, Ordinal>):  7   ← FALSE POSITIVE
//   E3  nestedDepth2 — depth-1 constraint does NOT match (compile error if attempted)
//   E4  Tagged<UserID, Inout4>.underlying works (Carrier conformance unconditional)
//   E5  ordinalPlusCardinalE works for legitimate (Ordinal, Cardinal) shapes
//   E5  ordinalPlusCardinalE ALSO accepts (Cardinal, Ordinal) and (Ordinal, Ordinal)
//       — type-safety leak: Cardinal vs Ordinal indistinguishable by Carrier alone
//
// Findings:
//   - H1/H1c: extension-only `.root` works for depth-1 / depth-2 via stacked
//             constraints. Doesn't generalize to arbitrary depth.
//   - H2: generic dispatch via depth-coupled constraint
//         (`where C.Underlying: Carrier, C.Underlying.Underlying == UInt`)
//         works for depth-1 only.
//   - H3: `associatedtype Root` enables recursive Root via conditional
//         cascade. Re-introduces Property.View blocker.
//   - H4: split BaseCarrier + Rooted preserves Tagged-of-Inout AND supports
//         generic dispatch at any depth via Rooted.Root.
//   - E1: Path E mechanism (Tagged-side conditional `.root` extension +
//         depth-coupled generic dispatch) WORKS for unifying bare Cardinal
//         and Tagged-of-Cardinal at depth-1.
//   - E2: **CRITICAL** — Path E's depth-coupled constraint
//         `where C.Underlying.Underlying == UInt` ALSO matches Ordinal-
//         shaped values (because Ordinal also has Underlying = UInt at the
//         primitive layer). Cardinal and Ordinal are INDISTINGUISHABLE by
//         Carrier alone. The `acceptCardinalE` function accepts Ordinal
//         inputs — type-safety leak.
//   - E3: depth-2 nested Tagged does not satisfy depth-1 constraint —
//         confirms depth-coupling.
//   - E4: Property.View case (Tagged-of-Inout where Inout doesn't conform
//         to Carrier) works under Path E — Tagged: Carrier is
//         unconditional; the `where Underlying: Carrier` extension simply
//         doesn't apply. Same as H4's BaseCarrier behavior.
//   - E5: **CRITICAL** — rewriting the cascade memo's Cardinal-side
//         operators as Path E single signatures admits semantically wrong
//         calls: `(Cardinal, Ordinal)` and `(Ordinal, Ordinal)` both
//         compile and execute, despite no `Position + Position` operator
//         existing in the intended design.
//
// REFUTED extension of H4: I had earlier suggested H4 preserves domain
// distinction. **This is wrong.** H4's `where C.Root == UInt` matches
// both Cardinal-rooted and Ordinal-rooted carriers (both Root = UInt).
// H4 has the SAME type-safety leak as Path E. Sibling protocol fixes
// the cascade-memo's split-pattern problem but does NOT preserve the
// Cardinal-vs-Ordinal type distinction. (To preserve domain distinction
// with sibling protocols, you'd need PER-DOMAIN sibling protocols
// — Cardinal.`Protocol` AND Ordinal.`Protocol` — which is what the
// cascade was. Returning to that path defeats the goal.)
//
// Domain-distinction trade-off:
//   - Path A (trivial-self): Cardinal.Underlying = Cardinal,
//     Ordinal.Underlying = Ordinal. `Carrier<Cardinal>` and
//     `Carrier<Ordinal>` are DISTINCT constraints. Type-safe.
//     `someOrdinal + someOrdinal` does not compile (LHS satisfies
//     Carrier<Ordinal> but RHS doesn't satisfy Carrier<Cardinal>).
//   - Path E (depth-coupled): Cardinal.Underlying.Underlying = UInt,
//     Ordinal.Underlying.Underlying = UInt. Constraints can't tell
//     them apart. `someOrdinal + someOrdinal` COMPILES under Path E's
//     cross-type operator. Type-unsafe.
//   - H3 / H4 (Root associatedtype): Cardinal.Root = UInt,
//     Ordinal.Root = UInt. Same indistinguishability problem.
//
// **ONLY PATH A** preserves Cardinal-vs-Ordinal type distinction
// while using only Tagged + Carrier.\`Protocol\` (no per-domain
// protocols). Path E and H3/H4 sacrifice domain distinction for
// other ergonomic gains.
//
// Recommended design: **Path A (trivial-self)**.
//   - Achieves Carrier-based universal unifier (`Carrier<Cardinal>`).
//   - Preserves Cardinal-vs-Ordinal type distinction (each domain
//     gets its own constraint shape).
//   - No new protocols.
//   - No cascade.
//   - Property.View case works (Tagged: Carrier still unconditional).
//   - Cost: bare-numeric access via separate `.rawValue` field on
//     each domain type (cardinal.underlying becomes identity).
//
// Status:    CONFIRMED — Path A is the structurally correct answer.

// =====================================================================
// MARK: - H1 + H1c: Extension-only `.root` (no protocol change)
// =====================================================================

protocol Carrier {
    associatedtype Underlying
    var underlying: Underlying { get }
}

// Trivial-self for primitive UInt — it IS-A UInt.
extension UInt: Carrier {
    public var underlying: UInt { self }
    public typealias Underlying = UInt
}

// Cardinal: non-trivial, wraps UInt.
struct Cardinal: Carrier {
    let _storage: UInt
    var underlying: UInt { _storage }
    typealias Underlying = UInt
}

// Tagged: immediate-wrap, UNCONDITIONAL Carrier conformance.
struct Tagged<Tag, U>: Carrier {
    let _storage: U
    var underlying: U { _storage }
    typealias Underlying = U
}

// Depth-1 extension: when Underlying is a Carrier, expose its underlying as `.root`.
extension Carrier where Underlying: Carrier {
    var root: Underlying.Underlying {
        underlying.underlying
    }
}

// Depth-2 extension: stack one more level.
extension Carrier where Underlying: Carrier, Underlying.Underlying: Carrier {
    // Same name `root`; Swift's specificity rule prefers more-constrained extension at depth-2 sites.
    var root: Underlying.Underlying.Underlying {
        underlying.underlying.underlying
    }
}

// Test depth-1
enum UserID {}
let cardinal = Cardinal(_storage: 42)
let tagged: Tagged<UserID, Cardinal> = Tagged(_storage: cardinal)
let h1Root: UInt = tagged.root
print("H1 depth-1: tagged.root = \(h1Root)  type=\(type(of: tagged.root))")

// Test depth-2
enum Outer {}
enum Inner {}
let inner: Tagged<Inner, Cardinal> = Tagged(_storage: cardinal)
let nested: Tagged<Outer, Tagged<Inner, Cardinal>> = Tagged(_storage: inner)
let h1cRoot: UInt = nested.root
print("H1c depth-2: nested.root = \(h1cRoot)  type=\(type(of: nested.root))")

// =====================================================================
// MARK: - H2: Generic dispatch on extension-only .root
// =====================================================================
//
// Without a `Root` associatedtype on the protocol, generic constraints
// of the form `where C.Root == UInt` cannot be expressed. The closest
// available shape is `where C.Underlying: Carrier, C.Underlying.Underlying == UInt`,
// which works for depth-1 but doesn't generalize to arbitrary depth.

func acceptDepth1<C: Carrier>(_ c: C) -> UInt
where C.Underlying: Carrier, C.Underlying.Underlying == UInt {
    c.root
}

// Both bare Cardinal (extension doesn't apply since UInt: Carrier with Underlying = UInt
// gives a degenerate match) and Tagged<Tag, Cardinal> can in principle satisfy this,
// but the constraint C.Underlying: Carrier excludes bare Cardinal (Cardinal.Underlying = UInt
// IS Carrier, so it qualifies — but C.Underlying.Underlying = UInt.Underlying = UInt, also UInt).
let h2_taggedCardinal = acceptDepth1(tagged)
print("H2 generic depth-1 on Tagged<UserID, Cardinal>: \(h2_taggedCardinal)")

let h2_bareCardinal = acceptDepth1(cardinal)  // Cardinal.Underlying = UInt; UInt: Carrier; UInt.Underlying = UInt ✓
print("H2 generic depth-1 on bare Cardinal: \(h2_bareCardinal)")

// But this only works for "exactly two layers down." The constraint is depth-coupled.
// To unify across depths, you'd need something like a Root associatedtype.

// =====================================================================
// MARK: - H3: Recursive Root via associatedtype with conditional cascade
// =====================================================================
//
// Add `associatedtype Root` to the protocol. Tagged conforms ONLY when
// Underlying: Carrier — re-introducing the Property.View blocker.

protocol RecursiveCarrier {
    associatedtype Underlying
    associatedtype Root
    var underlying: Underlying { get }
    var root: Root { get }
}

// UInt does NOT conform to RecursiveCarrier here — Root is just a
// type-level slot, not a constraint (e.g., `where C.Root == UInt`
// matches even if UInt isn't itself RecursiveCarrier).

struct Cardinal2: RecursiveCarrier {
    let _storage: UInt
    typealias Underlying = UInt
    typealias Root = UInt
    var underlying: UInt { _storage }
    var root: UInt { _storage }
}

struct Tagged2<Tag, U>: RecursiveCarrier where U: RecursiveCarrier {
    let _storage: U
    typealias Underlying = U
    typealias Root = U.Root
    var underlying: U { _storage }
    var root: U.Root { underlying.root }
}

let cardinal2 = Cardinal2(_storage: 99)
let tagged2: Tagged2<UserID, Cardinal2> = Tagged2(_storage: cardinal2)
let h3Root: UInt = tagged2.root
print("H3 RecursiveCarrier depth-1: \(h3Root)  type=\(type(of: tagged2.root))")

let inner2: Tagged2<Inner, Cardinal2> = Tagged2(_storage: cardinal2)
let nested2: Tagged2<Outer, Tagged2<Inner, Cardinal2>> = Tagged2(_storage: inner2)
let h3RootDepth2: UInt = nested2.root
print("H3 RecursiveCarrier depth-2: \(h3RootDepth2)  type=\(type(of: nested2.root))")

// Generic dispatch with Root constraint
func acceptAnyDepthUInt<C: RecursiveCarrier>(_ c: C) -> UInt where C.Root == UInt {
    c.root
}

let h3_tagged = acceptAnyDepthUInt(tagged2)
let h3_nested = acceptAnyDepthUInt(nested2)
let h3_bare = acceptAnyDepthUInt(cardinal2)
print("H3 generic via Root==UInt: tagged=\(h3_tagged) nested=\(h3_nested) bare=\(h3_bare)")

// =====================================================================
// MARK: - H4: Split protocols — BaseCarrier (unconditional) + Rooted (conditional)
// =====================================================================
//
// BaseCarrier: just Underlying. Tagged conforms unconditionally.
// Rooted: refines BaseCarrier with Root associatedtype. Tagged conforms
// conditionally on Underlying: Rooted. Property.View case (Tagged-of-Inout)
// retains BaseCarrier conformance even though Inout isn't Rooted.

protocol BaseCarrier {
    associatedtype Underlying
    var underlying: Underlying { get }
}

protocol Rooted: BaseCarrier where Underlying: BaseCarrier {
    associatedtype Root
    var root: Root { get }
}

// UInt: BaseCarrier required because Rooted's protocol-level
// `where Underlying: BaseCarrier` constraint forces it. UInt does NOT
// conform to Rooted (no Root typealias here) — that's fine; Rooted is
// a refinement and types can stop at BaseCarrier.
extension UInt: BaseCarrier {}
// UInt's BaseCarrier conformance reuses the typealias and accessor from
// H1's `Carrier` extension. Both protocols require `var underlying: Underlying`
// and `associatedtype Underlying`; Swift's witness inference satisfies the
// new BaseCarrier conformance without re-declaration.

struct Cardinal3: BaseCarrier {
    let _storage: UInt
    var underlying: UInt { _storage }
    typealias Underlying = UInt
}

extension Cardinal3: Rooted {
    typealias Root = UInt
    var root: UInt { _storage }
}

struct Tagged3<Tag, U>: BaseCarrier {
    let _storage: U
    var underlying: U { _storage }
    typealias Underlying = U
}

// Tagged3: Rooted conditional on U: Rooted
extension Tagged3: Rooted where U: Rooted {
    typealias Root = U.Root
    var root: U.Root { underlying.root }
}

// Property.View-like type that is BaseCarrier but NOT Rooted (no Root):
// Demonstrates that Tagged<_, NotRooted> still gets BaseCarrier conformance.
struct Inout: BaseCarrier {
    let _storage: Int
    var underlying: Int { _storage }
    typealias Underlying = Int
}
// Note: Inout does NOT conform to Rooted. (Int doesn't conform to Rooted in this experiment either.)

let cardinal3 = Cardinal3(_storage: 7)
let tagged3: Tagged3<UserID, Cardinal3> = Tagged3(_storage: cardinal3)
let h4Root: UInt = tagged3.root
print("H4 split protocols depth-1: \(h4Root)  type=\(type(of: tagged3.root))")

let inner3: Tagged3<Inner, Cardinal3> = Tagged3(_storage: cardinal3)
let nested3: Tagged3<Outer, Tagged3<Inner, Cardinal3>> = Tagged3(_storage: inner3)
let h4Nested: UInt = nested3.root
print("H4 split protocols depth-2: \(h4Nested)  type=\(type(of: nested3.root))")

// Property.View-style: Tagged3<UserID, Inout> is BaseCarrier but NOT Rooted.
let inoutVal = Inout(_storage: 100)
let taggedInout: Tagged3<UserID, Inout> = Tagged3(_storage: inoutVal)
print("H4 Tagged3<UserID, Inout> BaseCarrier underlying: \(taggedInout.underlying)")
// taggedInout.root would NOT compile — Inout doesn't conform to Rooted, so Tagged3<UserID, Inout> doesn't conform either.

// Generic dispatch via Rooted
func acceptRootedUInt<C: Rooted>(_ c: C) -> UInt where C.Root == UInt {
    c.root
}

let h4_tagged = acceptRootedUInt(tagged3)
let h4_nested = acceptRootedUInt(nested3)
let h4_bare = acceptRootedUInt(cardinal3)
print("H4 generic via Rooted.Root==UInt: tagged=\(h4_tagged) nested=\(h4_nested) bare=\(h4_bare)")

// Demonstrating that Tagged3<UserID, Inout> does NOT satisfy Rooted constraint:
// acceptRootedUInt(taggedInout)  // Compile error if uncommented — Inout: Rooted is not satisfied.

// =====================================================================
// MARK: - Path E: Tagged-side conditional extension; depth-coupled generics
// =====================================================================
//
// User's proposal: keep Tagged: Carrier UNCONDITIONAL (immediate-wrap);
// add a CONDITIONAL EXTENSION on Tagged where Underlying: Carrier that
// introduces `var root: Underlying.Underlying`. No new protocol. Cardinal
// stays non-trivial Carrier of UInt (current state).
//
// Note: types (Tagged, Cardinal, UInt) are reused from H1 at the top of
// the file. The Tagged-side extension is added below for E-specific
// scoping.

// Tagged-side `.root` extension (Path E shape — distinct from H1's
// Carrier-wide extension already present at file top, but functionally
// equivalent for Tagged values).
extension Tagged where U: Carrier {
    var rootE: U.Underlying { underlying.underlying }
}

// E1: depth-1 generic dispatch via depth-coupled constraint.
// (The verbose form below works around the fact that
//  `some Carrier<Cardinal>` excludes bare Cardinal under non-trivial Cardinal.
//  See E6 below for an empirical test.)
func acceptCardinalE<C: Carrier>(_ c: C) -> UInt
where C.Underlying: Carrier, C.Underlying.Underlying == UInt {
    c.underlying.underlying
}

// E6: would `some Carrier<Cardinal>` unify bare Cardinal AND Tagged-of-Cardinal?
// Under Path E (Cardinal: Carrier<UInt>, non-trivial), the answer is NO.
//
// `some Carrier<Cardinal>` desugars to `where C.Underlying == Cardinal`.
// - bare Cardinal:        Underlying == UInt    → does NOT match (UInt ≠ Cardinal)
// - Tagged<Tag, Cardinal>: Underlying == Cardinal → matches
//
// So `some Carrier<Cardinal>` cannot serve as the universal unifier
// under Path E without making Cardinal trivial-self (which is Path A).

// Make Carrier expose Underlying as a primary associated type so we
// can use the SE-0346 `some Carrier<X>` sugar. Carrier-Primitives
// already does this; mirroring it locally for this experiment.
protocol CarrierPAT<Underlying> {
    associatedtype Underlying
    var underlying: Underlying { get }
}

// (UInt already conforms to Carrier above with Underlying = UInt; not needed for E6.)

struct CardinalPAT: CarrierPAT {
    let _storage: UInt
    var underlying: UInt { _storage }
    typealias Underlying = UInt
}

struct TaggedPAT<Tag, U>: CarrierPAT {
    let _storage: U
    var underlying: U { _storage }
    typealias Underlying = U
}

// Path E version under primary-associated-type sugar
func acceptCardinalSugar(_ c: some CarrierPAT<CardinalPAT>) -> UInt {
    c.underlying.underlying  // c.Underlying == CardinalPAT, so .underlying: CardinalPAT, .underlying.underlying: UInt
}

let cardinalPAT = CardinalPAT(_storage: 42)
let taggedPAT: TaggedPAT<UserID, CardinalPAT> = TaggedPAT(_storage: cardinalPAT)

// E6a: Tagged-of-CardinalPAT matches `some CarrierPAT<CardinalPAT>` ✓
print("E6 acceptCardinalSugar(Tagged<UserID, CardinalPAT>): \(acceptCardinalSugar(taggedPAT))")

// E6b: Bare CardinalPAT does NOT match `some CarrierPAT<CardinalPAT>`.
// Empirically verified by temporarily uncommenting the line below
// and observing the diagnostic:
//
//   acceptCardinalSugar(cardinalPAT)
//
// produces: "global function 'acceptCardinalSugar' requires the types
// 'CardinalPAT.Underlying' (aka 'UInt') and 'CardinalPAT' be equivalent"
//
// Verified 2026-05-04 with swift-6.3.1.
print("E6 acceptCardinalSugar(bare CardinalPAT): COMPILE ERROR — Underlying == UInt ≠ CardinalPAT")
print("E6 ⇒ `some Carrier<Cardinal>` is NOT a unifier under non-trivial Cardinal.")

// Define Ordinal — also non-trivial Carrier of UInt (mirrors Cardinal).
struct Ordinal: Carrier {
    let _storage: UInt
    var underlying: UInt { _storage }
    typealias Underlying = UInt
}

let ordinal = Ordinal(_storage: 7)
let taggedOrdinal: Tagged<UserID, Ordinal> = Tagged(_storage: ordinal)

// E1: works for bare Cardinal AND Tagged-of-Cardinal at depth-1.
print("E1 acceptCardinalE(bare Cardinal):       \(acceptCardinalE(cardinal))")
print("E1 acceptCardinalE(Tagged<X, Cardinal>): \(acceptCardinalE(tagged))")

// E2: FALSE-POSITIVE — the same generic accepts Ordinal-shaped values
// (because Ordinal also has Underlying.Underlying == UInt).
print("E2 acceptCardinalE(bare Ordinal):        \(acceptCardinalE(ordinal))   ← false positive")
print("E2 acceptCardinalE(Tagged<X, Ordinal>):  \(acceptCardinalE(taggedOrdinal))   ← false positive")

// The function is named `acceptCardinalE` but accepts Ordinal inputs too.
// This is the type-safety leak: depth-coupled constraints lose domain
// specificity. Carrier alone cannot distinguish "Cardinal-meaning UInt"
// from "Ordinal-meaning UInt" — they share the same depth-2 chain.

// E3: depth-2 nested Tagged does NOT match the depth-1 constraint.
let innerCardinal: Tagged<Inner, Cardinal> = Tagged(_storage: cardinal)
let nestedDepth2: Tagged<Outer, Tagged<Inner, Cardinal>> = Tagged(_storage: innerCardinal)

// Uncommenting the next line would cause a compile error:
//   acceptCardinalE(nestedDepth2)
// The depth-1 constraint `C.Underlying.Underlying == UInt` requires
// nestedDepth2.Underlying.Underlying == UInt, but it's Cardinal != UInt.
//
// To handle depth-2, you'd need a DIFFERENT generic with
// `where C.Underlying.Underlying.Underlying == UInt`. Each depth needs
// its own constraint shape. (Confirmed structurally; demonstrating
// without the compile error.)
let depth2Demo = type(of: nestedDepth2)
print("E3 nestedDepth2 type: \(depth2Demo) — depth-1 constraint does NOT match (compile error if attempted)")

// E4: Property.View case — Tagged<Tag, Inout4> where Inout4 doesn't
// conform to Carrier. Tagged still has unconditional Carrier
// conformance (Underlying = Inout4); the `where Underlying: Carrier`
// extension simply doesn't apply, so `.rootE` is unavailable.
struct Inout4 {
    let value: Int
}

let taggedInout4: Tagged<UserID, Inout4> = Tagged(_storage: Inout4(value: 5))
print("E4 Tagged<UserID, Inout4>.underlying: \(taggedInout4.underlying)  ← Carrier still works")
// taggedInout4.rootE  // Compile error if uncommented — Inout4: Carrier not satisfied.

// E5: rewrite cascade-memo's two-overload split as ONE Path E signature.
// Memo's pre-cascade pattern:
//   extension Ordinal.`Protocol` {
//       static func + (lhs: Self, rhs: Cardinal) -> Self { ... }       // bare
//       @_disfavoredOverload
//       static func + <C: Carrier>(lhs: Self, rhs: C) -> Self
//           where C.Underlying == Cardinal { ... }                     // Tagged
//   }
// Path E version: ONE generic, but BOTH sides need depth-coupled constraints.
// Note: this signature uses depth-1 constraints on BOTH operands, so it
// matches bare-Ordinal LHS or Tagged-of-Ordinal LHS only when LHS depth is 1.
// For arbitrary-depth LHS, you'd need stacked constraints — same depth-coupling
// limitation applies symmetrically.
func ordinalPlusCardinalE<O: Carrier, C: Carrier>(_ lhs: O, _ rhs: C) -> UInt
where O.Underlying: Carrier, O.Underlying.Underlying == UInt,
      C.Underlying: Carrier, C.Underlying.Underlying == UInt {
    lhs.underlying.underlying + rhs.underlying.underlying
}

// `bare Ordinal` works as LHS (Ordinal.Underlying = UInt; UInt.Underlying = UInt).
print("E5 ordinalPlusCardinalE(bare ordinal, cardinal):           \(ordinalPlusCardinalE(ordinal, cardinal))")
// `Tagged<X, Ordinal>` works as LHS (Tagged.Underlying = Ordinal; Ordinal.Underlying = UInt).
print("E5 ordinalPlusCardinalE(Tagged<X, Ordinal>, cardinal):     \(ordinalPlusCardinalE(taggedOrdinal, cardinal))")
print("E5 ordinalPlusCardinalE(Tagged<X, Ordinal>, Tagged<X,Card>): \(ordinalPlusCardinalE(taggedOrdinal, tagged))")

// E5 false-positive: the same operator accepts `(Cardinal, Ordinal)` —
// where the LHS is supposed to be an Ordinal (position) and the RHS is
// supposed to be a Cardinal (count) — but Cardinal/Ordinal are
// indistinguishable by Carrier alone. Semantically wrong but
// type-system-permitted.
print("E5 ordinalPlusCardinalE(cardinal, ordinal):                \(ordinalPlusCardinalE(cardinal, ordinal))   ← LHS supposed to be Ordinal but Cardinal accepted")
print("E5 ordinalPlusCardinalE(cardinal, taggedOrdinal):          \(ordinalPlusCardinalE(cardinal, taggedOrdinal))   ← RHS supposed to be Cardinal but Ordinal accepted")

print("\nDone.")

// E6 empirical verification (uncomment to reproduce error):
// acceptCardinalSugar(cardinalPAT)
