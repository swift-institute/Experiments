// MARK: - Span Carrier Conformance Experiment
// Purpose: Empirically determine whether `Span<Element>: Carrier` is viable,
//          contra Research/sli-span-family.md DECISION (2026-04-24).
// Hypothesis: `Span: Carrier` is structurally viable in the Q3 (Copyable ×
//             ~Escapable) quadrant, both same-module and cross-module, in
//             debug and release.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
//
// Status: CONFIRMED — Span: Carrier is viable with explicit witnesses;
//         the production default extension does NOT cover it.
// Result: CONFIRMED (V1 REFUTED → V2/V3/V4 CONFIRMED). Build Succeeded
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         in debug + release; cross-module dispatch verified.
//         Output: V3 extract=5, describeAsBytes=5, init(_:)=5, V3 complete
// Date: 2026-04-25
//
// Variants:
//   V1 — REFUTED. Bare `extension Span: Carrier { typealias Underlying = Self }`
//        relying on the production `Carrier where Underlying == Self` default
//        extension. Diagnostic: "candidate would match if 'Span<Element>'
//        conformed to 'Escapable'". Root cause: the trivial-self extension
//        carries Self's default `Escapable` constraint and does not propagate
//        `~Escapable`, so its witnesses are excluded from candidacy entirely
//        for ~Escapable Self. Sharper failure than sli-span-family.md
//        anticipated — the issue isn't @_lifetime mismatch on the witness
//        body; the witness candidate never enters consideration.
//        Receipt: Outputs/build.txt.
//
//   V2 — CONFIRMED (same-module). Explicit witnesses with @_lifetime
//        annotations:
//            var underlying: Span<Element> {
//                @_lifetime(borrow self)
//                _read { yield self }
//            }
//            @_lifetime(copy underlying)
//            init(_ underlying: consuming Span<Element>) {
//                self = underlying
//            }
//        Note: `borrowing get { self }` does NOT work for ~Escapable Self —
//        returning self from a borrowing accessor is treated as a consume.
//        The `_read { yield self }` coroutine form is required (matching the
//        production trivial-self default's body shape).
//        Receipt: Outputs/build-v2-spancarrier.txt.
//
//   V3 — CONFIRMED. Cross-module use (this file): generic dispatch through
//        `some Carrier & ~Escapable`, constrained generic `where
//        C.Underlying == Span<UInt8>`, init form. Side finding: a generic
//        algorithm returning `C.Underlying` as a function result requires
//        `where C.Underlying: Copyable` (the protocol's Underlying is
//        `~Copyable & ~Escapable`, so unconstrained returns are rejected
//        with "'copy' cannot be applied to noncopyable types"). Span is
//        Copyable so this constraint is satisfied at the use site.
//        Receipt: Outputs/build-v3c.txt, Outputs/run.txt.
//
//   V4 — CONFIRMED. Release-mode build + run identical to debug.
//        Receipts: Outputs/build-release.txt, Outputs/run-release.txt.
//
// Headline: sli-span-family.md DECISION (skip) is empirically over-cautious
// on concern #1 (lifetime-requirement viability) — explicit witnesses do
// satisfy the protocol. The cost case (#3, "explicit bodies, not one-liners")
// remains: each Span variant needs ~5 lines of conformance. Concerns #2
// (parametric "Span of a Carrier Pointee") and #4 (single-conformance lock)
// are not addressed by this experiment.

import SpanCarrier

// MARK: - V3: Cross-module generic algorithms

// Generic algorithm: extract underlying from any ~Escapable Carrier.
// The protocol declares `Underlying: ~Copyable & ~Escapable`, so the
// associated type already permits ~Escapable; no extra suppression needed
// at the use site. Lifetime: returned Underlying borrows from `c`.
// Note: returning Underlying as a function result requires Underlying to be
// Copyable so the result can be propagated as a copy. The protocol's
// Underlying is `~Copyable & ~Escapable`, so generic algorithms returning
// `C.Underlying` MUST add `where C.Underlying: Copyable` (which is how
// callers like Span<UInt8> participate — Span is Copyable).
@_lifetime(borrow c)
func extractUnderlying<C: Carrier & ~Escapable>(
    _ c: borrowing C
) -> C.Underlying where C.Underlying: Copyable {
    c.underlying
}

// Constrained generic: API accepting any Carrier of Span<UInt8>.
// Returns Int (Escapable) — no @_lifetime annotation.
func describeAsBytes<C: Carrier & ~Escapable>(
    _ c: borrowing C
) -> Int where C.Underlying == Span<UInt8> {
    c.underlying.count
}

// MARK: - V3 exercise

func runV3() {
    let bytes: [UInt8] = [1, 2, 3, 4, 5]
    bytes.withUnsafeBufferPointer { buffer in
        let span = Span<UInt8>(_unsafeElements: buffer)

        // Generic dispatch through Carrier.
        let extracted = extractUnderlying(span)
        print("V3 extract: count=\(extracted.count)")

        // Constrained generic.
        let count = describeAsBytes(span)
        print("V3 describeAsBytes: \(count)")

        // Carrier-shaped init.
        let rebuilt = Span<UInt8>(extracted)
        print("V3 init(_:): count=\(rebuilt.count)")
    }
}

runV3()
print("V3 complete")
