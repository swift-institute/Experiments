// Experiment: Tagged is not AdditiveArithmetic / Numeric / Family by default.
// Empirically classify and demonstrate the domain-blind footgun.
//
// Demonstrates the principled absence rationale documented in
// `Research/principled-absence-additivearithmetic-family.md`.
//
// (a) AUTHORABILITY TEST (Option B — SLI-style opt-in): does AdditiveArithmetic
//     compile when shaped as a consumer-side opt-in? Function-style witnesses
//     (`static func +`, `static func -`, `static var zero`) should bypass
//     the ~Escapable blocker.
//
// (b) DOMAIN-BLIND ARITHMETIC FOOTGUN: with the conformance, demonstrate
//     operations the *domain* never authorized — multiplying user IDs,
//     summing them, taking `.zero` for a domain that has no semantic zero,
//     and the literal-conformance compounding effect.
//
// (c) PER-DOMAIN ALTERNATIVE (Option C): a domain that DOES have meaningful
//     arithmetic (Counter — counts add to counts) authors its conformance
//     directly, owning the semantic.
//
// Verified: Swift 6.3.1 (Apple Swift on macOS) — 2026-04-30.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration

// MARK: - Domain setup

enum User {}
extension User { typealias ID = Tagged<User, Int> }

// MARK: - Option B authorability test
//
// Try the SLI-style opt-in for AdditiveArithmetic. Numeric/SignedNumeric
// /BinaryInteger/BinaryFloatingPoint extend AdditiveArithmetic — verifying
// AdditiveArithmetic determines the family's classification.

extension Tagged: @retroactive AdditiveArithmetic
where Tag: ~Copyable & ~Escapable,
      Underlying: AdditiveArithmetic & Carrier.`Protocol` & Escapable,
      Underlying.Underlying == Underlying {
    public static var zero: Tagged { Tagged(.zero) }

    public static func + (lhs: Tagged, rhs: Tagged) -> Tagged {
        Tagged(lhs.underlying + rhs.underlying)
    }

    public static func - (lhs: Tagged, rhs: Tagged) -> Tagged {
        Tagged(lhs.underlying - rhs.underlying)
    }
}

// If we reach this point at runtime, the conformance compiled.

let userA: User.ID = User.ID(7)
let userB: User.ID = User.ID(5)

let userSum = userA + userB
precondition(userSum.underlying == 12, "+ forwards to Int.+ correctly")

let userDiff = userA - userB
precondition(userDiff.underlying == 2, "- forwards to Int.- correctly")

let zero: User.ID = .zero
precondition(zero.underlying == 0, "static var zero produces Tagged(0)")

print("tagged-no-additivearithmetic-family: Option B (SLI-style opt-in) COMPILES — function-style witnesses authorable.")

// MARK: - Domain-blind arithmetic footgun
//
// What does it MEAN to add two user IDs together? Domain-wise, nothing.
// But the conformance happily compiles `userA + userB`, producing another
// User.ID that the type-system happily threads into further code paths.
//
// The wrapper was supposed to make this hard to express. The conformance
// makes it as easy as `Int + Int`.

func processUsers(start: User.ID, count: User.ID) -> User.ID {
    // This is nonsensical domain-wise — but compiles cleanly with the
    // SLI conformance. A real consumer might write this thinking
    // "add 'count' to 'start' to get a new ID range" — but neither
    // operand has anything domain-meaningful happening.
    return start + count
}

let nonsensicalUser = processUsers(start: userA, count: userB)
precondition(nonsensicalUser.underlying == 12, "domain-blind operation 'works' — the wrapper has been silenced")

print("tagged-no-additivearithmetic-family: domain-blind footgun confirmed. processUsers(start:count:) compiles and runs even though adding two UserIDs has no domain meaning.")

// MARK: - Compounding with literal conformances
//
// Once AdditiveArithmetic is on Tagged, the literal-conformance pattern
// from `Tagged Primitives Test Support` reactivates as a footgun.
// Note: literal conformances only ship in Test Support, but the SLI
// opt-in user might also have them imported. Demonstration uses a local
// literal init for clarity.

extension User.ID {
    init(integerLiteral value: Int) {
        self = User.ID(value)
    }
}

// With the literal conformance + AdditiveArithmetic, `userA + 5` compiles
// — the literal `5` resolves to `User.ID(integerLiteral: 5)` and `+`
// forwards to Int.+. The user is now doing raw-Int arithmetic on what
// they thought was a domain-typed value.

let arithmeticUser = userA + User.ID(integerLiteral: 5)
precondition(arithmeticUser.underlying == 12, "literal + AdditiveArithmetic compounding produces Int arithmetic")

print("tagged-no-additivearithmetic-family: arithmetic + literal conformance compounding confirmed. userA + literal(5) reduces to Int arithmetic with domain-blind semantics.")

// MARK: - Per-domain alternative (Option C)
//
// A domain where arithmetic IS meaningful — Counter (counts add to counts).
// The domain author conforms AdditiveArithmetic deliberately, and the
// operations have semantic meaning IN THE DOMAIN.

struct Counter: AdditiveArithmetic, Equatable {
    var value: Int

    static var zero: Counter { Counter(value: 0) }

    static func + (lhs: Counter, rhs: Counter) -> Counter { Counter(value: lhs.value + rhs.value) }
    static func - (lhs: Counter, rhs: Counter) -> Counter { Counter(value: lhs.value - rhs.value) }
}

let oneCount = Counter(value: 3)
let anotherCount = Counter(value: 7)
let totalCount = oneCount + anotherCount

precondition(totalCount.value == 10, "Counter arithmetic is meaningful — adding counts produces a count")
print("tagged-no-additivearithmetic-family: per-domain Counter authors AdditiveArithmetic where arithmetic IS the semantic — adding counts produces a count.")

// MARK: - Final summary

print("""

Empirical findings:
- Option B authorable: YES (function-style witnesses)
- Domain-blind footgun: REAL (userA + userB compiles, semantically meaningless)
- Compounding with literals: REAL (userA + 5 reduces to Int arithmetic)
- Option C per-domain: works — Counter authors its own AdditiveArithmetic where
  the operation has semantic meaning

Classification: SOFT structurally / HARD semantically.

Recommendation: Do NOT include AdditiveArithmetic family in the SLI target.
Package-level import granularity is too coarse — every Tagged in the
consumer's compilation unit would gain arithmetic, including domains that
don't authorize it. Domains with meaningful arithmetic should conform
per-domain (Counter, Cardinal, etc.); domains without should not be
silently swept into arithmetic by an SLI import.

This is the singular case in the SLI-eligibility analysis where structural
authorability and semantic correctness diverge, and the semantic verdict
wins.
""")
