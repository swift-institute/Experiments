// MARK: - Consumer-Side Opt-In Viability Test
// Purpose: Determine whether consumer packages can each independently add
//          ExpressibleByIntegerLiteral for their specific Tagged<Tag, RawValue>
//          combinations without conflicting across modules. If yes, the
//          "identity-primitives ships no conformance; each consumer adds its own"
//          architecture is viable and sidesteps the marker-protocol question.
//
// Hypothesis: Swift's "one conditional conformance per (type, protocol) pair"
//             rule applies across module boundaries. Multiple consumers each
//             adding conformance with disjoint constraints will conflict at
//             the final client site.
//
// Toolchain: Swift 6.3.1 (Xcode 26.4.1 default; swiftlang-6.3.1.1.2)
// Platform:  macOS 26.0 (arm64)
// Date:      2026-04-21
//
// Result: REFUTED — consumer-side opt-in does NOT scale.
//
// Evidence:
//   ConsumerA alone (UserTag/UInt32 literal) → compiles and runs: UserID = 42 works.
//   ConsumerA + ConsumerB both imported → COMPILE ERROR at client site:
//     "type alias 'X' requires the types 'CoordTag' and 'UserTag' be equivalent"
//     "type alias 'X' requires the types 'Double' and 'UInt32' be equivalent"
//
//   Swift's single-conformance rule applies cross-module. Two independent
//   consumer packages each declaring `extension Tagged: ExpressibleByIntegerLiteral
//   where <disjoint constraints>` cannot coexist in the same program — exactly one
//   such declaration per (Tagged, ExpressibleByIntegerLiteral) pair is allowed
//   across the entire build graph.
//
// Implication: If identity-primitives ships no blanket conformance, any ONE
// consumer can add one for its specific specialization — but the moment a second
// consumer (or transitive dependency) does the same for a different specialization,
// the build breaks. The "let each package decide" escape hatch is structurally
// closed. Exactly one package in the whole graph owns Tagged's literal conformance.
//
// Status: REFUTED.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

// This default build imports ConsumerA only. Isolated consumer works:
public import TaggedLib
public import ConsumerA

let user: UserID = 42
print("UserID literal: \(user.rawValue)")
print("(Isolated consumer-A conformance compiles and runs.)")
print("The multi-consumer conflict is in reject-test.swift.txt.")
