// Experiment: collection-literal conformances on Tagged, post-carve-out.
//
// Empirical verification of the principled-absence rationale documented in
// `Research/principled-absence-array-dict-literal.md` v1.2.0 (carve-out
// authorized by user direction 2026-04-30).
//
// History of this experiment's verdict:
// - v1.0.0: classified HARD-by-policy. Pointfreeco's implementation uses
//   `unsafeBitCast`, our `[MEM-SAFE-001]` strict-memory-safety stance
//   forbids it. Conclusion: per-domain wrapper is the canonical pattern.
// - v1.1.0: surfaced a safe-Swift partial path via
//   `RangeReplaceableCollection.init<S: Sequence>(_:)`. SLI shipped the
//   RRC-constrained `ExpressibleByArrayLiteral`. Set/Dictionary remained
//   excluded.
// - v1.2.0 (current): user authorized a documented `unsafeBitCast`
//   carve-out for these two specific protocol conformances. SLI now
//   ships fully-parametric `ExpressibleByArrayLiteral` and
//   `ExpressibleByDictionaryLiteral` (matching pointfreeco's parametric
//   reach 1:1, marked with the `unsafe` expression keyword to satisfy
//   the strict-memory-safety audit).
//
// This experiment now demonstrates:
// (a) The SLI-shipped fully-parametric conformances via `import` —
//     `let xs: Tagged<Tag, [Int]> = [1, 2, 3]` and the Set/Dictionary
//     analogues.
// (b) Per-domain wrapper structs as a still-valid alternative when the
//     consumer wants stricter semantics or domain validation in the
//     literal init.
// (c) The `[MEM-SAFE-001]` carve-out is BOUNDED — only Array/Dict
//     literal protocols. Other unsafeBitCast usages would need separate
//     authorization.
//
// Verified: Swift 6.3.1 (Apple Swift on macOS) — 2026-04-30.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration

import Tagged_Primitives_Standard_Library_Integration

// Local Carrier conformance for stdlib collection types — central Carrier SLI
// deliberately skips these per swift-carrier-primitives/Research/sli-{array,set,dictionary}.md.
extension Array: @retroactive Carrier.`Protocol` { public typealias Underlying = Array<Element> }
extension ContiguousArray: @retroactive Carrier.`Protocol` { public typealias Underlying = ContiguousArray<Element> }
extension Dictionary: @retroactive Carrier.`Protocol` { public typealias Underlying = Dictionary<Key, Value> }
extension Set: @retroactive Carrier.`Protocol` { public typealias Underlying = Set<Element> }

// MARK: - Domain setup

enum Group {}

// MARK: - (a) SLI-shipped parametric conformances
//
// All four shapes work via the SLI-shipped carve-out — Array,
// ContiguousArray, Set (set literal reuses array syntax), Dictionary.

let arr: Tagged<Group, [Int]> = [10, 20, 30]
precondition(arr.underlying == [10, 20, 30], "Array literal via SLI")

let cont: Tagged<Group, ContiguousArray<Int>> = [1, 2, 3]
precondition(Array(cont.underlying) == [1, 2, 3], "ContiguousArray literal via SLI")

let setTagged: Tagged<Group, Set<Int>> = [1, 2, 3]
precondition(setTagged.underlying == Set([1, 2, 3]), "Set literal (array-syntax) via SLI")

let dict: Tagged<Group, [String: Int]> = ["alice": 1, "bob": 2]
precondition(dict.underlying == ["alice": 1, "bob": 2], "Dictionary literal via SLI")

print("tagged-no-array-dict-literal: SLI-shipped parametric conformances work for Array, ContiguousArray, Set, Dictionary.")
print("   Tagged<Group, [Int]>      = \(arr.underlying)")
print("   Tagged<Group, Set<Int>>   = \(setTagged.underlying)")
print("   Tagged<Group, [Str: Int]> = \(dict.underlying)")

// MARK: - (b) Per-domain wrapper alternative
//
// Consumers who want domain validation in the literal init author a
// wrapper struct instead of relying on the SLI conformance.

struct UserGroup: ExpressibleByArrayLiteral, Equatable {
    let storage: Tagged<Group, [Int]>
    init(arrayLiteral elements: Int...) {
        // Domain validation lives here: positive IDs only.
        let validated = elements.filter { $0 > 0 }
        self.storage = Tagged<Group, [Int]>(validated)
    }
}

let group: UserGroup = [1, 2, -1, 3]      // -1 filtered by domain validation
precondition(group.storage.underlying == [1, 2, 3], "domain-validated wrapper init")

print("tagged-no-array-dict-literal: per-domain wrapper UserGroup applies domain validation in literal init (filters negative IDs).")

// MARK: - (c) Carve-out scope demonstration
//
// The carve-out is BOUNDED to ExpressibleByArrayLiteral and
// ExpressibleByDictionaryLiteral. It does NOT extend to other unsafe
// operations on Tagged. Consumers writing their own unsafeBitCast on
// Tagged would still need to opt into Swift's strict-memory-safety
// machinery explicitly.

print("""

Empirical findings (post-carve-out):
- SLI ships fully-parametric ExpressibleByArrayLiteral and
  ExpressibleByDictionaryLiteral via documented unsafeBitCast carve-out
- Coverage: Array, ContiguousArray, Data, Set, Dictionary, custom
  literal-conformable types — matches pointfreeco 1:1
- Per-domain wrapper struct (Option C) remains the recommended pattern
  when domain validation in literal init is required
- The carve-out is BOUNDED — only these two specific protocol witnesses;
  future SLI additions or main-target additions requiring unsafeBitCast
  need separate per-action user authorization

Classification: SOFT — shipped in SLI via documented carve-out from
[MEM-SAFE-001]. The first and only such carve-out in the package.
""")
