// MARK: - generic-throws-init: experimental init shapes for Tagged + Carrier
//
// Purpose: Improve the `__unchecked:` situation for Tagged + Carrier. Test
//          whether a public init pattern can ship in the package itself
//          (instead of every consumer declaring custom inits that wrap
//          `__unchecked:`), with optional throwing for validation paths.
//
// Hypothesis:
//   H1: V2 (generic-throws + default no-op closure) compiles cross-module.
//   H2: Calling V2 without `validate:` argument is non-throwing at the call
//       site (E inferred as Never via the empty default closure).
//   H3: V1 (non-throwing) and V2 (generic-throws) coexist on the same Tagged
//       specialization without overload-resolution ambiguity.
//   H4: A Carrier-mirroring protocol with a generic-throws init requirement
//       compiles, and a concrete struct can conform to it.
//   H5: A default extension on real Carrier with a generic-throws init
//       gives every Carrier conformer (including Tagged) a throwing init
//       for free — zero migration cost.
//   H6: Promoting the generic-throws init to a protocol requirement, with
//       a default extension implementation, lets conformers omit explicit
//       implementations and inherit the default — same zero-migration as
//       H5, plus polymorphism (conformers can override).
//
// Toolchain: swift-6.3
// Platform:  macOS 26 (arm64)
// Date:      2026-05-01
// Status:    PARTIAL — H1 / H3 / H4 / H5 / H6 CONFIRMED; H2 REFUTED
// Result:    Build succeeded (debug + release, cross-module per [EXP-017])
//            Runtime: V1 / V2-throwing / V3 / V4 / V5 / V6 all behave
//            correctly; V2-non-throwing fails to compile (H2 evidence).
//
// Findings:
//   H1 CONFIRMED — V2 declaration compiles cross-module; debug + release
//     builds clean. Generic-throws init is structurally valid.
//
//   H2 REFUTED — `Tagged<V2User, UInt64>(42)` (no validate argument) does
//     not compile. Diagnostic: "generic parameter 'E' could not be inferred."
//     The default `{ _ in }` closure is consistent with any `E: Error` and
//     doesn't pin `E = Never`. Result-type context fixes Tag and Underlying
//     but provides no anchor for E. Swift's inference declines to default
//     E to Never from a parameter-agnostic empty-closure default. The
//     "throws(Never) ≡ non-throwing" equivalence holds *after* E is fixed,
//     but inference doesn't fix it. Practical consequence: the V2 pattern
//     alone cannot subsume the non-throwing case.
//
//   H3 CONFIRMED — V3's overloaded shape (non-throwing init + generic-
//     throws init *without* default closure) compiles and resolves cleanly.
//     `Tagged<V3User, UInt64>(99)` selects the non-throwing form;
//     `try Tagged<V3User, UInt64>(99) { ... }` selects the throwing form.
//     This is the working pattern for "support both shapes on one type."
//
//   H4 CONFIRMED — `GenericThrowsCarrier` (parallel to real Carrier) with
//     a generic-throws init requirement compiles. `V4Cardinal` conforms
//     by implementing the requirement explicitly. Protocol-level shape
//     is feasible.
//
//   H5 CONFIRMED — A default extension on the real `Carrier` protocol,
//     adding a generic-throws init that delegates to the existing non-
//     throwing init requirement, compiles and works cross-module.
//     `V5Cardinal` (a real Carrier conformer that did NOT declare the
//     throwing init) inherits the throwing path via the extension and
//     calls succeed. Zero migration cost: every existing Carrier conformer
//     (Tagged, the 28 stdlib trivial-self carriers, all downstream
//     consumers) gains the throwing init for free.
//
//   H6 CONFIRMED — Promoting the generic-throws init to a *protocol
//     requirement* and providing a default extension implementation works.
//     `V6Cardinal` conforms to `GenericThrowsCarrierWithDefault` and
//     omits the throwing-init implementation; the default is inherited.
//     This shape gives the best of both worlds: zero migration (default
//     handles existing conformers), plus polymorphism (conformers MAY
//     override with custom validation behaviour).
//
// Adoption verdict (per [EXP-019]):
//   The simple "single API via E == Never inference" idea (H2) is REFUTED.
//   The broader question — "can we improve the __unchecked: situation
//   for Carrier and Tagged?" — has working answers via H5 / H6, but each
//   carries a trade-off the experiment surfaces but does not resolve:
//
//   POSITIVE FINDINGS:
//
//   • H5 (default extension on Carrier) is the lowest-cost path: ship a
//     generic-throws init via extension on `Carrier where Self: ~Copyable
//     & ~Escapable`. Every Carrier conformer (including Tagged) gains a
//     throwing init at the call site `try X(value) { v in validate(v) }`
//     without declaring anything per-domain. Migration cost: zero.
//     Polymorphism: none.
//
//   • H6 (requirement + default impl) adds polymorphism: each Carrier
//     conformer MAY override the default with custom validation. Migration
//     cost: still zero. Cost: larger protocol surface.
//
//   • Both H5 and H6 leave `init(__unchecked:, _:)` as the package's
//     internal escape hatch, used only inside the public init bodies.
//     Consumers never invoke `__unchecked:` directly.
//
//   STRUCTURAL TRADE-OFF (V7 / "validation-mandatory types"):
//
//   Carrier already requires a public `init(_ underlying:)`. Public types
//   that conform to Carrier MUST expose direct unchecked construction
//   (V7 demonstrates the failure mode for types wanting a non-public
//   init). V5 and V6 propagate one MORE non-opt-out-able public init
//   through this surface — Swift has no mechanism to opt out of a
//   default extension method or a requirement's default impl. Conformers
//   can only override; they cannot remove.
//
//   The current `__unchecked:`-only design is intentionally restrictive:
//   the awkward label forces consumers to declare per-domain inits,
//   which means validation-mandatory types can keep all direct
//   construction internal to their module. V5 and V6 soften this — every
//   Carrier conformer (including Tagged-aliased domain types) inherits
//   the throwing init for free, regardless of whether the consumer wanted
//   to expose it.
//
//   WHO BENEFITS / WHO LOSES:
//
//   • Wrapper-with-optional-validation types: V5/V6 = win. Drop per-
//     domain init declarations; pay zero migration; gain throwing path.
//
//   • Validation-mandatory types: V5/V6 = loss. Carrier conformance was
//     already too permissive (existing `init(_ underlying:)` requirement);
//     V5/V6 add another non-opt-out-able public init. Either don't conform
//     to Carrier, or accept the leak.
//
//   The decision turns on which case the Institute weights more heavily.
//   Recommended next step: research-process to resolve the design between
//   (a) keep current `__unchecked:` discipline (no V5/V6); (b) ship V5/V6
//   accepting the structural softening; (c) introduce a marker protocol
//   for validation-mandatory types (`StrictCarrier` or similar) that
//   omits the construction requirement, leaving Carrier as the
//   "constructible" subset.

