//
// Purpose: Empirically verify whether the @Witness macro propagates generic
//   struct parameters into synthesized members (init, unimplemented(), Calls,
//   Observe, etc.).
// Hypothesis: REFUTED — the macro does NOT propagate generic parameters. The
//   generated members reference the generic type name as if it were in scope,
//   but the synthesis does not declare the generic parameter on the new
//   extensions/types. Compilation is expected to fail with a diagnostic about
//   undeclared generic parameter or unrelated-type mismatch.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING — if this experiment COMPILES, the hypothesis is REFUTED
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//   in the opposite direction (the macro DOES handle generics, which would
//   be a pleasant surprise). If it fails to compile, record the diagnostic
//   verbatim in the Result section of EXPERIMENT.md.
// Date: 2026-04-17
//

public import Witnesses

// Try a generic @Witness struct. If the macro propagates <LeafError>, this
// compiles. If not, the generated init / unimplemented() / Calls / Observe
// members fail to reference LeafError and the build breaks.
//
// Migrated from Sendable-based isolation to region-based isolation:
//   * Removed `: Sendable` on the leaf error — not needed; region transfer suffices.
//   * Removed `& Sendable` from LeafError generic constraint — only the
//     `Error` capability is required of the leaf type.
//   * Removed `: Sendable` from IO — closure storage is the only
//     concurrency-relevant field; consumers transfer via `sending`.
//   * Removed `@Sendable` from the closure type — region isolation
//     replaces closure-attribute Sendability.
@Witness
public struct IO<LeafError: Error> {
    let op: () async throws(LeafError) -> Int
}
