// MARK: - Approach 11: Operation-Struct Pattern (legal-architecture mirror)
// Purpose: Verify the user's 2026-05-02 proposal that the rule-law-us-nv
//          legal architecture pattern (operation-as-struct, replace-
//          typealias-with-wrapping-struct-on-override) generalizes to the
//          syscall layering problem.
//
// User framing: "L1 X, L2 Z.Y, and L3 X.Y where the methods and functions
//                can be overridden on L3" — achieved structurally via:
//                  L1: namespace anchors (Kernel, File)
//                  L2 Z.Y: ISO_9945.Kernel.File.Stats (operation struct;
//                          init IS the syscall, struct holds result fields)
//                  L3 X.Y: Kernel.File.Stats.get(...) (ergonomic method
//                          at the unifier; single extension site)
//                Override at L3 = replace `POSIX.Kernel.File.Stats`
//                typealias with a distinct wrapping struct whose init
//                applies policy and delegates to L2's init.
//
// Legal-architecture precedent: `rule-law-us-nv/Sources/Rule Law US
// Nevada/Rule Law US Nevada.swift` lines 41-57:
//   "Typealiases to legislature packages. When case law or composition
//    logic needs to modify a chapter's behavior, replace the typealias
//    with a custom type that wraps or extends the statute encoding."
// Approach 11 ports this prescription to the platform stack.
//
// Hypothesis: When operations are STRUCTS (not methods), and the L3-
//             unifier adds the ergonomic method at exactly one site,
//             override at L3 is achieved by typealias replacement at the
//             OPERATION STRUCT level — no same-signature method collision
//             because the override happens at a different declaration
//             axis (struct declaration, not extension method).
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — passes all six criteria; structurally generalizable.
// Date: 2026-05-02
//
// Build: clean (no warnings)
// Runtime output:
//   Kernel.File.Stats.get(descriptor: 0) = size=1024 perms=644
//   Kernel.File.Stats.get(descriptor: -1) = size=1024 perms=644 (L3 policy retry kicked in)
//   ISO_9945.Kernel.File.Stats(descriptor: -1) THROWS interrupted (L2 has no retry — proves L2/L3 are distinct)
//   POSIX.Kernel.File.Stats(descriptor: -1) = size=1024 (L3 init handles retry)
//   Type via Kernel.File.Stats: size=1024
// Exit: 0
//
// Criterion matrix:
//  (1) Type identity preserved at consumer:  PASS — `Kernel.File.Stats`
//      resolves through the typealias chain
//      `Kernel.File.Stats = POSIX.Kernel.File.Stats` to a usable struct.
//      Consumer's type annotation `let s: Kernel.File.Stats` works.
//      Internal data is single-source at L2 via `_underlying` stored
//      property (no field duplication; maintenance changes propagate).
//
//  (2) L3-policy resolution at consumer:    PASS — `Kernel.File.Stats.get(
//      descriptor:)` invokes the L3-unifier's static func, which calls
//      `Kernel.File.Stats(descriptor:)` — that init resolves to
//      `POSIX.Kernel.File.Stats.init(descriptor:)` (the policy init), which
//      applies retry and delegates to L2's init.
//
//  (3) Type instantiation:                  PASS — `let s: Kernel.File.Stats`
//      and `Kernel.File.Stats.get(descriptor:)` both work.
//
//  (4) NO @_spi:                            PASS — zero `@_spi` attributes
//      anywhere. iso-9945 codes plain `public`; swift-posix imports plain
//      `public`; no visibility hacks.
//
//  (5) NO consumer call shape change:       PASS — `Kernel.File.Stats.get(
//      descriptor:)` is the consumer-facing entry, identical in shape to
//      what consumers expect from the L3-unifier flip. Power-user access
//      to L2 raw form is `try ISO_9945.Kernel.File.Stats(descriptor: fd)`
//      — direct init at the spec namespace.
//
//  (6) Compiles cleanly:                    PASS — no warnings.
//
// Mechanism summary:
//
//   ┌─────────────────────────────────────────────────────────────────┐
//   │ L1 (L1Defs):    Kernel, Kernel.File namespaces; FooError        │
//   ├─────────────────────────────────────────────────────────────────┤
//   │ L2 (L2Methods): ISO_9945.Kernel.File.Stats — OPERATION STRUCT   │
//   │                 init IS the syscall; fields hold the result     │
//   ├─────────────────────────────────────────────────────────────────┤
//   │ L3 (L3Policy):  POSIX.Kernel.File.Stats — DISTINCT WRAPPING     │
//   │                 STRUCT (override case); _underlying: ISO_9945...│
//   │                 Kernel.File = POSIX.Kernel.File (unifier flip)  │
//   │                 extension Kernel.File.Stats {                   │
//   │                   static func get(...) {                        │
//   │                     try Kernel.File.Stats(descriptor:)          │
//   │                   }                                             │
//   │                 }                                               │
//   └─────────────────────────────────────────────────────────────────┘
//
// Why no recursion: `static func get(...)` and `init(descriptor:)` are
// different declaration kinds. The unifier's static func body calls the
// init — different shape, no overload resolution conflict. Within the
// L3Policy module, only ONE declaration of `static func get` exists
// (declared on `Kernel.File.Stats`). The L2 module declares `Stats`
// (a type, not a method). Different kinds — no collision.
//
// Why no struct duplication of fields: L3's `Stats` holds an
// `_underlying: ISO_9945.Kernel.File.Stats` stored property. Field
// accessors forward to `_underlying`. Adding a field at L2 is reflected
// at L3 by adding one accessor (or none, if iso-9945's struct exposes
// the field publicly and L3 doesn't need to curate). No field
// duplication; single source of truth.
//
// Override-toggle mechanism (in production usage):
//   * No override needed → `extension POSIX.Kernel.File { public typealias
//     Stats = ISO_9945.Kernel.File.Stats }` (the trivial case)
//   * Override needed → declare distinct wrapping struct (this experiment)
//   * Toggling between the two is a one-file change at L3-policy; nothing
//     at L2 changes. Mirrors the legal architecture's "replace the
//     typealias with a custom type" prescription exactly.
//
// Generalization: this pattern applies uniformly to any L2/L3 layering
// where:
//   - L2 owns the spec-literal operation
//   - L3 may need to apply policy/composition
//   - The data type identity should be preserved across consumers
//
// In the legal architecture, `NRS 77.310.1` IS the operation (init does
// the statute evaluation). When case law modifies, the L3 composition
// layer replaces the typealias with a wrapping struct that does
// statute evaluation + case-law modification in its init. Same
// mechanism; same generalizable shape.

