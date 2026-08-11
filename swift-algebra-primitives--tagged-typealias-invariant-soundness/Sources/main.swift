// MARK: - Tagged Typealias Invariant Soundness
// Purpose: Determine whether Algebra.Z.Modulo can safely be a Tagged typealias
//          by testing whether Tagged's construction surface allows invariant bypass.
//
// Hypothesis: Tagged's public init(__unchecked:) and mutable rawValue make it
//             impossible to enforce [0,n) invariants on a typealias. If confirmed,
//             Modulo must remain a wrapper struct.
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT
// Status: SUPERSEDED 2026-04-30 — Finite.Capacity protocol surface changed; experiment's witness model no longer conforms
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: macOS (arm64)
//
// Result: CONFIRMED — All 7 bypass vectors confirmed. Tagged typealias is unsound for Modulo.
//         V1: init(__unchecked:) creates out-of-range values (999 for bound 5)
//         V2: rawValue mutation overwrites to 999
//         V3: Modulo<0> constructible (should be uninhabitable)
//         V4: Finite.Enumerable auto-conformance works (positive finding)
//         V5: Nested Error type accessible through typealias (positive finding)
//         V6: Checked init cannot prevent bypass via init(__unchecked:) or rawValue mutation
//         V7: Invalid inputs (999) propagate through arithmetic → result 997, outside [0,5)
// Date: 2026-02-04

import Tagged_Primitives
import Ordinal_Primitives
import Finite_Primitives

// ============================================================================
// MARK: - Variant 1: Can Tagged be constructed with arbitrary rawValue?
// Hypothesis: Tagged's init(__unchecked:Void, _:) is public and allows any value.
// Result: CONFIRMED — Created Tagged<Finite.Bound<5>, Ordinal> with rawValue 999
// ============================================================================

func variant1_directConstruction() {
    print("=== Variant 1: Direct construction bypass ===")

    // Attempt to create a Tagged<Finite.Bound<5>, Ordinal> with value 999
    // (out of bounds for a "bounded" ordinal)
    let invalid: Tagged<Finite.Bound<5>, Ordinal> = Tagged(__unchecked: (), Ordinal(999))
    print("Created Tagged<Finite.Bound<5>, Ordinal> with value 999: \(invalid.rawValue)")
    print("Valid range should be [0, 5), but value is: \(invalid.rawValue.rawValue)")
    print("RESULT: init(__unchecked:) IS public — invariant bypass confirmed")
    print()
}

// ============================================================================
// MARK: - Variant 2: Can rawValue be mutated?
// Hypothesis: Tagged's rawValue has _modify accessor, allowing mutation.
// Result: CONFIRMED — rawValue mutated from 2 to 999
// ============================================================================

func variant2_rawValueMutation() {
    print("=== Variant 2: rawValue mutation ===")

    var bounded: Tagged<Finite.Bound<5>, Ordinal> = Tagged(__unchecked: (), Ordinal(2))
    print("Initial value: \(bounded.rawValue.rawValue)")

    bounded.rawValue = Ordinal(999)
    print("After mutation: \(bounded.rawValue.rawValue)")
    print("RESULT: rawValue IS mutable — invariant bypass confirmed")
    print()
}

// ============================================================================
// MARK: - Variant 3: Can Modulo<0> be constructed via Tagged?
// Hypothesis: If Modulo were a typealias, Tagged construction allows Modulo<0>.
// Result: CONFIRMED — SimulatedModulo<0> created with Tag.capacity == 0
// ============================================================================

// Simulate the proposed Modulo design
enum SimulatedResidue<let n: Int>: Finite.Capacity, Hashable, Sendable {
    static var capacity: Int { n }
}

typealias SimulatedModulo<let n: Int> = Tagged<SimulatedResidue<n>, Ordinal>

func variant3_zeroModulusConstruction() {
    print("=== Variant 3: Zero-modulus construction ===")

    // This SHOULD be impossible, but can we create Modulo<0>?
    let illegal: SimulatedModulo<0> = Tagged(__unchecked: (), Ordinal(0))
    print("Created SimulatedModulo<0> with value: \(illegal.rawValue.rawValue)")
    print("Tag.capacity = \(SimulatedResidue<0>.capacity)")
    print("RESULT: Modulo<0> IS constructible via Tagged — invariant bypass confirmed")
    print()
}

// ============================================================================
// MARK: - Variant 4: Does Finite.Enumerable auto-conform?
// Hypothesis: Tagged<SimulatedResidue<5>, Ordinal> gets Finite.Enumerable
//             from the existing extension because SimulatedResidue: Finite.Capacity.
// Result: CONFIRMED — count=5, allCases enumerates [0,1,2,3,4]
// ============================================================================

func variant4_finiteEnumerable() {
    print("=== Variant 4: Finite.Enumerable auto-conformance ===")

    // SimulatedModulo<5> should be Finite.Enumerable because:
    // - Tag (SimulatedResidue<5>) conforms to Finite.Capacity
    // - RawValue is Ordinal
    let count = SimulatedModulo<5>.count
    print("SimulatedModulo<5>.count = \(count)")

    let all = Array(SimulatedModulo<5>.allCases)
    print("allCases count: \(all.count)")
    for element in all {
        print("  ordinal \(element.ordinal.rawValue)")
    }
    print("RESULT: Finite.Enumerable auto-conformance works")
    print()
}

