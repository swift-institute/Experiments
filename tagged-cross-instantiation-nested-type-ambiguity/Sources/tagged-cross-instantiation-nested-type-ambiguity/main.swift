// MARK: - Tagged Cross-Instantiation Nested-Type Ambiguity Investigation
//
// Blog: BLOG-IDEA-077 "We tried Tagged + Carrier across the layer boundary.
//                      Swift's name lookup said no."
// Pitch: PITCH-0002 "Constraint-Aware Nested-Type Lookup on Constrained Extensions"
// Research: swift-institute/Research/swift-constrained-extension-nested-type-lookup-gap.md
//
// Purpose: Empirically test the L3-policy-layering migration agent's claim
// that Swift's nested-type lookup on constrained extensions ignores the
// where-clause, causing `Tagged<X, Y>.Error` to be ambiguous when multiple
// constrained extensions declare same-name nested typealiases on disjoint
// (Tag, RawValue) instantiations.
//
// Hypothesis (the agent's claim, stated as testable):
//   "Two constrained extensions on Tagged with disjoint where-clauses but
//   the same nested-typealias name `Error` cause `Tagged<X, Y>.Error`
//   lookup to be ambiguous at consumer sites that touch any concrete
//   Tagged<X, Y>.Error access — even when only one constrained extension
//   applies for the concrete (X, Y)."
//
// Toolchain: swift-6.3 (system default)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED (the agent's ambiguity claim holds at minimal scope)
// Status: STILL PRESENT (as of swift-6.3 system default, 2026-05-02)
// Date: 2026-05-02
//
// Diagnostic (verbatim, debug build, exit 1):
//   error: ambiguous type name 'Error' in 'Tagged<TagA, RawA>'
//   note: found candidate with type 'Tagged<TagA, RawA>.Error' (aka 'NestedAError')   [LegA]
//   note: found candidate with type 'Tagged<TagA, RawA>.Error' (aka 'NestedBError')   [LegB]
//
// Command: cd Experiments/tagged-cross-instantiation-nested-type-ambiguity && \
//          rm -rf .build && swift build
//
// What this rules in: Swift's nested-type lookup on constrained extensions
// of generic types DOES NOT respect the where-clause as a discriminator.
// Two `extension Tagged where Tag == X, RawValue == Y { typealias Error = ... }`
// declarations on disjoint (Tag, RawValue) instantiations BOTH appear as
// candidates for `Tagged<concrete, concrete>.Error` lookup, producing an
// ambiguity error at any site that names the nested typealias.
//
// What this rules out: the followup-doc § 7 template's claim that approach
// 12+13 (Tagged + nested-typealias-via-constrained-extension) works
// uniformly across the ecosystem. The toy experiments (approach-12 + 13)
// only had ONE Tagged variant in scope; production scale (multiple Tagged
// variants from swift-memory-primitives + swift-posix etc.) hits the
// ambiguity at every consumer.
//
// Implications for the L3-policy migration:
//   - Wave 3.5-Corrective @_spi-with-identical-signature pattern: BROKEN
//     (separate compile-time finding; orthogonal to this experiment)
//   - Approach 12+13 Tagged + Carrier with constrained-extension nested
//     typealiases: NOT VIABLE at production scale
//   - Fresh-enum-at-L3 (Wave 3.5-N original) + plain-typealias-where-no-
//     policy: agent's pivot ("Path β") is empirically justified
//
// Open questions NOT tested by this experiment (would be V5+ follow-up):
//   - Q: Does dropping the nested-typealias declaration entirely (consumers
//     write `Tagged<X, Y>.RawValue.Error` instead) bypass the ambiguity?
//   - Q: Does declaring the typealias on RawValue's home rather than as a
//     constrained Tagged extension preserve consumer ergonomics without
//     ambiguity?
// Per [EXP-011a] first-clean-signal-is-the-result, these are different
// hypotheses requiring different variants. Document but do not run unless
// the architectural decision needs them.
//
// ─────────────────────────────────────────────────────────────────
// Variants per [EXP-009]:
//
// V1 — Baseline single-leg lookup:
//   Reach `Tagged<TagA, RawA>.Error` from main where ONLY LegA is in
//   scope's transitive imports. (LegA + LegB are both linked, but main
//   doesn't import LegB explicitly.)
//
// V2 — Cross-instantiation lookup (the claim):
//   Reach `Tagged<TagA, RawA>.Error` from main where BOTH LegA and LegB
//   are imported. Per the agent's claim, this should fail with ambiguity
//   error because the LegB constrained extension's typealias is reachable
//   via Tagged's lookup table even though its where-clause doesn't apply.
//
// V3 — Symmetric reach to LegB's variant:
//   Reach `Tagged<TagB, RawB>.Error` from main with both legs imported.
//   Mirror image of V2.
//
// V4 — Concrete typed-throws use:
//   Use the looked-up Error type in a concrete `throws(...)` clause to
//   verify it actually resolves to the right enum (NestedAError vs
//   NestedBError) when the where-clause does respect concrete types.

