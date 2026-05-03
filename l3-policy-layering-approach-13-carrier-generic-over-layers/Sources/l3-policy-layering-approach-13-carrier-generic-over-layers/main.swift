// MARK: - Approach 13: Carrier-generic over L2 and L3 layers
// Purpose: Verify the principal's 2026-05-02 generalization that
//          swift-carrier-primitives' Carrier protocol enables generic
//          functions accepting BOTH L2 (bare struct) AND L3 (Tagged-
//          wrapped) types uniformly via `some Carrier<L2.Type>`.
//
// User formulation: "we could then also use carrier-primitives (tagged
//   conforms to carrier) and use some Carrier<X> to allow both L2 and
//   L3 types where it doesn't matter"
//
// Design intent confirmation (Tagged+Carrier.swift:18-21):
//   "This is the move that lets `some Carrier<Cardinal>` accept bare
//    `Cardinal`, `Tagged<User, Cardinal>`, and any further-nested
//    Tagged variant uniformly — subsuming the per-type
//    `Cardinal.\`Protocol\`` cascade with a single parametric
//    extension."
//
// Cascade verified by experiment 13:
//   ISO_9945.Kernel.File.Stats: Carrier with Underlying == Self
//     (trivial self-carrier extension default)
//   Tagged<POSIX, ISO_9945.Kernel.File.Stats>: Carrier with
//     Underlying == RawValue.Underlying == ISO_9945.Kernel.File.Stats
//     (cascade through Tagged+Carrier.swift conformance)
//   `describeStats(_: some Carrier<ISO_9945.Kernel.File.Stats>)`
//     accepts both — no overload distinction needed at the call site.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — `some Carrier<L2.Type>` accepts both layers; runtime
//         demonstrates a single generic function processing bare L2,
//         Tagged-wrapped L3, AND L3-unifier-typealiased Kernel.* uniformly.
// Date: 2026-05-02
//
// Build: clean (no warnings)
// Runtime output:
//   L2 bare struct via describeStats: size=1024 perms=644
//   L3 Tagged variant via describeStats: size=1024 perms=644
//   Kernel.File.Stats (= L3 Tagged) via describeStats: size=1024 perms=644
//   L2.underlying type matches L3.underlying type: true
//   type(of: l2): Stats
//   type(of: l3): Tagged<POSIX, Stats>
// Exit: 0
//
// What this confirms:
//   (1) Trivial self-carrier conformance at L2 (one-line opt-in:
//       `extension ISO_9945.Kernel.File.Stats: Carrier { typealias
//       Underlying = Self }`) is mechanically free — defaults from
//       `Carrier where Underlying == Self.swift` provide
//       `var underlying` and `init(_:)` automatically.
//   (2) Tagged's existing Carrier conformance cascades correctly:
//       `Tagged<POSIX, ISO_9945.Kernel.File.Stats>.Underlying ==
//        ISO_9945.Kernel.File.Stats`. No additional plumbing needed
//       at swift-posix.
//   (3) `some Carrier<X>` is the lightweight generic syntax (X is
//       declared as primary associated type on Carrier protocol).
//       Equivalent to `<C: Carrier>(_:C) where C.Underlying == X`.
//   (4) Static type identity is preserved (l2 is Stats; l3 is
//       Tagged<POSIX, Stats>) — distinct nominal types remain available
//       for code that needs to distinguish layers.
//   (5) Layer-agnostic processing is now expressible at any abstraction
//       level: utility functions that don't care which layer they
//       receive can take `some Carrier<L2.Type>` and operate on the
//       canonical underlying data.
//
// Architectural value beyond approach 12:
//   Approach 12 unified the consumer call shape via L3-unifier typealias
//   (`Kernel.File.Stats.get(...)` resolves to Tagged constrained ext).
//   Approach 13 extends that to the GENERIC API LEVEL: code that
//   processes "any Stats" — across libraries, across layers, across
//   nested Tagged variants — is a single generic function rather than
//   a forest of overloads. This is what "ecosystem-wide layer-agnostic
//   helpers" looks like in practice.

import L3Policy
import Tagged_Primitives
import Carrier_Primitives

// L2 instance (bare struct):
let l2 = try ISO_9945.Kernel.File.Stats(descriptor: 0)
print("L2 bare struct via describeStats: \(describeStats(l2))")

// L3 instance (Tagged-wrapped):
let l3 = try POSIX.Kernel.File.Stats(descriptor: -1)   // -1 simulates EINTR; L3 retries
print("L3 Tagged variant via describeStats: \(describeStats(l3))")

// Same generic function — different concrete types — both valid:
let kernelView = try Kernel.File.Stats(descriptor: 0)
print("Kernel.File.Stats (= L3 Tagged) via describeStats: \(describeStats(kernelView))")

// Type identity at the Carrier protocol level:
print("L2.underlying type matches L3.underlying type:",
      type(of: l2.underlying) == type(of: l3.underlying))

// Layer-distinguishing static type check (what consumers can rely on):
print("type(of: l2): \(type(of: l2))")
print("type(of: l3): \(type(of: l3))")