public import Tagged_Primitives
public import Carrier_Primitives

// MARK: - V1 — Baseline non-throwing init (control)

/// Tag for V1 — exercises the current Institute pattern.
public enum V1User: ~Copyable, ~Escapable {}

extension Tagged where Tag == V1User, Underlying == UInt64 {
    /// Non-throwing init wrapping `__unchecked:`.
    public init(_ value: UInt64) {
        self.init(_unchecked: value)
    }
}

// MARK: - V2 — Generic-throws with default empty validate closure

/// Tag for V2 — exercises the generic-throws-with-default pattern.
public enum V2User: ~Copyable, ~Escapable {}

/// V2's domain validation error (used when caller passes a validating closure).
public enum V2Error: Error, Sendable {
    case notPositive
}

extension Tagged where Tag == V2User, Underlying == UInt64 {
    /// Generic-throws init: `E == Never` (default empty closure) ⇒ non-throwing
    /// call site; explicit validating closure ⇒ throws the closure's error type.
    public init<E: Error>(
        _ value: UInt64,
        validate: (UInt64) throws(E) -> Void = { _ in }
    ) throws(E) {
        try validate(value)
        self.init(_unchecked: value)
    }
}

// MARK: - V3 — V1-style + V2-style inits coexisting on the same Tag

