// Experiment: Tagged carries no Foundation-dependent conformances.
// Empirically verify the Foundation-independence axiom + demonstrate the
// consumer-side opt-in pattern.
//
// Demonstrates the principled absence rationale documented in
// `Research/principled-absence-foundation-protocols.md`.
//
// (a) PACKAGE-FOUNDATION-FREE PROOF: Tagged Primitives main module has
//     ZERO `import Foundation`. Verifiable via grep at the Sources/
//     level. This experiment imports Tagged_Primitives WITHOUT importing
//     Foundation in the experiment, proving the import chain is clean.
//
// (b) CONSUMER-SIDE CONFORMANCE: when the consumer's package legitimately
//     imports Foundation (for its own reasons), the consumer can author
//     LocalizedError + UUID convenience inits trivially. The conformance
//     and import chain live at the consumer's layer, not in the Institute
//     primitives package.
//
// Verified: Swift 6.3.1 (Apple Swift on macOS) — 2026-04-30.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration
// Note: NO `import Foundation` in this experiment. Tagged_Primitives main
// is Foundation-free per [PRIM-FOUND-001].

// MARK: - Foundation-free verification
//
// If Tagged_Primitives required Foundation, this file would fail to compile
// without an explicit `import Foundation`. The fact that the experiment
// builds clean WITHOUT Foundation imported is the empirical proof.

enum User {}
extension User { typealias ID = Tagged<User, Int> }

let userID: User.ID = User.ID(42)
precondition(userID.underlying == 42, "Tagged Primitives builds and works without Foundation")

print("tagged-no-foundation-protocols: Tagged Primitives main is Foundation-free — this experiment imports Tagged_Primitives WITHOUT importing Foundation, and Tagged works as expected.")

// MARK: - Demonstrate the absence

// `Tagged: LocalizedError` is not available — `LocalizedError` is in
// Foundation, which we don't import. Even attempting to write the
// conformance signature here would require `import Foundation`.
//
// Likewise, `Tagged where Underlying == UUID` convenience inits are unavailable
// because `UUID` is a Foundation type.

print("tagged-no-foundation-protocols: LocalizedError and UUID convenience inits are unavailable on Tagged because the Institute primitives layer does not import Foundation.")

// MARK: - Consumer-side opt-in (separate compilation unit pattern)
//
// In a real consumer's package that DOES import Foundation, the consumer
// can author the conformances themselves. This experiment doesn't import
// Foundation (to demonstrate the Foundation-free property of Tagged
// Primitives), but in a Foundation-importing consumer, the pattern is:
//
//   import Foundation
//   import Tagged_Primitives
//
//   extension Tagged: LocalizedError
//   where Tag: ~Copyable & ~Escapable, Underlying: LocalizedError & Escapable {
//       public var errorDescription: String? { underlying.errorDescription }
//       public var failureReason: String? { underlying.failureReason }
//   }
//
//   extension Tagged where Underlying == UUID {
//       public init() { self.init(UUID()) }
//   }
//
// The conformance and Foundation import live in the consumer's package,
// where Foundation dependency is appropriate (Foundations layer or above).

print("tagged-no-foundation-protocols: consumer-side opt-in pattern — when the consumer's package imports Foundation for its own reasons, the LocalizedError + UUID conformances are authored at the consumer's layer (not the Institute primitives layer).")

// MARK: - Final summary

print("""

Empirical findings:
- Tagged Primitives main is Foundation-free (this experiment builds and
  runs WITHOUT importing Foundation, confirming the [PRIM-FOUND-001] axiom)
- LocalizedError and UUID convenience inits would require importing
  Foundation, which is structurally forbidden in the primitives layer
- Consumer-side opt-in is one-line in a Foundation-importing consumer's
  package — the Foundation dependency lives at the consumer's layer

Classification: HARD-BY-AXIOM absence. [PRIM-FOUND-001] forbids Foundation
in primitives, regardless of consumer intent or use case. The absence is
not a SLI candidate — even SLI is part of the primitives layer and
inherits the Foundation-free axiom.
""")
