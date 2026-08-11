// MARK: - generic-throws-init driver — exercises the six variants cross-module
//
// Purpose: Cross-module driver per [EXP-017] — imports `Definitions` and
//          calls each variant's init shape. The fact that this target builds
//          and runs is half the evidence; the build output is the other half.
//
// Toolchain: swift-6.3
// Platform:  macOS 26 (arm64)
// Date:      2026-05-01
// Status:    PARTIAL — see Definitions.swift for the full hypothesis matrix
// Result:    All call sites that compile produce expected runtime output;
//            the V2-no-validate call site does not compile (H2 REFUTED;
//            documented in MARK comments below).

import Tagged_Primitives
import Carrier_Primitives
import Definitions

// MARK: - V1 — Baseline non-throwing init

let v1: Tagged<V1User, UInt64> = .init(42)
print("V1 baseline:", v1.underlying)

// MARK: - V2 — Generic-throws, no validation closure (REFUTED: E inference fails)

// The following call site does NOT compile:
//
//     let v2NoValidate: Tagged<V2User, UInt64> = .init(42)
//
// Diagnostic: "generic parameter 'E' could not be inferred"
//
// The default `{ _ in }` closure is consistent with any `E: Error` and
// does not pin `E = Never`. Result-type context fixes Tag and Underlying
// but provides no constraint on E. Swift's inference declines to default
// E to Never on its own. The "throws(E) where E == Never ≡ non-throwing"
// equivalence holds AFTER E is fixed — but inference doesn't fix it from
// a parameter-agnostic default. ⇒ H2 REFUTED.

// MARK: - V2 — Generic-throws, success path with validating closure (CONFIRMED)

do {
    let v2Valid: Tagged<V2User, UInt64> = try .init(42) { v throws(V2Error) in
        guard v > 0 else { throw V2Error.notPositive }
    }
    print("V2 with-validate (success):", v2Valid.underlying)
} catch {
    print("V2 with-validate (unexpected error):", error)
}

// MARK: - V2 — Generic-throws, error path with validating closure

do {
    let v2Invalid: Tagged<V2User, UInt64> = try .init(0) { v throws(V2Error) in
        guard v > 0 else { throw V2Error.notPositive }
    }
    print("V2 with-validate (unexpected success):", v2Invalid.underlying)
} catch {
    print("V2 with-validate (expected error):", error)
}

// MARK: - V3 — Coexistence: V1-form and V2-form inits on the same Tag

let v3Plain: Tagged<V3User, UInt64> = .init(99)
print("V3 plain (V1-form resolves):", v3Plain.underlying)

do {
    let v3Validated: Tagged<V3User, UInt64> = try .init(99) { v throws(V2Error) in
        guard v > 0 else { throw V2Error.notPositive }
    }
    print("V3 validated (V2-form resolves):", v3Validated.underlying)
} catch {
    print("V3 validated (unexpected error):", error)
}

// MARK: - V4 — Carrier-mirroring protocol with generic-throws init requirement

let v4Source = V4Cardinal(7)

do {
    let v4: V4Cardinal = try .init(v4Source) { v throws(V2Error) in
        guard v.underlying > 0 else { throw V2Error.notPositive }
    }
    print("V4 GenericThrowsCarrier conformer (success):", v4.underlying)
} catch {
    print("V4 GenericThrowsCarrier conformer (unexpected error):", error)
}

// MARK: - V5 — Default generic-throws init on real Carrier (zero-migration path)

// V4Cardinal's struct doesn't conform to real Carrier; we test V5 against
// a real Carrier conformer. V4Cardinal already has a non-throwing convenience
// init `V4Cardinal(_ raw: UInt64)` and conforms to GenericThrowsCarrier
// (the parallel protocol). For V5 we need a type conforming to real Carrier.
// Add a minimal conformer here.

struct V5Cardinal: Carrier {
    typealias Underlying = V5Cardinal
    private var _storage: UInt64
    init(_ raw: UInt64) { self._storage = raw }
    var underlying: V5Cardinal { _read { yield self } }
    init(_ underlying: consuming V5Cardinal) {
        self._storage = underlying._storage
    }
    var underlying: UInt64 { _storage }
}

let v5Source = V5Cardinal(11)

do {
    // The throws init comes from the V5 default extension on Carrier in
    // Definitions.swift — V5Cardinal didn't declare it; it's inherited
    // for free via the Carrier conformance. Zero migration cost.
    let v5: V5Cardinal = try .init(v5Source) { v throws(V2Error) in
        guard v.underlying > 0 else { throw V2Error.notPositive }
    }
    print("V5 default-extension on Carrier (success):", v5.underlying)
} catch {
    print("V5 default-extension on Carrier (unexpected error):", error)
}

do {
    let v5Invalid: V5Cardinal = try .init(V5Cardinal(0)) { v throws(V2Error) in
        guard v.underlying > 0 else { throw V2Error.notPositive }
    }
    print("V5 default-extension on Carrier (unexpected success):", v5Invalid.underlying)
} catch {
    print("V5 default-extension on Carrier (expected error):", error)
}

// MARK: - V6 — Protocol requirement + default extension implementation

let v6Source = V6Cardinal(13)

// V6Cardinal omits the generic-throws init implementation in the conformer;
// the protocol's default extension implementation provides it. The fact that
// this call site compiles and runs IS the evidence — V6Cardinal satisfies
// the requirement via the default.
do {
    let v6: V6Cardinal = try .init(v6Source) { v throws(V2Error) in
        guard v.underlying > 0 else { throw V2Error.notPositive }
    }
    print("V6 protocol-requirement + default impl (success):", v6.underlying)
} catch {
    print("V6 protocol-requirement + default impl (unexpected error):", error)
}

print("done.")
