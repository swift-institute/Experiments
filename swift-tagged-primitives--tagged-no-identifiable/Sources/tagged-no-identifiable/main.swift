// Experiment: Tagged is not Identifiable by default. Empirically classify.
//
// Demonstrates the principled absence rationale documented in
// `Research/principled-absence-identifiable.md`.
//
// (a) SLI SHIPS THE CONFORMANCE: importing
//     `Tagged_Primitives_Standard_Library_Integration` provides
//     `Tagged: Identifiable` parametrically.
//
// (b) IDENTITY-INVERSION DEMONSTRATION: with the SLI conformance
//     active, show that Identifiable-driven code observes Underlying.id,
//     NOT the phantom-typed identity that Tagged was supposed to carry.
//     Two Tagged values with different Tags but the same Underlying.id
//     are "the same" to Identifiable consumers.
//
// (c) PER-DOMAIN ALTERNATIVE (Option C): demonstrate the recommended
//     pattern — a domain type whose `id` IS the Tagged value, preserving
//     phantom-typed identity.
//
// Verified: Swift 6.3.1 (Apple Swift on macOS) — 2026-04-30.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration
import Tagged_Primitives_Standard_Library_Integration

// MARK: - Domain setup

enum User {}
enum Order {}

extension User  { typealias ID = Tagged<User,  UInt64> }
extension Order { typealias ID = Tagged<Order, UInt64> }

// MARK: - Identifiable Underlying setup
//
// Make a domain Underlying that has a `.id` of its own (a UUID-like
// struct that itself conforms to Identifiable).

struct DomainKey: Identifiable, Hashable, Equatable, Sendable, Carrier.`Protocol` {
    let id: UInt64
    typealias Underlying = Self
}

// MARK: - SLI-shipped conformance verification
//
// `Tagged: Identifiable` ships in
// `Sources/Tagged Primitives Standard Library Integration/Tagged+Identifiable.swift`.
// Importing SLI (above) brings the conformance into scope.

let userKey = DomainKey(id: 42)
let userTagged: Tagged<User, DomainKey> = Tagged<User, DomainKey>(userKey)

precondition(userTagged.id == 42, "Tagged.id forwards to underlying.id correctly")

print("tagged-no-identifiable: SLI-shipped Tagged: Identifiable conformance works — userTagged.id == 42 forwards to underlying.id.")

// MARK: - Identity-inversion demonstration
//
// Two Tagged values with different Tags but the same Underlying.id are
// "the same" to Identifiable consumers. This is the cost the rationale
// critiques.

let orderTagged: Tagged<Order, DomainKey> = Tagged<Order, DomainKey>(userKey)

// Both have the same Identifiable.id even though they're entirely different
// phantom-typed types. Generic Identifiable code can't distinguish them.

func describeIdentity<T: Identifiable>(_ value: T) -> String where T.ID == UInt64 {
    "id=\(value.id)"
}

let userDescription  = describeIdentity(userTagged)
let orderDescription = describeIdentity(orderTagged)

precondition(userDescription == orderDescription,
             "Identity-inversion: phantom-Tag-distinct values have the SAME Identifiable.id")

print("tagged-no-identifiable: identity-inversion confirmed. User.ID and Order.ID with same DomainKey have id=\(userTagged.id) — phantom Tag invisible to Identifiable.")

// MARK: - Per-domain alternative (Option C)
//
// The "domain type IS Identifiable, with Tagged as its id" pattern.
// This preserves the phantom-typed identity at the Identifiable layer.
// Domain structs nest under the User / Order namespaces.

extension User {
    struct Profile: Identifiable {
        let id: User.ID         // Tagged<User, UInt64> acts as Identifiable.ID
        let name: String
    }
}

extension Order {
    struct Receipt: Identifiable {
        let id: Order.ID        // Tagged<Order, UInt64> acts as Identifiable.ID
        let total: Int
    }
}

let alice = User.Profile(id: User.ID(1), name: "Alice")
let bob   = User.Profile(id: User.ID(2), name: "Bob")
let purchase = Order.Receipt(id: Order.ID(1), total: 100)

// Now Identifiable.ID type itself differs between User.Profile and Order.Receipt
// — generic code constrained on Identifiable observes the *Tagged* type as the
// id, preserving phantom-typed discrimination at the protocol layer.

precondition(User.Profile.ID.self == User.ID.self,
             "User.Profile.Identifiable.ID resolves to User.ID (Tagged<User, UInt64>)")
precondition(Order.Receipt.ID.self == Order.ID.self,
             "Order.Receipt.Identifiable.ID resolves to Order.ID (Tagged<Order, UInt64>)")
precondition(User.Profile.ID.self != Order.Receipt.ID.self,
             "User.Profile.ID ≠ Order.Receipt.ID at the type level — phantom identity preserved")

_ = (alice, bob, purchase)  // suppress unused-warning

print("tagged-no-identifiable: per-domain pattern (Option C) preserves phantom-typed identity. User.Profile.Identifiable.ID is User.ID = Tagged<User, UInt64>; Order.Receipt.Identifiable.ID is Order.ID = Tagged<Order, UInt64>; the two are distinct types.")

// Final summary

print("""

Empirical findings:
- Option B authorable: YES (computed-forward witness, no ~Escapable blocker)
- Identity-inversion cost: REAL (different phantom Tags collapse to same id at Identifiable layer)
- Option C: preferred — Tagged itself as id preserves phantom-typed identity

Classification: SOFT absence. SLI opt-in is structurally fine; the cost is
semantic (identity-inversion). Consumers integrating with external Identifiable-
keyed APIs can take SLI; consumers authoring their own domain types should
prefer Option C (Tagged as the id, not as a thing-with-id).
""")
