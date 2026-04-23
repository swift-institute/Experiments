// MARK: - Self-Projection Default Pattern Meta-Experiment
//
// Purpose: Empirically characterize where the "self-projection default"
//          meta-pattern (generalized from the Ownership.Borrow unification
//          DECISION) applies, and where preconditions fail. The pattern:
//
//            "Whenever a namespace N contains (a) a generic struct
//             N<Value: Cs_V> and (b) a capability protocol N.`Protocol`
//             expressing 'conformers have an N-shaped projection of
//             themselves,' the protocol's associatedtype representing
//             that projection can default to N<Self>. Constraint-
//             compatibility: Self's suppressions on the protocol MUST
//             be ⊆ Value's suppressions on the generic struct."
//
//          The Borrow case is the origin. This experiment probes whether
//          and where else the shape fits, classifying candidates as
//          CONFIRMED (fits), REFUTED (does not fit), DEGENERATE (fits
//          partially), or BLOCKED (cannot be built as expected).
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
// Required feature flags: Lifetimes, SuppressedAssociatedTypes
//
// Result: CONFIRMED — Build Succeeded; `swift run` prints per-variant
//         classification. Six variants authored; see per-variant result
//         lines below and Research/self-projection-default-pattern.md
//         for the classification rationale.
//
// Date: 2026-04-22
//
// META-FINDINGS:
//   1. The self-projection default pattern FITS when the namespace
//      supplies (a) a single-parameter generic struct N<Value> and
//      (b) a capability protocol whose associatedtype represents a
//      projection of the conformer itself. V0 (Borrow baseline) and
//      V1 (Mutate mirror) CONFIRM.
//
//   2. The pattern DOES NOT FIT cleanly when the generic struct has
//      TWO unordered type parameters with no canonical Self-to-param
//      assignment. V2 (Property<Tag, Base>) documents this — the
//      default `= Property<???, Self>` has no natural resolution, and
//      the compiler cannot infer one associatedtype from the absence
//      of another. V2 is REFUTED for the self-projection shape, though
//      Property DOES admit a different (two-associatedtype) pattern.
//
//   3. Constraint compatibility (Self suppressions ⊆ Value suppressions)
//      is load-bearing: violating it at the default's substitution site
//      produces exactly the diagnostic the Borrow V3 finding predicted.
//      V3 captures the error form and documents the diagnostic.
//
//   4. The pattern admits a DEGENERATE case: a namespace N with a
//      capability protocol N.`Protocol` but NO sibling generic struct
//      N<Value>. V4 (Hash-shape) shows that the protocol can still
//      carry an associatedtype default, but the default is a fixed
//      non-generic type (e.g., `Hash.Value`), not a projection of Self.
//      This is structurally a different pattern — "capability-default"
//      rather than "self-projection default." The DECISION's pattern
//      name should be read strictly.
//
//   5. Not every namespace with shape {N, N<T>, N.`Protocol`} is a
//      self-projection pattern. V5 (Memory.Contiguous shape) shows a
//      structural lookalike where the protocol's associatedtype is an
//      attribute of the conformer (Element), not a projection of Self.
//      Here, a default `Element = Memory.Contiguous<Self>.Element` is
//      nonsensical — Element is an axis orthogonal to Self. V5 DOES
//      NOT FIT. This is the most important negative finding: the
//      pattern is defined by the *role* of the associatedtype, not
//      by the *structure* of the namespace.
//
// HEADER ANCHOR PER [EXP-007a]:
// Status: CONFIRMED as of Swift 6.3.1 — six variants authored, each
//         compiles per its hypothesis, classifications documented.

// ============================================================================
// MARK: - V0 baseline: Ownership.Borrow shape (self-projection default FITS)
//
// Hypothesis: The canonical self-projection default pattern — single-parameter
//             generic struct + capability protocol + hoisted typealias +
//             associatedtype default = N<Self> — compiles end-to-end.
// Result: CONFIRMED — mirrors the Borrow experiment V8/V8_PathC/V10 shape.
// ============================================================================

// Hoisted module-scope protocol for V0 (can't nest in generic context
// per SE-0404).
public protocol __V0_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable
        = V0_Ownership.Borrow<Self>
}