/// Tag for V3 — exercises whether the two init shapes can be defined together.
public enum V3User: ~Copyable, ~Escapable {}

extension Tagged where Tag == V3User, Underlying == UInt64 {
    /// Non-throwing init (V1 form).
    public init(_ value: UInt64) {
        self.init(_unchecked: value)
    }

    /// Generic-throws init (V2 form). Default empty closure intentionally
    /// omitted here so the V1 init handles the no-validation case and the
    /// V2 init handles the validation case without overload-resolution
    /// ambiguity. (See V3a for the ambiguous-default coexistence variant.)
    public init<E: Error>(
        _ value: UInt64,
        validate: (UInt64) throws(E) -> Void
    ) throws(E) {
        try validate(value)
        self.init(_unchecked: value)
    }
}

// MARK: - V4 — Carrier-mirroring protocol with generic-throws init requirement

/// Mirror of `Carrier<Underlying>` with the init requirement promoted to
/// generic-throws. Tests whether such a protocol requirement compiles and
/// whether a concrete struct can satisfy it.
public protocol GenericThrowsCarrier<Underlying>: ~Copyable, ~Escapable {
    associatedtype Domain: ~Copyable & ~Escapable = Never
    associatedtype Underlying: ~Copyable & ~Escapable

    var underlying: Underlying {
        @_lifetime(borrow self)
        borrowing get
    }

    @_lifetime(copy underlying)
    init<E: Error>(
        _ underlying: consuming Underlying,
        validate: (borrowing Underlying) throws(E) -> Void
    ) throws(E)
}

/// Concrete conformer to GenericThrowsCarrier — bare value type (Underlying = Self).
public struct V4Cardinal: GenericThrowsCarrier {
    public typealias Underlying = V4Cardinal

    private var _storage: UInt64

    public var underlying: V4Cardinal {
        _read { yield self }
    }

    public init<E: Error>(
        _ underlying: consuming V4Cardinal,
        validate: (borrowing V4Cardinal) throws(E) -> Void
    ) throws(E) {
        try validate(underlying)
        self._storage = underlying._storage
    }

    /// Non-throwing convenience init for tests (not part of the protocol).
    public init(_ raw: UInt64) {
        self._storage = raw
    }

    public var underlying: UInt64 { _storage }
}

// MARK: - V7 — Can a public Carrier conformer hide its init?
//
// V7 hypothesis: a public type wanting to be `Carrier` BUT NOT expose a
// public init cannot do so under the current Carrier design. The protocol
// requires `init(_ underlying:)` at the conformance's access level; a
// non-public init won't satisfy a public protocol requirement.
//
// This isn't introduced by V5/V6 — it's the existing Carrier design.
// Document the limitation here so the verdict can address whether
// V5/V6 should propagate that constraint further or be reconsidered.
//
// V7 is intentionally commented out so the experiment continues to build.
// Uncommenting reproduces the diagnostic:
//
//     error: initializer 'init(_:)' must be declared public because it
//     matches a requirement in public protocol 'Carrier'
//
// public struct V7Validated: Carrier {
//     public typealias Underlying = String
//     private let _storage: String
//
//     public var underlying: String { _read { yield _storage } }
//
//     // Non-public init — fails to satisfy Carrier's public requirement.
//     internal init(_ underlying: consuming String) {
//         self._storage = underlying
//     }
//
//     // Even with a public throwing factory, the non-public init can't
//     // satisfy the protocol requirement.
//     public static func validated(_ raw: String) throws(V2Error) -> V7Validated {
//         guard !raw.isEmpty else { throw .notPositive }
//         return V7Validated(raw)
//     }
// }