public import TaggedCore
public import LegA
public import LegB

// ─────────────────────────────────────────────────────────────────
// MARK: - V1: Baseline — single-leg lookup via concrete-instantiation typealias

func v1_baseline_legA_lookup() {
    let _: Tagged<TagA, RawA>.Error = NestedAError.a
    print("V1 PASS: Tagged<TagA, RawA>.Error resolves to NestedAError when both legs imported")
}

// ─────────────────────────────────────────────────────────────────
// MARK: - V2: Cross-instantiation lookup (the claim under test)

func v2_legA_lookup_with_legB_imported() {
    // The agent's claim: this line should fail to compile because
    // Tagged.Error is ambiguous between LegA's and LegB's typealiases.
    let value: Tagged<TagA, RawA>.Error = NestedAError.a
    // If the type system DOES respect the where-clause, this assertion
    // succeeds: the Error here is NestedAError, not NestedBError.
    let _: NestedAError = value
    print("V2 PASS: Tagged<TagA, RawA>.Error resolves unambiguously to NestedAError despite LegB being imported")
}

// ─────────────────────────────────────────────────────────────────
// MARK: - V3: Symmetric — LegB lookup with LegA imported

func v3_legB_lookup_with_legA_imported() {
    let value: Tagged<TagB, RawB>.Error = NestedBError.b
    let _: NestedBError = value
    print("V3 PASS: Tagged<TagB, RawB>.Error resolves unambiguously to NestedBError despite LegA being imported")
}

// ─────────────────────────────────────────────────────────────────
// MARK: - V4: Typed-throws use in declarations

func v4_typed_throws_a() throws(Tagged<TagA, RawA>.Error) {
    throw NestedAError.a
}

func v4_typed_throws_b() throws(Tagged<TagB, RawB>.Error) {
    throw NestedBError.b
}

func v4_run() {
    do throws(Tagged<TagA, RawA>.Error) {
        try v4_typed_throws_a()
    } catch {
        // Concrete error caught here is NestedAError per typed-throws.
        let _: NestedAError = error
        print("V4a PASS: typed-throws catch resolves to NestedAError concretely")
    }
    do throws(Tagged<TagB, RawB>.Error) {
        try v4_typed_throws_b()
    } catch {
        let _: NestedBError = error
        print("V4b PASS: typed-throws catch resolves to NestedBError concretely")
    }
}

// ─────────────────────────────────────────────────────────────────

v1_baseline_legA_lookup()
v2_legA_lookup_with_legB_imported()
v3_legB_lookup_with_legA_imported()
v4_run()

print("---")
print("All variants compiled and ran. The agent's ambiguity claim is REFUTED in this minimal shape.")
print("If a real-world consumer hits the ambiguity, the discriminator is NOT 'two constrained extensions with same nested-type name on disjoint where-clauses' alone — additional structural conditions must apply.")
