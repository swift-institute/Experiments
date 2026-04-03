# nonsending-dispatch

Consolidated experiment package for `nonisolated(nonsending)` behavior across dispatch contexts.

## Coverage

| Variant | Origin | Topic | Status |
|---------|--------|-------|--------|
| V01 | nonsending-sendable-iterator | Sendable vs nonsending isolation boundary on stored closures | CONFIRMED |
| V02 | nonsending-clock-feasibility | NonsendingClock protocol with ImmediateClock isolation | CONFIRMED |
| V03 | nonsending-generic-dispatch | Nonsending propagation through generic/opaque dispatch | ALL PASSED |
| V04 | nonsending-method-annotation | callAsFunction nonsending vs deprecated isolation: parameter | ALL PASSED (T1-T7) |

## Key Findings

- **V01**: `nonisolated(nonsending)` on methods preserves caller isolation. Adding `@Sendable` to stored closures breaks isolation (makes the closure concurrent).
- **V02**: A `NonsendingClock` protocol refining `Clock` compiles and `ImmediateClock` preserves isolation with zero thread hop.
- **V03**: `nonisolated(nonsending)` propagates through all dispatch modes (direct, generic, opaque). No separate protocol needed.
- **V04**: `nonisolated(nonsending)` on `callAsFunction()` is a drop-in replacement for the deprecated `isolation:` parameter pattern.

## Swift Settings

Uses `NonisolatedNonsendingByDefault` feature flag (from V01).

## Consolidation

Per EXP-018. Absorbs 4 experiment packages into a single library target.