// ============================================================================
// MARK: - Variant 5: Error type in protocol-constrained extension
// Hypothesis: A nested enum Error can be defined in
//             extension Tagged where Tag: SomeProtocol, RawValue == Ordinal
//             and accessed as TypeAlias.Error.
// Result: CONFIRMED — SimulatedModulo<5>.ModuloError and SimulatedModulo<0>.ModuloError both accessible
// ============================================================================

protocol SimulatedResidual: Finite.Capacity, Sendable {}
extension SimulatedResidue: SimulatedResidual {}

extension Tagged where Tag: SimulatedResidual, RawValue == Ordinal {
    enum ModuloError: Swift.Error, Sendable, Equatable {
        case modulus
        case bounds(Int)
    }
}

func variant5_nestedErrorType() {
    print("=== Variant 5: Error type in protocol-constrained extension ===")

    // Can we access the Error type through the typealias?
    let err: SimulatedModulo<5>.ModuloError = .bounds(42)
    print("Created SimulatedModulo<5>.ModuloError.bounds(42): \(err)")

    let err0: SimulatedModulo<0>.ModuloError = .modulus
    print("Created SimulatedModulo<0>.ModuloError.modulus: \(err0)")
    print("RESULT: Nested error type accessible through typealias")
    print()
}

// ============================================================================
// MARK: - Variant 6: Checked init on protocol-constrained extension
// Hypothesis: A throwing init can be added to Tagged via protocol constraint,
//             but it does NOT prevent callers from using init(__unchecked:).
// Result: CONFIRMED — Checked init works but init(__unchecked:) and rawValue mutation remain open
// ============================================================================

extension Tagged where Tag: SimulatedResidual, RawValue == Ordinal {
    init(checked residue: Int) throws(ModuloError) {
        let n = Tag.capacity
        guard n > 0 else { throw .modulus }
        guard residue >= 0, residue < n else { throw .bounds(residue) }
        self.init(__unchecked: (), Ordinal(UInt(residue)))
    }
}

func variant6_checkedInitBypass() {
    print("=== Variant 6: Checked init does not prevent bypass ===")

    // The checked init works correctly
    do {
        let valid = try SimulatedModulo<5>(checked: 3)
        print("Checked init(3): ordinal = \(valid.rawValue.rawValue)")
    } catch {
        print("Unexpected error: \(error)")
    }

    // But the unchecked path is still open
    let bypassed: SimulatedModulo<5> = Tagged(__unchecked: (), Ordinal(999))
    print("Bypassed via init(__unchecked:): ordinal = \(bypassed.rawValue.rawValue)")

    // And mutation is still open
    var mutable = try! SimulatedModulo<5>(checked: 2)
    mutable.rawValue = Ordinal(888)
    print("After rawValue mutation: ordinal = \(mutable.rawValue.rawValue)")
    print("RESULT: Checked inits cannot prevent bypass — Tagged is inherently open")
    print()
}

// ============================================================================
// MARK: - Variant 7: Arithmetic on invalid values
// Hypothesis: If an invalid value is constructed, arithmetic produces nonsense.
// Result: CONFIRMED — modularAdd(3, 999) mod 5 = 997, outside [0,5)
// ============================================================================

extension Tagged where Tag: SimulatedResidual, RawValue == Ordinal {
    static func modularAdd(_ lhs: Self, _ rhs: Self) -> Self {
        let a = lhs.rawValue.rawValue
        let b = rhs.rawValue.rawValue
        let m = UInt(Tag.capacity)
        let sum = a + b
        return Self(__unchecked: (), Ordinal(sum >= m ? sum - m : sum))
    }
}

func variant7_arithmeticOnInvalidValues() {
    print("=== Variant 7: Arithmetic on invalid values ===")

    let valid: SimulatedModulo<5> = Tagged(__unchecked: (), Ordinal(3))
    let invalid: SimulatedModulo<5> = Tagged(__unchecked: (), Ordinal(999))

    let result = SimulatedModulo<5>.modularAdd(valid, invalid)
    print("modularAdd(3, 999) mod 5 = \(result.rawValue.rawValue)")
    print("Expected: 2 (if treating 999 as valid)")
    print("Actual ordinal > 5, invariant violated in result: \(result.rawValue.rawValue >= 5)")
    print("RESULT: Invalid inputs produce values outside [0,n)")
    print()
}

// ============================================================================
// MARK: - Execute All Variants
// ============================================================================

variant1_directConstruction()
variant2_rawValueMutation()
variant3_zeroModulusConstruction()
variant4_finiteEnumerable()
variant5_nestedErrorType()
variant6_checkedInitBypass()
variant7_arithmeticOnInvalidValues()

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("=== RESULTS SUMMARY ===")
print("V1 (Direct construction):      Tagged init(__unchecked:) is public")
print("V2 (rawValue mutation):         rawValue is mutable via _modify")
print("V3 (Zero modulus):              Modulo<0> is constructible")
print("V4 (Finite.Enumerable):         Auto-conformance works")
print("V5 (Nested Error type):         Accessible through typealias")
print("V6 (Checked init bypass):       Cannot prevent raw construction")
print("V7 (Invalid arithmetic):        Broken values propagate")
print()
print("CONCLUSION: Tagged typealias is UNSOUND for Modulo.")
print("The typealias cannot enforce the [0,n) representation invariant")
print("because Tagged's public construction surface is wide open.")
print()
print("RECOMMENDATION: Keep struct Modulo<n> as wrapper.")
print("Use Residue<n> tag + Residual protocol for scoping extensions,")
print("but store the representation internally (Ordinal, not Tagged).")
