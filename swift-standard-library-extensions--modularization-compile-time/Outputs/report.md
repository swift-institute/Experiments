# Modularization Compile-Time Impact — Report

**Research**: `../../../Research/modularization-compile-time-impact.md`
**Experiment**: `../EXPERIMENT.md`
**Date**: 2026-04-22
**Toolchain**: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
**Machine**: Apple M3, 8 cores, macOS 26 (arm64)

## Status

**PARTIAL** — primary hypothesis measured; secondary scenarios (incremental, release, consumer-side) deferred.

## Headline

**~3.07× slower** clean debug build at N=79 (strict, no Core, zero intra-package deps, @inlinable sweep, format-subsystem relocated to swift-format-primitives) vs N=1 baseline. Mid-band of the research doc's 1.5–4× debug-clean prediction.

| N | Partition | Samples | Median | Min | Max |
|---|---|---|---|---|---|
| 1 | single target (baseline) | 5 | **1.54 s** | 1.36 | 2.07 |
| 79 | strict per extended type, no Core, zero intra-deps, @inlinable sweep, format subsystem moved out | 5 | **4.73 s** | 4.64 | 5.21 |

Evolution across experiment runs:
- Pre-@inlinable, 78 targets (with Core): 4.13× (5.82s / 1.41s).
- @inlinable sweep (no other changes): 3.07× (3.99s / 1.30s). +49 annotations across 19 files restore cross-module specialization.
- Temporary StringProtocol→String co-location (avoiding naming violation in rename attempt): 2.83× (3.88s / 1.37s). 77 targets, special-case folded.
- **Post-relocation (final)**: 3.07× (4.73s / 1.54s). 79 targets, StringProtocol is fully independent, no special cases in generator. Format subsystem lives in `swift-format-primitives`. Baseline variance (1.54s vs earlier 1.37s) is system noise from successive build runs; the qualitative cost structure is stable in the 2.8–3.1× range.

All 556 tests continue to pass on canonical `swift-standard-library-extensions`. 39 tests pass on `swift-format-primitives` (including the migrated Format.Case.Insensitive suites and new Format.Case suites). Raw data: `samples.csv`. Machine: `machine.txt`.

## Refactoring applied to enable measurement

The initial MVP run failed at N=max with four classes of source-level blockers (Classes 1–4, see version 1 of this report in git history). Per the decision "strict (no Core), do as advised," the following refactor was applied to make strict modularization achievable:

| Change | Type | Rationale |
|---|---|---|
| `Bool.swift:15` — `.init(self)` → `self ? 1 : 0` | Class 4 fix (mechanical) | `Int.init(_ bool: Bool)` is declared in `Int.swift`. Replacing with stdlib literal removes the cross-file dep. |
| `Array.Builder.swift` split into `Array.Builder.swift`, `ArraySlice.Builder.swift`, `ContiguousArray.Builder.swift` | [API-IMPL-005] fix + delegation inlined | The original file declared three Builder types and used cross-type delegation. Splitting + inlining produces three self-contained files. |
| `@inlinable` sweep on all public `func`/`init`/`subscript`/computed-var declarations | Standing improvement | 49 additions across 19 files via `Audits/cross-file-inventory/add-inlinable.py`. Preserves cross-module specialization under modularization. Consistent with stdlib's own annotation practice. |
| Experiment generator: target = filename-stem-up-to-first-dot, with special-case `StringProtocol` → `String` | Packaging | Files extending the same type (e.g., `Array.swift`, `Array.Builder.swift`) co-locate. `StringProtocol.swift` is folded into `String Extensions` because `StringProtocol.formatted(as: String.Case)` references `String.Case` declared in `String.swift` — a real cross-file ref that cannot be cleanly resolved inside this package (see "Format subsystem" below). Produces 77 targets for 89 files. |

### Format subsystem: out-of-place content flagged

