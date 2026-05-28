// MARK: - SE-503 Suppressed Associated Types — Cross-Version Probe (definitions module)
//
// Purpose: Determine whether the SE-503 migration form — explicitly restating
//   `where <PrimaryAssoc>: ~Copyable` on extensions and generic constraints —
//   compiles IDENTICALLY on Swift 6.3 (experimental SuppressedAssociatedTypes
//   flag) and a final-SE-503 toolchain, so the swift-primitives edits can land
//   today as a single source form.
// Hypothesis: the explicit restatement is accepted on both (redundant-but-legal
//   on 6.3 per the migration doc; required on final SE-503).
//
// Toolchain: Apple Swift 6.3.2 (org.swift.632202605101a)  +  Apple Swift 6.5-dev / snapshot 2026-05-12-a (org.swift.64202605121a)
// Platform: macOS 26 (arm64)
//
// Status: CONFIRMED — a portable cross-version form exists, but NOT the naive one.
// Date: 2026-05-28
//
// RESULTS (evidence in Outputs/):
//  F1  Un-gated SE-503 restatement (`extension Mailbox where Items: ~Copyable`,
//      `where T.Items: ~Copyable`, …): REFUTED as "same code on both".
//        • Swift 6.3.2  → ERROR: "cannot suppress '~Copyable' on generic parameter
//          'Self.Items' defined in outer scope" (all 5 variants V1–V5).
//        • Swift 6.5-dev → Build complete (flag-deprecation warnings only).
//        ⇒ 6.3 FORBIDS the restatement; SE-503 REQUIRES it. Mutually exclusive.
//  F2  `#if compiler(>=6.5)` gate (restatement in #if, current bare form in #else):
//      CONFIRMED. Builds + runs on BOTH toolchains, debug AND release ([EXP-017]),
//      cross-module (Uses imports Defs). Branch witnesses prove correct selection:
//        • 6.3.2  → #else  "compiler<6.5 → prototype bare branch"
//        • 6.5-dev → #if   "compiler>=6.5 → SE-503 restatement branch"
//        Evidence: Outputs/build-6.3.2-gate65-debug.txt, build-6.5dev-gate65-debug.txt,
//                  build-*-GATED-{debug,release}.txt, run-*-GATED.txt ("se503-cross-version built").
//  F3  `hasFeature(SuppressedAssociatedTypesWithDefaults)` is NOT a usable gate on the
//      2026-05-12 snapshot: false even with the flag enabled → both toolchains took #else.
//  F4  SE-0503 status = "Accepted" (NOT yet in a numbered release); lives on `main`
//      behind `-enable-experimental-feature SuppressedAssociatedTypesWithDefaults`.
//      The old `SuppressedAssociatedTypes` flag is DEPRECATED on 6.5-dev (warning →
//      OldSuppressedAssociatedTypes) but still compiles — and already accepts the restatement.
//  F5  6.3.2 silently IGNORES the unknown `SuppressedAssociatedTypesWithDefaults` flag
//      (no error) — enabling it in a shared Package.swift is safe on 6.3.2.
//
//  F6  "Use a `NonCopyable` name instead of `~Copyable`" idea — DISPROVEN (Probes/):
//        • P2 `associatedtype Item: NonCopyable` (protocol bound, NonCopyable: ~Copyable):
//          move-only Item REJECTED on BOTH ("UserBox does not conform to Box"). A conformance
//          ADDS a requirement; it cannot REMOVE the Copyable default. P3 (real `~Copyable`) accepts it.
//        • P4 `typealias NC = ~Copyable` DOES name the suppression and works at DECLARATION sites.
//        • P5 but at a USE-SITE restatement (`extension Mailbox where Items: NC`) it hits the IDENTICAL
//          6.3.2 error as the literal `~Copyable` (compiler desugars the alias before applying the rule),
//          and compiles on 6.5-dev. ⇒ naming does NOT escape the version split; only `#if compiler` does.
//
//  F7  "Keep the bare form, switch later" is NOT a flag-day (Probes/p6, p7):
//        • P6 today's BARE library (bare extension + bare generic use, no restatement)
//          COMPILES on BOTH 6.3.2 and 6.5-dev. The transition does not break the library build.
//        • P7 the narrowing is CONSUMER-SIDE: a move-only-associated-type caller of a bare API
//          fails ONLY on 6.5-dev ("referencing 'ping()' requires 'MB.Items' (MoveOnly) conform to
//          'Copyable'"); 6.3.2 accepts it. ⇒ only the ~39 load-bearing sites ever break; the
//          ~158 parser sites (Input always Copyable) never hit it. Switch is small + lazy + per-package.
//
// THRESHOLD CAVEAT: `>=6.5` is the conservative choice — 6.5-dev is the version
// EMPIRICALLY verified to accept the restatement; 6.4 was untestable (no toolchain).
// If SE-0503 ships in a release < 6.5, tighten the gate then. Re-verify on the actual
// SE-0503 release toolchain ([META-006] toolchain-triggered revalidation).
//
// Reference: https://github.com/swiftlang/swift/blob/main/userdocs/diagnostics/old-suppressed-associatedtypes.md
//            SE-0503 (Accepted): proposals/0503-suppressed-associated-types.md
// Audit:     swift-institute/Audits/AUDIT-se-503-suppressed-associated-types-2026-05-28.md

// Doc's canonical shape: primary `Items` (suppressed) + non-primary `Generator` (suppressed).
public protocol Mailbox<Items>: ~Copyable {
    associatedtype Items: ~Copyable
    associatedtype Generator: ~Copyable
}

// Inherited / re-exposed primary: `Element` is suppressed in `Streaming` and
// re-exposed as a PRIMARY associated type by `Stream` — mirrors
// `Input.`Protocol`<Element>: Streaming` and `Parser.Bidirectional`.
public protocol Streaming {
    associatedtype Element: ~Copyable
}
public protocol Stream<Element>: Streaming {
    // Element re-exposed as primary; suppression inherited from Streaming.
}

// Carrier shape: primary `Underlying` (suppressed) + defaulted non-primary
// `Domain` (suppressed, = Never) — mirrors `_CarrierProtocol`. The `C.Domain`
// restatement is the exact shape flagged as a possible 6.3 error in
// swift-carrier-primitives Fixture+describe.swift.
public protocol Quantity<Underlying>: ~Copyable {
    associatedtype Underlying: ~Copyable
    associatedtype Domain: ~Copyable = Never
}
