// MARK: - Modularization Compile-Time Impact
// Purpose: Measure clean/incremental/consumer build wall time across target-count N
//          for swift-standard-library-extensions.
// Hypothesis: Incremental build under N ≈ 87 is ≥ 10× faster than N = 1; clean build
//             under N ≈ 87 is 1.5–4× slower in debug, narrowing in release. See
//             Research/modularization-compile-time-impact.md for the full six-part
//             hypothesis set.
//
// Toolchain: swift-6.3.1 (2026-04-17)
// Platform: macOS 26 (arm64)
// Status: PARTIAL — endpoints measured post-relocation.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         N=1 debug clean: 1.54s median (5 samples).
//         N=79 strict (zero intra-deps, no Core, no special cases) debug clean: 4.73s median (5 samples).
//         Ratio: ~3.07× — mid-band of predicted 1.5–4×.
//         Refactor complete: Bool.swift self-containment fix, Array.Builder.swift split +
//         inlined delegation, @inlinable sweep (49 additions / 19 files), format subsystem
//         relocated to swift-format-primitives (Format.Case, Format.Case.Insensitive,
//         StringProtocol.formatted(_:), String.caseInsensitive). 556/556 tests pass on
//         swift-standard-library-extensions; 39/39 on swift-format-primitives.
//         See Outputs/report.md and swift-format-primitives/Research/case-formatting-placement.md.
// Date: 2026-04-22
//
// Execution: See EXPERIMENT.md. This executable target exists only to satisfy
// experiment-process [EXP-003d] naming alignment. The measurement harness is
// in scripts/, partition descriptors in partitions/, generated packages in
// variants/ (gitignored), results in Outputs/ (gitignored).

print("modularization-compile-time harness. Run via scripts/run-sample.sh; see EXPERIMENT.md.")