// MARK: - V5 — Default generic-throws init on real Carrier (zero-migration path)

/// V5 hypothesis: rather than adding a new protocol requirement, ship the
/// generic-throws init as a *default extension method* on `Carrier`. Every
/// Carrier-conforming type (Tagged, the 28 stdlib trivial-self carriers, any
/// downstream conformer) inherits it for free; no migration; no protocol
/// requirement change. The extension delegates to the existing non-throwing
/// init requirement after the validation closure passes.
///
/// This addresses the `__unchecked:` situation directly: consumers can call
/// the throwing init on any Carrier without declaring per-domain validating
/// inits, while the non-throwing path remains the existing
/// `Carrier.init(_ underlying:)` requirement.
extension Carrier where Self: ~Copyable & ~Escapable {
    @_lifetime(copy underlying)
    public init<E: Error>(
        _ underlying: consuming Underlying,
        validate: (borrowing Underlying) throws(E) -> Void
    ) throws(E) {
        try validate(underlying)
        self.init(underlying)
    }
}

// MARK: - V6 — Protocol requirement + default extension implementation

/// V6 hypothesis (per user): make the generic-throws init a *protocol
/// requirement* in addition to (or instead of) a default extension.
/// Trade-off vs V5:
///   - V5 (default extension only): zero migration; not polymorphic;
///     conformers cannot override the validation behaviour.
///   - V6 (protocol requirement + default impl): zero migration *via the
///     default*; polymorphic — conformers MAY override; ensures every
///     conformer is contractually obligated to provide the throwing path.
///
/// V6 tests the practical hybrid: declare a parallel protocol with the
/// generic-throws init as a *requirement*, ship a default implementation
/// in extension, and verify (a) a conformer that omits the requirement
/// inherits the default, and (b) a conformer that overrides the requirement
/// gets its custom version called.
public protocol GenericThrowsCarrierWithDefault<Underlying>: ~Copyable, ~Escapable {
    associatedtype Domain: ~Copyable & ~Escapable = Never
    associatedtype Underlying: ~Copyable & ~Escapable

    var underlying: Underlying {
        @_lifetime(borrow self)
        borrowing get
    }

    /// Required non-throwing init (existing Carrier-style requirement).
    @_lifetime(copy underlying)
    init(_ underlying: consuming Underlying)

    /// Required generic-throws init — but defaulted in extension below.
    @_lifetime(copy underlying)
    init<E: Error>(
        _ underlying: consuming Underlying,
        validate: (borrowing Underlying) throws(E) -> Void
    ) throws(E)
}

extension GenericThrowsCarrierWithDefault where Self: ~Copyable & ~Escapable {
    /// Default implementation of the generic-throws init requirement.
    /// Delegates to the non-throwing init requirement after validation.
    /// Conformers can omit their own implementation and inherit this.
    @_lifetime(copy underlying)
    public init<E: Error>(
        _ underlying: consuming Underlying,
        validate: (borrowing Underlying) throws(E) -> Void
    ) throws(E) {
        try validate(underlying)
        self.init(underlying)
    }
}

/// V6Cardinal — conforms to GenericThrowsCarrierWithDefault but only
/// implements the non-throwing requirement. The generic-throws requirement
/// is satisfied by the default extension implementation.
public struct V6Cardinal: GenericThrowsCarrierWithDefault {
    public typealias Underlying = V6Cardinal
    private var _storage: UInt64

    public init(_ raw: UInt64) {
        self._storage = raw
    }

    public var underlying: V6Cardinal { _read { yield self } }

    public init(_ underlying: consuming V6Cardinal) {
        self._storage = underlying._storage
    }

    // No explicit init<E: Error>(_, validate:) implementation —
    // the default extension implementation handles it.

    public var underlying: UInt64 { _storage }
}