public enum V0_Ownership {
    // Generic struct Value admits the full suppression set (~Copyable & ~Escapable)
    // so the associatedtype default Borrow<Self> type-checks when Self admits
    // ~Escapable.
    //
    // Implementation note: we use UnsafeRawPointer (untyped) rather than
    // UnsafePointer<Value> to sidestep UnsafePointer's implicit Value: Escapable
    // constraint on Swift 6.3.1. The meta-pattern under study is about the
    // protocol↔associatedtype↔generic-struct shape, not about typed-pointer
    // storage; mirrors the Borrow experiment V8's use of UnsafeRawPointer.
    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {
        @usableFromInline let _pointer: UnsafeRawPointer
        @inlinable init(_ ptr: UnsafeRawPointer) {
            unsafe (self._pointer = ptr)
        }
        public typealias `Protocol` = __V0_Borrow_Protocol
    }
}

// Case A conformer: no interior storage — default applies, no custom type.
public struct V0_Ordinal: ~Copyable, V0_Ownership.Borrow.`Protocol` {}

// Case B conformer: custom specialization overrides the default.
public struct V0_Path: ~Copyable {}
public extension V0_Path {
    struct Borrowed: ~Copyable, ~Escapable {
        let _pointer: UnsafeRawPointer
    }
}
extension V0_Path: V0_Ownership.Borrow.`Protocol` {}

// Compile-time probe: default resolution works.
public typealias _V0_OrdinalBorrowed = V0_Ordinal.Borrowed
// _V0_OrdinalBorrowed ≡ V0_Ownership.Borrow<V0_Ordinal>

// ============================================================================
// MARK: - V1: Ownership.Mutate mirror (self-projection default FITS with
//             a *narrower* Value constraint than Borrow)
//
// Hypothesis: Same shape as V0 but with UnsafeMutablePointer — the SE-0519
//             Mutate<T> counterparty. This is the strongest hypothesis:
//             if the meta-pattern is real, a one-to-one translation of
//             the Borrow shape to a mutate shape MUST work.
//
// Note: The ecosystem currently names this type `Ownership.Inout<Value>`
//       rather than `Ownership.Mutate<Value>`; the handoff uses the
//       SE-0519 pitch-name `Mutate`. The shape is identical either way
//       — this variant tests the shape, not the name.
//
// Discovery during implementation: UnsafeMutablePointer<Value> requires
//       Value: Escapable on Swift 6.3.1, whereas UnsafePointer<Value>
//       admits Value: ~Escapable. Consequence: V1's generic parameter
//       Value can ONLY be ~Copyable (not ~Copyable & ~Escapable). By
//       the constraint-compatibility rule, the protocol's Self MUST
//       also be restricted — Self: ~Copyable only, not ~Escapable.
//       Pattern still fits, with narrower suppressions end-to-end.
// Result: CONFIRMED (FITS) — with the narrowing noted above. The shape
//         translates 1:1, but Value's Escapable requirement propagates
//         to the protocol's Self. Mirrors the ecosystem's actual
//         Ownership.Inout<Value: ~Copyable> declaration.
// ============================================================================

public protocol __V1_Mutate_Protocol: ~Copyable {
    associatedtype Mutated: ~Copyable, ~Escapable
        = V1_Ownership.Mutate<Self>
}

public enum V1_Ownership {
    public struct Mutate<Value: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline let _pointer: UnsafeMutableRawPointer
        @inlinable
        @_lifetime(borrow ptr)
        init(_ ptr: UnsafeMutableRawPointer) {
            unsafe (self._pointer = ptr)
        }
        public typealias `Protocol` = __V1_Mutate_Protocol
    }
}

// Case A conformer: accept the default.
public struct V1_Token: ~Copyable, V1_Ownership.Mutate.`Protocol` {}

// Case B conformer: specialization override.
public struct V1_Path: ~Copyable {}
public extension V1_Path {
    struct Mutated: ~Copyable, ~Escapable {
        let _pointer: UnsafeMutableRawPointer
    }
}
extension V1_Path: V1_Ownership.Mutate.`Protocol` {}

// Compile-time probe: default resolves; specialization overrides.
public typealias _V1_TokenMutated = V1_Token.Mutated
// _V1_TokenMutated ≡ V1_Ownership.Mutate<V1_Token>
public typealias _V1_PathMutated = V1_Path.Mutated
// _V1_PathMutated ≡ V1_Path.Mutated (the custom struct)