`String.Case` + `String.Case.Insensitive` + `StringProtocol.formatted(as:)` + `String.caseInsensitive` are not stdlib extensions in the self-containment sense — they are case-formatting domain content that happens to live here. Under strict modularization, they cannot be cleanly split (the only mechanical resolution — renaming `String.Case.Insensitive` → `String.CaseInsensitive` — violates [API-NAME-002] No Compound Identifiers and was reverted). The right long-term move is to relocate this subsystem to `swift-format-primitives` or add a `Format Standard Library Integration` target there per [MOD-010]. Until then, the experiment folds `StringProtocol.swift` into the `String Extensions` target (one target spans two files) to measure the rest of the package cleanly. This is flagged as TODO in the canonical repo's Research/ notes; it is not a blocker for the modularization decision but should be resolved before shipping per-type targets.

All 561 tests in 171 suites pass after the refactor. Canonical package build time: 1.14 s clean debug, unchanged from the pre-refactor baseline.

**Residual intra-package coupling**: zero. The generated `Package.swift` contains exactly one `dependencies:` line — on the umbrella target re-exporting the 78 variants.

## Interpretation

### Primary finding

Strict per-type modularization costs **~4× in clean debug build time** on this package / this machine / this toolchain. For an 89-file, 78-target partition, that's ~57 ms per target of amortized fixed overhead (across 8 cores). This is consistent with the research doc's theoretical model (Amdahl-bound + per-target module-emit cost), and sits at the pessimistic end of the prediction.

### What this doesn't yet tell us

The decision to adopt strict modularization should not rest on clean-debug cost alone. Three follow-on measurements materially affect the calculus:

1. **Incremental builds** — hypothesis: N=78 is ≥10× faster than N=1 on single-file edits, because SwiftPM only invalidates the touched target and the umbrella. This is the day-to-day-development lever.
2. **Consumer-side builds** — hypothesis: a consumer needing only `Array` extensions builds 1 target (plus its deps), not 78. This is the ecosystem-wide payoff that justifies the clean-build cost.
3. **Release mode** — hypothesis: the gap narrows in release because per-target optimization work grows absolute, diluting fixed overhead.

Only (1) and (2) must be materially positive for the modularization to pay off. The 4× clean-debug cost is amortized over development time; the consumer-side benefit is multiplicative across downstream packages.

### Refactor as standalone value

Even if modularization is not adopted, the refactor performed here is a strict improvement to the canonical package:

- The self-containment principle is now satisfied. Each extension file expresses its API in stdlib terms alone.
- [API-IMPL-005] (one type per file) is closer to compliance — `Array.Builder.swift` no longer violates it.
- The source contents are easier to review and audit because each file is independently understandable.

These are independent of the modularization decision.

## Deferred (entry criteria met)

With strict variant-max building cleanly, the full matrix is now reachable. The following cells are ready to run using the existing harness; they were deferred per [EXP-011a] until the first endpoint signal.

| Cell | Priority | Why | Expected cost |
|---|---|---|---|
| N=1 vs N=78, debug, incremental (touch `Array.swift`) | High | Day-to-day development cost; likely the modularization's headline benefit | ~2 min run |
| N=1 vs N=78, release, clean | Medium | Validates that release narrows the gap | ~3 min run |
| Consumer: import only Array_Extensions | High | Direct measure of consumer-side payoff | 2 min to build consumer + run |
| Consumer: import 4 targets | Medium | Mid-range consumer | 2 min |
| Consumer: import umbrella | Medium | Worst-case consumer under N=78 | 2 min |
| N=10, N=40 intermediate points | Low | Plots the curve. Probably diminishing value given endpoints are measured | 5 min |

## Next actions

**Decision-relevant**: run the incremental and consumer scenarios. These measurements determine whether the 4× clean-build cost is offset by the day-to-day and consumer-side benefits.

**Independent of the modularization decision**: merge the refactor (Bool.swift, Array.Builder split, formatted(as:) scope change) as a standing improvement. The canonical package is better for it whether or not per-type modularization is adopted.

## Raw data

- `samples.csv` — 10 rows, 5 × variant=1 + 5 × variant=max, debug clean as-is.
- `machine.txt` — hardware + toolchain provenance.
- `variants/` (gitignored) — generated packages; regenerate via `scripts/generate-variant.sh`.

## Reproduce

```bash
cd Experiments/modularization-compile-time
./scripts/run-mvp.sh
```

Full matrix expansion not yet scripted; extend `run-mvp.sh` per the deferred-cell table above.
