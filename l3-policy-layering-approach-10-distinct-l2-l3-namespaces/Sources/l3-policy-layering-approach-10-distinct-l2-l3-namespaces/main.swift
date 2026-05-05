// MARK: - Approach 10: Distinct L2/L3 Top-Level Namespaces (no typealias)
// Purpose: Validate the user's 2026-05-02 proposal: stop typealiasing
//          POSIX.Kernel.File.Stats = ISO_9945.Kernel.File.Stats. Let
//          ISO_9945.* and POSIX.* be DISTINCT top-level namespaces, each
//          owning its own type definitions and methods. Conversion at the
//          L2/L3 boundary is internal to swift-posix.
// User framing: "ISO_9945.* and POSIX.* achieve the same [as my approach 9
//                sub-namespace]; ISO_9945.* is l2 (the equivalent of
//                .Syscall), POSIX.* is l3. I'd like lower level (l2) to be
//                coded without regard to downstream. and STILL have
//                upstream be able to present its public API as it wants."
//
// Hypothesis: When the L2 type and the L3 type are DISTINCT nominal types
//             (no typealias collapse), there is no same-signature extension
//             collision. iso-9945 codes the spec-literal form naturally;
//             swift-posix codes its policy form naturally; the boundary is
//             a value conversion inside swift-posix's body, not a typealias
//             chain. No @_spi, no sub-namespace, no recursion.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — passes all six criteria; structurally cleaner than approach 9
// Date: 2026-05-02
//
// Build: clean (no warnings)
// Runtime output:
//   ISO_9945.Kernel.File.Stats.get() = size=1024 perms=644
//   POSIX.Kernel.File.Stats.get() = size=1024 perms=644
//   Kernel.File.Stats.get() = size=1024 perms=644
//   Type via Kernel.File.Stats: size=1024
// Exit: 0
//
// Criterion matrix (re-interpreted for distinct-types case):
//  (1) Type identity preserved at consumer:  PASS — Kernel.File.Stats
//      resolves through `Kernel.File = POSIX.Kernel.File` to a usable
//      struct. Consumers never see iso-9945's struct directly; type
//      identity is internal to each namespace, with conversion at the
//      L2/L3 boundary inside swift-posix.
//  (2) L3-policy resolution at consumer:    PASS — `Kernel.File.Stats.get()`
//      routes to POSIX.Kernel.File.Stats.get(), which delegates to L2
//      cleanly (different nominal types, no overload collision).
//  (3) Type instantiation:                  PASS
//  (4) NO @_spi:                            PASS
//  (5) NO consumer call shape change:       PASS — `Kernel.File.Stats.get()`
//      identical to single-module form. Power-user access to raw L2 form
//      is at `ISO_9945.Kernel.File.Stats.get()` — which already exists
//      naturally as the spec namespace; no special opt-in needed.
//  (6) Compiles cleanly:                    PASS
//
// Mechanism: Two distinct top-level namespaces (`ISO_9945`, `POSIX`),
// each owning its own type definitions and methods. No typealias chain.
// The L3-unifier flip (here `Kernel.File = POSIX.Kernel.File`) is a
// typealias on the cross-platform UNIFIER namespace (`Kernel`), not
// between `POSIX.*` and `ISO_9945.*` — preserving the per-layer namespace
// independence.
//
// Conversion at the boundary: swift-posix's body of `get()` calls
// `try ISO_9945.Kernel.File.Stats.get()` to reach the spec-literal form,
// receives an `ISO_9945.Kernel.File.Stats` value, and converts to its
// own `POSIX.Kernel.File.Stats` via an `internal init(from l2:)`. The
// conversion site is contained inside swift-posix (one place per
// corrective namespace) and is invisible to consumers.
//
// User framing realized: "lower level (l2) coded without regard to
// downstream" — iso-9945 codes ISO_9945.Kernel.File.Stats naturally as
// the POSIX `struct stat` mirror, without making any choices for
// downstream layers' benefit (no @_spi, no sub-namespace, no
// disambiguation modifiers). "upstream presents its public API as it
// wants" — swift-posix declares POSIX.Kernel.File.Stats with whatever
// field shape, accessors, and policy methods it deems appropriate;
// independent of iso-9945's choices.
//
// Architectural alignment: This is the SAME structural shape the 37
// non-corrective Wave 3.5-1..8 namespaces already use (distinct enum
// at POSIX with method wrappers). For the 4 corrective namespaces
// (Stats, Open, Memory.Map, Time) which are STRUCT-shape rather than
// namespace-enum-shape, the disposition is the same — declare a
// distinct struct at POSIX with the necessary field shape. Wave 3.5-1's
// original disposition for the 4 was correct in concept (distinct type
// at POSIX) but wrong in detail (used enum where struct was needed).
// Wave 3.5-Corrective deviated to typealias chain to get struct
// identity, but that's what created the same-signature collision.
// Approach 10 returns to the structurally consistent pattern.
//
// What it confirms: Distinct top-level L2/L3 namespaces eliminate the
// same-name method-wrapping problem WITHOUT requiring sub-namespace
// nesting at L2 (approach 9), without @_spi (approach 8), without
// consumer migration (approaches 5/6), and without any import-attribute
// dance (approaches 1/2/3). The conversion-at-the-boundary cost is
// trivial in production (struct-to-struct field copy or wrap).

import L3Policy

// L2 spec-literal call (raw syscall path — no policy):
let l2 = try ISO_9945.Kernel.File.Stats.get()
print("ISO_9945.Kernel.File.Stats.get() = size=\(l2.size) perms=\(String(l2.permissions, radix: 8))")

// L3-policy call (the typical consumer path):
let l3 = try POSIX.Kernel.File.Stats.get()
print("POSIX.Kernel.File.Stats.get() = size=\(l3.size) perms=\(String(l3.permissions, radix: 8))")

// After the L3-unifier flip Kernel.File = POSIX.Kernel.File, consumer
// reaches the L3-policy path through Kernel.*:
let viaKernel = try Kernel.File.Stats.get()
print("Kernel.File.Stats.get() = size=\(viaKernel.size) perms=\(String(viaKernel.permissions, radix: 8))")

// Type identity check at consumer site:
let typedL3: POSIX.Kernel.File.Stats = l3
let typedKernel: Kernel.File.Stats = viaKernel
print("Type via Kernel.File.Stats: size=\(typedKernel.size)")

// Cross-check: ISO_9945's struct and POSIX's struct are DISTINCT types.
// (Compile-time only — uncommenting the below would fail if it tried to
//  cross the type boundary without the explicit conversion init.)
// let cross: ISO_9945.Kernel.File.Stats = l3   // ← would be an error