// ============================================================================
// MARK: - V2: Property<Tag, Base> two-param shape (REFUTED)
//
// Hypothesis: The self-projection default pattern DOES NOT apply cleanly
//             to namespaces whose canonical generic struct has TWO type
//             parameters, neither of which is uniquely "Self." The
//             default `associatedtype Projection = Property<???, Self>`
//             has no natural resolution for the missing argument.
//
// Demonstration: we construct the closest approximation and show that
//                either (a) the default requires two associatedtypes
//                (Tag and Projection), turning the pattern into
//                something structurally different (two-associatedtype
//                protocol, not a self-projection default), or (b) a
//                fixed-Tag default (e.g., Property<SomeTag, Self>)
//                hardcodes an arbitrary Tag, which is semantically
//                incorrect for a general protocol.
//
// Result: REFUTED — the self-projection default pattern does not apply
//         to two-param generic structs with no canonical Self-to-param
//         assignment. Property admits a DIFFERENT pattern (two
//         associatedtypes) but that is not the pattern under study.
// ============================================================================

// The two-param Property type, mirroring swift-property-primitives.
public struct V2_Property<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline var _base: Base
    @inlinable public init(_ base: consuming Base) {
        self._base = base
    }
}

// Attempt A (sub-hypothesis): drop one parameter by fixing Tag, default over Self.
// This is structurally a ONE-parameter pattern applied to a two-parameter struct
// — it commits to a canonical Tag for the default, which may not suit all
// conformers. Compiles, but only because it has bypassed the two-param
// generality of Property.
//
// Note: Self: ~Copyable (no ~Escapable), matching V2_Property's actual
// constraints. Property in the ecosystem is ~Copyable-only, not ~Escapable.
public enum V2_TagA {}  // arbitrary fixed tag for the default

public protocol __V2a_Property_Protocol: ~Copyable {
    associatedtype Projection: ~Copyable
        = V2_Property<V2_TagA, Self>  // fixed-Tag default
}

extension V2_Property where Base: ~Copyable {
    public typealias `Protocol` = __V2a_Property_Protocol
}

public struct V2_Container: ~Copyable, __V2a_Property_Protocol {}
// Compiles, but this is NOT the self-projection default pattern — it is
// a self-projection-default-plus-fixed-Tag pattern, a different shape.
public typealias _V2a_ContainerProjection = V2_Container.Projection
// _V2a_ContainerProjection ≡ V2_Property<V2_TagA, V2_Container>

// Attempt B (sub-hypothesis): two associatedtypes — Tag AND Projection —
// with Projection defaulting to Property<Tag, Self>. This DOES compile,
// proving the shape is expressible, but it is structurally richer than
// the self-projection default: it requires the conformer to declare Tag
// in addition to Projection. The conformer does more work; the "default"
// is parameterized on a value Self supplies, not a uniform N<Self>.

public protocol __V2b_Property_Protocol: ~Copyable {
    associatedtype Tag
    associatedtype Projection: ~Copyable
        = V2_Property<Tag, Self>
}

public struct V2_ContainerB: ~Copyable {}
extension V2_ContainerB: __V2b_Property_Protocol {
    public typealias Tag = V2_TagA
}
public typealias _V2b_ContainerBProjection = V2_ContainerB.Projection
// Resolves to V2_Property<V2_TagA, V2_ContainerB>

// Verdict: The literal self-projection default pattern (ONE associatedtype
// defaulting to N<Self>) does not fit Property<Tag, Base>. The closest
// expressible analogues (Attempt A, Attempt B) are distinct patterns that
// compromise either generality (fixed Tag) or the "single associatedtype"
// shape (two associatedtypes). Property's two-param structure is
// orthogonal to self-projection.

// ============================================================================
// MARK: - V3: Constraint-compatibility failure (REFUTED with diagnostic)
//
// Hypothesis: When the protocol's Self admits suppressions that the
//             generic struct's Value does not — Self: ~Escapable but
//             Value: Escapable — the default `= N<Self>` fails type-
//             checking at its substitution site. The compiler's error
//             locates the mismatch and names the missing conformance.
// Result: REFUTED at compile time — the invalid form is commented out
//         with the diagnostic captured verbatim. This documents the
//         failure shape and confirms constraint compatibility is load-
//         bearing per the V3 finding from the Borrow experiment.
// ============================================================================

