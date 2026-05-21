// MARK: - Sequence.Map Fluent Chain on ~Copyable & ~Escapable Self
//
// Purpose: Reproducer for the day Swift's move-checker relaxes
//          `consuming get` on protocol extensions where
//          `Self: ~Copyable & ~Escapable`. The chain we want to
//          unblock is:
//
//              source.map.compact { transform }
//              source.map.flat    { transform }
//              source.map         { transform }     // via callAsFunction
//
//          where `source: SeqProtocol` is `~Copyable & ~Escapable`
//          and bound to a local `let` at the call site.
//
// Status: DEFERRED-revisit
//
// Hypothesis: The `var map` accessor on a protocol extension where
//             `Self: ~Copyable & ~Escapable` cannot use a
//             `consuming get` body at the direct user call site —
//             `sil_movechecking_capture_consumed` (DiagnosticsSIL.def:886)
//             fires on any local-let-bound receiver.
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a
//            (org.swift.64202605121a) — last verified by parser-primitives'
//            owned-consuming-get experiment on 2026-05-14
// Platform:  macOS 26 (Darwin 25.2.0, arm64)
//
// Result: REFUTED at language level — full writeup in
//         swift-sequence-primitives/Research/source-map-compact-chain-noncopyable-self-blocker.md
//         and ecosystem-wide cross-reference at
//         swift-institute/Research/2026-05-18-consuming-get-protocol-extension-noncopyable-limitation.md
//
// Date: 2026-05-21
//
// ---
//
// Revisit trigger: a future Swift nightly compiles V1's
// `let source = NCSource([1,2,3]); _ = source.v1_map` (uncomment the
// `let _ = source.v1_map` line in V1_ConsumingGetBaseline.swift) without
// the `sil_movechecking_capture_consumed` diagnostic. At that point,
// the asymmetric ship-state in swift-sequence-primitives — `var map`
// for Copyable Self + `consuming func compactMap` direct method for
// ~Copyable Self — can be unified to the fluent chain on both sides.
//
// V3 is the working borrow-semantics reproducer kept in the file set
// for the alternative-Reframing-A revisit (release-mode miscompile
// risk per `swift-property-primitives/Sources/Property Inout Primitives/Property.Inout.swift:90-101`;
// rejected for L1 production today).
//
// ---
//
// This entry-point file exists only to provide the [EXP-007a]
// canonical header anchor. The experiment is INERT in this state —
// no V* function is invoked here. To revisit, edit the V1/V2/V3/V4
// files per their inline comments and rerun against a current
// toolchain.

print("sequence-map-fluent-chain-noncopyable-1 — DEFERRED-revisit (see header)")
