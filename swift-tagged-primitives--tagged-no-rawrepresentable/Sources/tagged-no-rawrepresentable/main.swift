// Experiment: Tagged is not RawRepresentable, and the absence is STRUCTURAL.
//
// Demonstrates the principled absence rationale documented in
// `Research/principled-absence-rawrepresentable.md`.
//
// (a) STRUCTURAL ABSENCE PROOF (compile-time): the file
//     `reject-test-conformance.swift.txt` documents the conformance
//     attempt that fails to compile, including its diagnostic. Even with
//     constraints attempting to scope the conformance to the
//     fully-Copyable-and-Escapable cell, Tagged's `~Escapable` structural
//     declaration propagates through the synthesized `underlying` getter
//     witness — `RawRepresentable` is not ~Escapable-aware, so the
//     conformance is not authorable in any constraint shape.
//
// (b) CONSUMER ALTERNATIVE (runtime): this main demonstrates the
//     correct consumer pattern — a domain-specific struct that wraps
//     Tagged and conforms to RawRepresentable on its own terms.
//     Domain types provide their own validated `init?(underlying:)`,
//     forwarding to `Tagged.init(__unchecked:)` after validation.
//
// Verified: Swift 6.3.1 (Apple Swift on macOS) — 2026-04-30.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration

// MARK: - Domain setup

enum User {}

// MARK: - Consumer alternative — domain-specific wrapper

/// Consumer-defined domain type that wraps `Tagged<User, Int>` and
/// conforms to `RawRepresentable`. Validation lives here, not in Tagged.
struct UserID: RawRepresentable, Equatable {
    private let storage: Tagged<User, Int>

    init?(rawValue: Int) {
        // Domain validation (consumer's responsibility): non-negative IDs only.
        guard rawValue >= 0 else { return nil }
        self.storage = Tagged<User, Int>(rawValue)
    }

    var rawValue: Int { storage.underlying }
}

// MARK: - Round-trip demonstration

guard let validUser = UserID(rawValue: 42) else {
    fatalError("UserID(rawValue: 42) returned nil — domain validation rejected a valid value")
}
precondition(validUser.rawValue == 42, "round-trip via init?(underlying:) preserves value")

guard let zeroUser = UserID(rawValue: 0) else {
    fatalError("UserID(rawValue: 0) returned nil — domain validation rejected boundary case")
}
precondition(zeroUser.rawValue == 0, "boundary value round-trips")

// Domain validation rejects negative IDs — this is the correct semantics
// for a failable RawRepresentable init, contrasting with the always-succeeds
// init?(underlying:) that an unconditional Tagged: RawRepresentable would
// produce.
let invalidUser = UserID(rawValue: -1)
precondition(invalidUser == nil, "domain validation rejects negative IDs")

print("tagged-no-rawrepresentable: consumer wrapper UserID round-trips through RawRepresentable; domain validation works")

// MARK: - Stdlib interop demonstration

// Once the consumer has a RawRepresentable-conforming wrapper, stdlib APIs
// constrained on RawRepresentable are available.

func describe<T: RawRepresentable>(_ value: T) -> String {
    "raw=\(value.rawValue)"
}

precondition(describe(validUser) == "raw=42", "stdlib RawRepresentable interop works on the consumer wrapper")

print("tagged-no-rawrepresentable: stdlib RawRepresentable interop available via UserID wrapper")

// MARK: - Empirical finding

print("""

Finding: Tagged itself cannot conform to RawRepresentable. Even with
constraint shapes attempting to scope the conformance to the
fully-Copyable-and-Escapable cell, Tagged's structural ~Escapable
declaration propagates through the synthesized underlying getter witness.
The compiler diagnostic is reproduced in reject-test-conformance.swift.txt.

Consequence: RawRepresentable is a HARD absence — not eligible for SLI
opt-in. The consumer path is a domain-specific wrapper struct, which
also gets to enforce domain validation (here: non-negative IDs).
""")