// The hoisted protocol admits Self: ~Escapable.
public protocol __V3_Incompatible_Protocol: ~Copyable, ~Escapable {
    // Default below would need V3_Ownership.Borrow<Self>, but Borrow's
    // Value is Escapable-only, so Self (which may be ~Escapable) cannot
    // satisfy Borrow<Self>. The commented-out default documents the
    // diagnostic:
    //
    //   error: type 'Self' does not conform to protocol 'Escapable'
    //          associatedtype Borrowed: ~Copyable, ~Escapable
    //                                              ^
    //          = V3_Ownership.Borrow<Self>
    //            ~~~~~~~~~~~~~~~~~~~~~~~~~
    //
    // associatedtype Borrowed: ~Copyable, ~Escapable
    //     = V3_Ownership.Borrow<Self>   // UNCOMMENTING THIS FAILS TO COMPILE

    // Safe form (no default): the protocol compiles; conformers must
    // always supply Borrowed explicitly, losing the "opt-in one-liner"
    // ergonomics the pattern grants.
    associatedtype Borrowed: ~Copyable, ~Escapable
}

public enum V3_Ownership {
    // Note: Value omits `~Escapable` — deliberately narrower than the protocol's Self.
    public struct Borrow<Value: ~Copyable>: ~Escapable {
        @usableFromInline let _pointer: UnsafePointer<Value>
        @inlinable init(_ ptr: UnsafePointer<Value>) {
            unsafe (self._pointer = ptr)
        }
    }
}

// Conformers in the mismatched world can still compile IF they supply
// Borrowed explicitly — the mismatch only bites at the DEFAULT site.
public struct V3_Conformer: ~Copyable {}
public extension V3_Conformer {
    struct Borrowed: ~Copyable, ~Escapable {
        let _pointer: UnsafeRawPointer
    }
}
extension V3_Conformer: __V3_Incompatible_Protocol {}

// Verdict: The pattern's preconditions are load-bearing. Silencing the
// constraint mismatch by dropping the default reintroduces the Viewable
// burden (every conformer authors a nested type). Maintaining the default
// REQUIRES widening Value's constraints to match the protocol's Self —
// this is exactly the widening the Borrow DECISION prescribes
// (Value: ~Copyable → Value: ~Copyable & ~Escapable).

// ============================================================================
// MARK: - V4: Hash-style degenerate shape (DEGENERATE — partial fit)
//
// Hypothesis: A namespace N with a capability protocol N.`Protocol` but
//             WITHOUT a sibling generic struct N<Value> can still carry
//             an associatedtype default — but the default is a fixed
//             non-generic type rather than a projection of Self. The
//             pattern's spirit (reduce conformer authorship burden)
//             applies; its letter (Self-parameterization) does not.
// Result: CONFIRMED structurally, but DEGENERATE w.r.t. the self-
//         projection default pattern. Compiles end-to-end; the default
//         is a capability-level default, not a self-projection default.
// ============================================================================

// Hash is an empty namespace enum in the ecosystem.
public enum V4_Hash {}

// Hash.Value is a concrete (non-generic) type — not Hash<T>.
extension V4_Hash {
    public struct Value {
        public let raw: Int
        public init(raw: Int) { self.raw = raw }
    }
}

// Hash.`Protocol` can still carry an associatedtype with a default —
// but the default is fixed (Hash.Value), not a projection of Self.
public protocol __V4_Hash_Protocol: ~Copyable {
    associatedtype HashResult = V4_Hash.Value
    borrowing func hashValue() -> HashResult
}

extension V4_Hash {
    public typealias `Protocol` = __V4_Hash_Protocol
}

// Conformer accepting the default.
public struct V4_Token: ~Copyable, V4_Hash.`Protocol` {
    public borrowing func hashValue() -> V4_Hash.Value {
        V4_Hash.Value(raw: 0)
    }
}

// Compile-time probe: default resolves.
public typealias _V4_TokenHashResult = V4_Token.HashResult
// _V4_TokenHashResult ≡ V4_Hash.Value — NOT parameterized by Self.