import L3Policy

// L3-unifier ergonomic call (typical consumer):
let normal = try Kernel.File.Stats.get(descriptor: 0)
print("Kernel.File.Stats.get(descriptor: 0) = size=\(normal.size) perms=\(String(normal.permissions, radix: 8))")

// L3-unifier with EINTR scenario — descriptor -1 simulates EINTR; L3 policy retries:
let withRetry = try Kernel.File.Stats.get(descriptor: -1)
print("Kernel.File.Stats.get(descriptor: -1) = size=\(withRetry.size) perms=\(String(withRetry.permissions, radix: 8)) (L3 policy retry kicked in)")

// Direct L2 spec-literal call — proves L2 is uninvolved in policy:
do throws(FooError) {
    let raw = try ISO_9945.Kernel.File.Stats(descriptor: -1)
    print("ISO_9945.Kernel.File.Stats(descriptor: -1) unexpected success = \(raw)")
} catch {
    print("ISO_9945.Kernel.File.Stats(descriptor: -1) THROWS \(error) (L2 has no retry — proves L2/L3 are distinct operation structs)")
}

// Direct L3 init — proves the policy lives in L3's init:
let l3Direct = try POSIX.Kernel.File.Stats(descriptor: -1)
print("POSIX.Kernel.File.Stats(descriptor: -1) = size=\(l3Direct.size) (L3 init handles retry)")

// Type identity at consumer site:
let typed: Kernel.File.Stats = withRetry
print("Type via Kernel.File.Stats: size=\(typed.size)")
