// Experiment: Tagged is not Sequence / Collection by default. Empirically classify.
//
// Demonstrates the principled absence rationale documented in
// `Research/principled-absence-sequence-collection.md`.
//
// (a) AUTHORABILITY TEST (Option B — SLI-style opt-in): Sequence and
//     Collection's witnesses (makeIterator, subscript, index-after) are
//     all function-style; should bypass the structural ~Escapable blocker.
//
// (b) WRAPPER-VS-CONTENT CONFLATION: even with the conformance, generic
//     algorithms over T: Sequence treat Tagged<Tag, [Int]> and [Int]
//     interchangeably. The wrapper boundary becomes invisible to the
//     algorithm.
//
// (c) HONEST DEFAULT (Option C): demonstrate the explicit-unwrap pattern
//     `for x in tagged.underlying { ... }` and how it preserves the
//     wrapper-boundary visibility.
//
// Verified: Swift 6.3.1 (Apple Swift on macOS) — 2026-04-30.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration

// Local Carrier conformance for stdlib collection types — central Carrier SLI
// deliberately skips these per swift-carrier-primitives/Research/sli-{array,set,dictionary}.md.
import Tagged_Primitives_Standard_Library_Integration

extension Array: @retroactive Carrier.`Protocol` { public typealias Underlying = Array<Element> }
extension ContiguousArray: @retroactive Carrier.`Protocol` { public typealias Underlying = ContiguousArray<Element> }
extension Dictionary: @retroactive Carrier.`Protocol` { public typealias Underlying = Dictionary<Key, Value> }
extension Set: @retroactive Carrier.`Protocol` { public typealias Underlying = Set<Element> }

// MARK: - Domain setup

enum User {}
extension User { typealias Roster = Tagged<User, [Int]> }

// MARK: - SLI-shipped conformance verification
//
// `Tagged: Sequence` and `Tagged: Collection` ship in
// `Sources/Tagged Primitives Standard Library Integration/Tagged+Sequence.swift`
// and `Tagged+Collection.swift`. Importing SLI brings them into scope.
//
// The Array literal conformance also shipped in SLI (via the documented
// unsafeBitCast carve-out), so we can construct the roster via literal
// rather than `__unchecked: ()`.

let roster: User.Roster = [10, 20, 30]

// Sequence ergonomics:
var collected: [Int] = []
for x in roster {
    collected.append(x)
}
precondition(collected == [10, 20, 30], "Sequence iteration via SLI works")

// Collection ergonomics:
precondition(roster.first == 10,  "Collection.first via subscript works")
precondition(roster.count == 3,   "Collection.count works")
precondition(roster[roster.startIndex] == 10, "Collection.subscript works")

print("tagged-no-sequence-collection: SLI-shipped Tagged: Sequence + Tagged: Collection work — iteration, first, count, subscript, all forward to Underlying.")

// MARK: - Wrapper-vs-content conflation
//
// Generic algorithms over T: Sequence treat Tagged<Tag, [Int]> and a plain
// [Int] interchangeably. The wrapper boundary is invisible to the algorithm.

func sumElements<S: Sequence>(_ seq: S) -> Int where S.Element == Int {
    seq.reduce(0, +)
}

let plainArray: [Int] = [10, 20, 30]
let plainSum = sumElements(plainArray)
let taggedSum = sumElements(roster)

precondition(plainSum == taggedSum,
             "generic algorithm produces identical results for [Int] and Tagged<Tag, [Int]> — wrapper boundary invisible")
precondition(plainSum == 60, "sum(10, 20, 30) == 60")

print("tagged-no-sequence-collection: wrapper-vs-content conflation confirmed. sumElements treats Tagged<Tag, [Int]> identically to [Int] — the phantom Tag is invisible to the generic algorithm.")

// MARK: - Honest pattern (Option C — preferred default)
//
// The consumer unwraps explicitly. Each .underlying marks the type-boundary
// crossing.

var honestCollected: [Int] = []
for x in roster.underlying {           // explicit unwrap; reader knows: now operating on [Int]
    honestCollected.append(x)
}
precondition(honestCollected == [10, 20, 30], "explicit-unwrap pattern produces same result")

// Generic algorithms cannot accidentally consume Tagged via T: Sequence —
// the consumer must explicitly call .underlying first.

// _ = sumElements(roster)            // would still compile due to opt-in conformance
let honestSum = sumElements(roster.underlying) // explicit unwrap; honest about boundary

precondition(honestSum == taggedSum, "explicit-unwrap and opt-in produce same result; the difference is the call-site honesty")

print("tagged-no-sequence-collection: explicit-unwrap pattern (roster.underlying.reduce/forEach/etc.) marks the wrapper boundary at every crossing.")

// MARK: - Final summary

print("""

Empirical findings:
- Option B authorable: YES (function-style witnesses for Sequence + Collection)
- Wrapper-vs-content conflation: REAL (generic T: Sequence algorithms treat
  Tagged<Tag, [Int]> identically to [Int])
- Option C (explicit .underlying): preserves wrapper-boundary visibility at the
  cost of slightly more verbose call sites

Classification: SOFT absence. SLI opt-in is structurally fine; the
wrapper-vs-content conflation is the consumer's accepted trade-off.
For Institute primitives consumers (where type-boundary visibility is
load-bearing), the explicit-unwrap pattern is the preferred default —
SLI opt-in is for consumers integrating with external Sequence/Collection-
constrained APIs that they cannot refactor to take .underlying.
""")
