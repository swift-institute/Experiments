// Experiment: Tagged is not LosslessStringConvertible by default. Empirically classify.
//
// Demonstrates the principled absence rationale documented in
// `Research/principled-absence-losslessstringconvertible.md`.
//
// (a) AUTHORABILITY TEST (Option B — SLI-style opt-in): `init?(_ description:)`
//     is function-style; `description` requirement is satisfied by Tagged's
//     existing CustomStringConvertible conformance. Both should be authorable.
//
// (b) LOSSY-ROUNDTRIP DEMONSTRATION: even with the conformance, two Tagged
//     values with the same Underlying but different phantom Tags produce
//     IDENTICAL descriptions. The "lossless" claim holds within a single Tag
//     (`T(v.description) == v` for the SAME T) but the description content
//     does not encode the Tag — a String received without context cannot be
//     reconstituted to the correct Tagged type.
//
// (c) PER-DOMAIN ALTERNATIVE (Option C): a wrapper struct that owns
//     LosslessStringConvertible — the round-trip is genuinely lossless
//     within the domain because the wrapper IS a single tag.
//
// Verified: Swift 6.3.1 (Apple Swift on macOS) — 2026-04-30.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration
import Tagged_Primitives_Standard_Library_Integration

// MARK: - Domain setup

enum User {}
enum Order {}

extension User  { typealias ID = Tagged<User,  Int> }
extension Order { typealias ID = Tagged<Order, Int> }

// MARK: - SLI-shipped conformance verification
//
// `Tagged: LosslessStringConvertible` ships in
// `Sources/Tagged Primitives Standard Library Integration/Tagged+LosslessStringConvertible.swift`.
// Importing SLI brings the conformance into scope; the `description`
// property is satisfied by the main-target `CustomStringConvertible`
// conformance via cross-module witness inheritance.

guard let userFromString: User.ID = User.ID(String("42")) else {
    fatalError("init?(_:) returned nil for valid Int string")
}
precondition(userFromString.underlying == 42, "init?(_:) parses correctly")
precondition(userFromString.description == "42", "description property forwards to underlying's description")

print("tagged-no-losslessstringconvertible: SLI-shipped Tagged: LosslessStringConvertible works — both init?(_:) and description.")
print("   Note: passing the literal String('42') wrapped in String(...) is the documented disambiguation when Tagged: ExpressibleByStringLiteral is also in SLI scope.")

// MARK: - Within-domain roundtrip (the protocol's contract holds for Tagged<User, Int>)

let original: User.ID = 99
let serialized = original.description
guard let reconstructed: User.ID = User.ID(serialized) else {
    fatalError("init?(_:) failed on User.ID's own description")
}
precondition(reconstructed == original, "within-domain roundtrip preserves the Tagged value")
print("tagged-no-losslessstringconvertible: within-domain roundtrip works (User.ID(\"99\") == original).")

// MARK: - Lossy-roundtrip demonstration
//
// The description content does NOT encode the phantom Tag. Two Tagged values
// with the same Underlying but different Tags produce identical descriptions.
// A consumer receiving a String via wire/file/IPC has no way to know which
// Tag to instantiate.

let userVal:  User.ID  = 42
let orderVal: Order.ID = 42

precondition(userVal.description == orderVal.description,
             "phantom-Tag-distinct values have IDENTICAL descriptions — Tag is invisible in the string")

// A receiver who has only the string "42" cannot recover whether the original
// was a User.ID or an Order.ID. The picking is determined by the
// receiver's type annotation, not by the string content.

let pickedAsUser: User.ID? = User.ID(serialized)
let pickedAsOrder: Order.ID? = Order.ID(serialized)

precondition(pickedAsUser?.underlying == 99 && pickedAsOrder?.underlying == 99,
             "the string '99' parses to both User.ID(99) and Order.ID(99) — receiver-type determines the Tag, not the string")

print("tagged-no-losslessstringconvertible: lossy-from-Tagged-perspective confirmed. Description '99' can be parsed as User.ID OR Order.ID — Tag information is NOT in the string.")

// MARK: - Per-domain alternative (Option C)

struct Serialized: LosslessStringConvertible, Equatable {
    let storage: Tagged<User, Int>
    init?(_ description: String) {
        guard let raw = Int(description) else { return nil }
        self.storage = Tagged<User, Int>(raw)
    }
    var description: String { String(storage.underlying) }
}

let wrapped = Serialized("100")!
precondition(wrapped.description == "100", "wrapper roundtrip works")
print("tagged-no-losslessstringconvertible: per-domain wrapper Serialized roundtrips losslessly within its single tag.")

// Final summary

print("""

Empirical findings:
- Option B authorable: YES (function-style init? + computed-forward description)
- Within-domain roundtrip: HOLDS (T(v.description) == v for same T)
- Lossy-from-Tagged-perspective: REAL (string content does NOT encode Tag)
- Option C: per-domain wrapper preserves the within-domain lossless guarantee

Classification: SOFT absence. SLI opt-in is structurally fine; the lossy-from-
Tagged-perspective cost is the consumer's accepted trade-off. Consumers
serializing Tagged values across wire/file/IPC should prefer Option C
(per-domain wrapper) to avoid the receiver-type-picks-the-tag confusion.
""")