// Verdict: The "namespace + protocol with default" shape exists without
// a sibling generic struct. The default can reduce conformer authorship
// cost (same spirit) but loses the Self-parameterization (different
// letter). Calling this a self-projection default conflates two
// patterns; the meta-pattern should name itself strictly. This variant
// confirms that preconditions (a) sibling generic struct AND (b)
// protocol whose associatedtype represents a projection of Self are
// both load-bearing.

// ============================================================================
// MARK: - V5: Memory.Contiguous-shape structural lookalike (DOES NOT FIT)
//
// Hypothesis: A namespace N with ALL three structural elements —
//             enum N, generic struct N<T>, capability protocol
//             N.`Protocol` — can still fail the self-projection default
//             pattern when the protocol's associatedtype represents
//             something OTHER than a Self projection. In Memory.Contiguous's
//             case, the associatedtype Element is an *attribute of the
//             conformer* (what it stores), not a projection of the
//             conformer itself. A default `Element = Memory.Contiguous<Self>.Element`
//             is nonsensical because Element is orthogonal to Self.
// Result: DOES NOT FIT — the pattern's structural preconditions are
//         met, but the semantic precondition (associatedtype = projection
//         of Self) is not. This is the most important negative finding:
//         the pattern is defined by the *role* of the associatedtype,
//         not by namespace shape.
// ============================================================================

public enum V5_Memory {}

extension V5_Memory {
    // Generic struct — but Element is what's *contained*, not what's
    // *projected from Self.*
    public struct Contiguous<Element: ~Copyable>: ~Copyable {
        @usableFromInline let count: Int
        @inlinable init(count: Int) { self.count = count }
    }
}

// Protocol with an associatedtype — but the role is CONTAINMENT, not
// PROJECTION.
public protocol __V5_ContiguousProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    var count: Int { get }
}

extension V5_Memory.Contiguous {
    public typealias `Protocol` = __V5_ContiguousProtocol
}

// A conformer must supply Element — there is no meaningful default.
// An attempted "self-projection" default would have to read Element
// as "what Self contains when projected through Memory.Contiguous."
// But Self is the CONTAINER; Element is WHAT it contains. There is
// no natural resolution — "Self contains Self" only makes sense for
// self-referential types like trees, not for containers.
public struct V5_Buffer: ~Copyable {
    public let count: Int
    public init(count: Int) { self.count = count }
}

extension V5_Buffer: __V5_ContiguousProtocol {
    // Conformer MUST supply Element — no default applies.
    public typealias Element = UInt8
}

// Verdict: Namespace shape {N, N<T>, N.`Protocol`} is a STRUCTURAL
// lookalike but not a SEMANTIC fit for the self-projection default
// pattern when the protocol's associatedtype is an attribute of the
// conformer (element-containment) rather than a projection of Self.
// The meta-pattern's defining precondition is the *role* of the
// associatedtype, not the namespace's structural layout.

// ============================================================================
// MARK: - Main
// ============================================================================

@main
struct Main {
    static func main() {
        // Per-variant classification, printed at runtime so `swift run`
        // produces a human-readable evidence record.
        print("V0 Borrow baseline:                   CONFIRMED (FITS)")
        print("V1 Mutate mirror:                     CONFIRMED (FITS)")
        print("V2 Property two-param:                REFUTED (DOES NOT FIT)")
        print("V3 constraint-compat failure:         REFUTED (diagnostic)")
        print("V4 Hash degenerate:                   CONFIRMED (DEGENERATE)")
        print("V5 Memory.Contiguous structural:      REFUTED (DOES NOT FIT)")

        // Compile-time probes already established by typealias resolution:
        print("")
        print("Compile-time probes:")
        print("  V0_Ordinal.Borrowed      = \(String(reflecting: V0_Ordinal.Borrowed.self))")
        print("  V1_Token.Mutated         = \(String(reflecting: V1_Token.Mutated.self))")
        print("  V2a_Container.Projection = \(String(reflecting: V2_Container.Projection.self))")
        print("  V2b_ContainerB.Projection= \(String(reflecting: V2_ContainerB.Projection.self))")
        print("  V4_Token.HashResult      = \(String(reflecting: V4_Token.HashResult.self))")
    }
}
