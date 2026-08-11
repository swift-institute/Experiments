// Experiment: Tagged is not Strideable by default. Empirically classify.
//
// Demonstrates the principled absence rationale documented in
// `Research/principled-absence-strideable.md`.
//
// (a) ABSENCE PROOF (compile-time): without the conformance below,
//     `tagged.distance(to: other)` is unavailable; `for i in a...b`
//     where a/b are Tagged values does not compile.
//
// (b) AUTHORABILITY TEST (Option B — SLI opt-in): does the conformance
//     compile when shaped as a consumer-side extension? Strideable's
//     requirements are function-style (`distance(to:)`, `advanced(by:)`)
//     rather than stored-property-style — so the structural ~Escapable
//     blocker that hit RawRepresentable may or may not fire here.
//
// (c) PER-DOMAIN ALTERNATIVE (Option C): even if Option B compiles,
//     demonstrate the per-domain Strideable conformance pattern that
//     Index types use (per swift-index-primitives precedent).
//
// Verified: Swift 6.3.1 (Apple Swift on macOS) — 2026-04-30.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration

// MARK: - Domain setup

enum User {}
extension User { typealias ID = Tagged<User, Int> }

// MARK: - Option B authorability test
//
// Attempt the SLI-style opt-in conformance.

extension Tagged: @retroactive Strideable
where Tag: ~Copyable & ~Escapable,
      Underlying: Strideable & Comparable & Equatable & Carrier.`Protocol` & Escapable,
      Underlying.Underlying == Underlying {
    public func distance(to other: Tagged) -> Underlying.Stride {
        underlying.distance(to: other.underlying)
    }
    public func advanced(by n: Underlying.Stride) -> Tagged {
        Tagged(underlying.advanced(by: n))
    }
}

// If we reach this point at runtime, the conformance compiled.
// Demonstrate the consequences:

let userA: User.ID = User.ID(1)
let userB: User.ID = User.ID(5)

let dist = userA.distance(to: userB)
precondition(dist == 4, "distance(to:) forwards correctly to Int.distance")

let userC = userA.advanced(by: 10)
precondition(userC.underlying == 11, "advanced(by:) forwards correctly to Int.advanced")

// Range works — this is the consequence the rationale critiques. Same-domain
// range is well-typed, but the iteration is just Int-stride wearing User
// clothing.

var collected: [Int] = []
for u in userA...userB {
    collected.append(u.underlying)
}
precondition(collected == [1, 2, 3, 4, 5], "Range<User.ID> iteration via Strideable")

print("tagged-no-strideable: Option B (SLI-style opt-in) COMPILES — Strideable witnesses are function-style (no stored-property ~Escapable blocker).")
print("tagged-no-strideable: Same-domain range iteration works (\(collected)) — but the stride semantics are Int's, not User's.")

// MARK: - Cross-domain protection (phantom-typing earns its keep)
//
// Even with the blanket conformance, cross-domain ranges DO NOT compile —
// the phantom Tag protects against the most dangerous misuse.

enum Order {}
extension Order { typealias ID = Tagged<Order, Int> }

// _ = userA ... Order.ID(5)
//
// would fail with: "Binary operator '...' cannot be applied to operands
// of type 'User.ID' (= Tagged<User, Int>) and 'Order.ID'
// (= Tagged<Order, Int>)"

print("tagged-no-strideable: cross-domain ranges DO NOT compile (phantom Tag protects).")

// MARK: - Per-domain alternative (Option C)
//
// The "domain owns the stride semantics" pattern — a wrapper struct that
// authors its own Strideable conformance with domain-correct semantics.
// (For Index<Element>, the swift-index-primitives package does this with
// `Index: Strideable where Tag: ~Copyable`.)

struct Slot: Strideable, Comparable, Hashable {
    private static let validIDs: [Int] = [1, 3, 7, 12, 25]
    let storage: Int

    init?(_ underlying: Int) {
        guard Slot.validIDs.contains(underlying) else { return nil }
        self.storage = underlying
    }

    static func < (lhs: Slot, rhs: Slot) -> Bool { lhs.storage < rhs.storage }

    func distance(to other: Slot) -> Int {
        // Domain stride: distance is "number of valid IDs between" — NOT raw int diff.
        let myIdx = Slot.validIDs.firstIndex(of: storage)!
        let otherIdx = Slot.validIDs.firstIndex(of: other.storage)!
        return otherIdx - myIdx
    }

    func advanced(by n: Int) -> Slot {
        let myIdx = Slot.validIDs.firstIndex(of: storage)!
        let newIdx = myIdx + n
        guard newIdx >= 0, newIdx < Slot.validIDs.count else {
            // Out-of-bounds; in production code this would error or wrap.
            // For demonstration, clamp to bounds.
            return Slot(Slot.validIDs[max(0, min(newIdx, Slot.validIDs.count - 1))])!
        }
        return Slot(Slot.validIDs[newIdx])!
    }
}

let sparseA = Slot(1)!
let sparseB = Slot(7)!

precondition(sparseA.distance(to: sparseB) == 2, "domain stride: 1→7 covers two valid IDs (3, 7)")

let sparseC = sparseA.advanced(by: 3)
precondition(sparseC.storage == 12, "advanced(by: 3) from 1 lands on 12 (the third valid ID after 1)")

print("tagged-no-strideable: Per-domain Strideable (Slot) advances by VALID-ID positions, not raw-Int stride. Domain owns the semantics.")
