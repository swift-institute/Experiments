// MARK: - Approach 12: Tagged<POSIX, ISO_9945.Stats> — L2-as-RawValue
// Purpose: Verify the principal's 2026-05-02 refinement of approach 11:
//          instead of declaring a hand-written wrapping struct at L3,
//          use `swift-tagged-primitives.Tagged` with the L3 namespace
//          enum as the phantom tag and L2's struct as the RawValue.
//
// User formulation (verbatim):
//   public typealias `POSIX.Kernel.File.Stats` =
//       Tagged<POSIX, ISO_9945.Kernel.File.Stats>
//
// Hypothesis: Tagged with L2's struct as RawValue gives:
//   (a) zero L2 migration cost (iso-9945 stays unchanged),
//   (b) single source of data (Tagged's rawValue IS L2's struct),
//   (c) distinct nominal types via generic instantiation
//       (Tagged<POSIX, X> ≠ X), so no same-signature method collision,
//   (d) the L3-unifier's ergonomic method dispatches through the
//       constrained-extension on Tagged at the typealiased site
//       (Kernel.File.Stats = Tagged<POSIX, ISO_9945.Kernel.File.Stats>).
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — all six criteria pass; structurally cleanest variant
//         of the operation-struct pattern. Zero L2 migration cost.
// Date: 2026-05-02
//
// Build: clean (no warnings)
// Runtime output:
//   Kernel.File.Stats.get(descriptor: 0) = size=1024 perms=644
//   Kernel.File.Stats.get(descriptor: -1) = size=1024 perms=644 (L3 policy retry kicked in)
//   ISO_9945.Kernel.File.Stats(descriptor: -1) THROWS interrupted (L2 has no retry — proves L2/L3 are distinct)
//   POSIX.Kernel.File.Stats(descriptor: -1) = size=1024 (L3 init handles retry via Tagged constrained ext)
//   Type via Kernel.File.Stats: size=1024
//   withRetry.rawValue: size=1024 (L2 struct accessible via .rawValue)
// Exit: 0
//
// Criterion matrix:
//  (1) Type identity preserved at consumer:  PASS — Kernel.File.Stats
//      resolves through `Kernel.File.Stats = POSIX.Kernel.File.Stats =
//      Tagged<POSIX, ISO_9945.Kernel.File.Stats>`. Single nominal type
//      at consumer (the Tagged generic instantiation).
//
//  (2) L3-policy resolution at consumer:    PASS — descriptor: -1 succeeds
//      via Kernel.* (retry kicks in) but throws via ISO_9945.* (no retry).
//      Proves the L3-unifier static func dispatches through the
//      constrained-extension `init(descriptor:)` on `Tagged<POSIX, …>`.
//
//  (3) Type instantiation:                  PASS — `let s: Kernel.File.Stats`
//      and `Kernel.File.Stats(descriptor:)` and `.get(descriptor:)` all work.
//
//  (4) NO @_spi:                            PASS — zero @_spi anywhere.
//      iso-9945 is plain `public`; swift-posix imports plain `public`.
//
//  (5) NO consumer call shape change:       PASS — Kernel.File.Stats.get(
//      descriptor:) and Kernel.File.Stats(descriptor:) work identically
//      to single-module form. Power-user gets `stats.rawValue.field` as
//      the explicit reach-through; or `stats.field` via forwarding accessors.
//
//  (6) Compiles cleanly:                    PASS — no warnings.
//
// Architectural advantages over approaches 10/11:
//   - L2 stays UNCHANGED. iso-9945's struct shape is identical to current
//     production. Zero migration cost at L2 (vs approach 11's struct-init
//     paradigm shift).
//   - Single source of data: Tagged's RawValue IS L2's struct. Adding a
//     field at L2 is automatically available via `.rawValue.field`. No
//     hand-written wrap-as-stored-property at L3.
//   - Phantom tag = the L3 namespace enum itself (POSIX). No new tag
//     types needed. Same mechanism extends to Windows trivially:
//     Tagged<Windows, Windows.`32`.Kernel.File.Stats>.
//   - Constrained extension dispatch on Tagged provides the layer's
//     methods at exactly the right path, with no cross-module same-sig
//     collision possible (the generic instantiation is a distinct
//     nominal type from the RawValue).
//
// Trade-offs:
//   - Field-access ergonomics: forwarding accessors needed at L3 for
//     consumers who don't want `.rawValue.field` reach-through. Boilerplate
//     scales with field count × layer count.
//   - swift-tagged-primitives becomes a load-bearing dependency for the
//     L2/L3 platform stack. Major architectural commitment.
//   - Distinct nominal types still exist (Tagged<POSIX, X> ≠ X). The
//     "duplicate structs" structural property is the same as approaches
//     10/11; the distinction is mechanical (generic instantiation) rather
//     than hand-written wrapping struct.

import L3Policy
import Tagged_Primitives

// L3-unifier ergonomic call (typical consumer):
let normal = try Kernel.File.Stats.get(descriptor: 0)
print("Kernel.File.Stats.get(descriptor: 0) = size=\(normal.size) perms=\(String(normal.permissions, radix: 8))")

// L3-unifier with EINTR scenario — descriptor -1 simulates EINTR; L3 retries:
let withRetry = try Kernel.File.Stats.get(descriptor: -1)
print("Kernel.File.Stats.get(descriptor: -1) = size=\(withRetry.size) perms=\(String(withRetry.permissions, radix: 8)) (L3 policy retry kicked in)")

// Direct L2 spec-literal call — proves L2 is uninvolved in policy:
do throws(FooError) {
    let raw = try ISO_9945.Kernel.File.Stats(descriptor: -1)
    print("ISO_9945.Kernel.File.Stats(descriptor: -1) unexpected success = \(raw)")
} catch {
    print("ISO_9945.Kernel.File.Stats(descriptor: -1) THROWS \(error) (L2 has no retry — proves L2/L3 are distinct)")
}

// Direct L3 init via Tagged — proves the policy lives in the constrained init:
let l3Direct = try POSIX.Kernel.File.Stats(descriptor: -1)
print("POSIX.Kernel.File.Stats(descriptor: -1) = size=\(l3Direct.size) (L3 init handles retry via Tagged constrained ext)")

// Type identity check at consumer site — Kernel.File.Stats is the Tagged variant:
let typed: Kernel.File.Stats = withRetry
print("Type via Kernel.File.Stats: size=\(typed.size)")

// rawValue reach-through: power-user accessing the L2 struct directly
print("withRetry.rawValue: size=\(withRetry.rawValue.size) (L2 struct accessible via .rawValue)")
