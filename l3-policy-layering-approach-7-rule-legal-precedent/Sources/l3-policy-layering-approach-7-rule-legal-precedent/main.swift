// MARK: - Approach 7: rule-legal-demo / rule-law-demo Precedent Investigation
// Purpose: Investigate whether rule-legal-demo or rule-law-demo employ a
//          layering pattern matching the L2/L3 same-name method-wrapping
//          problem (typed L2 methods + L3 policy wrapper, type identity
//          preserved across modules).
// Hypothesis: Per the handoff, the user recalled possibly-similar layering.
//             Investigate whether this can be replicated.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: REFUTED — No relevant precedent found
// Date: 2026-05-02
//
// Investigation method (grep, no swift build needed):
//
//   $ grep -rln "@_spi\|@_implementationOnly\|@_disfavoredOverload\|@_exported" \
//       /Users/coen/Developer/rule-legal/ /Users/coen/Developer/rule-law/
//
// Findings:
//   • rule-legal-demo: uses @_exported import only (the standard
//     re-export chain pattern, [PLAT-ARCH-006]). No @_spi, no
//     @_implementationOnly, no @_disfavoredOverload.
//   • rule-law-demo: similar — only standard imports.
//   • Underlying packages (rule-legal-us-nv-private-corporation,
//     swift-us-nv-nrs-77/78, etc.): no exotic import attributes.
//
// Architectural distinction:
//   • Legal architecture: Layer N contributes NEW types/methods on NEW
//     namespaces (Boek 2 statutes → rule-burgerlijk-wetboek-2 composition).
//     Each layer ADDS, doesn't OVERRIDE. No same-name method-wrapping.
//   • Platform architecture (the case under investigation):
//     iso-9945 contributes typed methods on a struct; swift-posix wants
//     to OVERRIDE those methods at the same nominal type with policy
//     semantics. Different problem shape.
//
// What it rules out: The recalled layering pattern from rule-legal/rule-law
// does not address the same-name method-wrapping problem because the legal
// architecture never has same-name override across layers. The user's
// recollection appears to describe the standard re-export chain, which is
// adequate for additive layering but does not solve override-at-same-name
// for L2/L3 policy wrappers. The four legal layers (Namespace, Legislature,
// Judiciary, Composition, Products) compose ADDITIVELY — they do not face
// the same-signature-on-same-nominal-type collision.

print("Approach 7: documentation-only — no relevant precedent found")
