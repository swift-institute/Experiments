# Path Operator Overload Resolution — Results

<!--
---
version: 1.0.0
last_updated: 2026-03-19
status: COMPLETE
tier: 2
---
-->

## Context

Chained `/` with 6+ string literals reportedly caused a type-checker timeout when `Path` had two `/` operator overloads (plus a `Path / String` overload). The concern was exponential overload resolution from `@_disfavoredOverload` on chained binary operators with multiple `ExpressibleByStringLiteral` types.

**Toolchain**: Swift 6.2.4 (swiftlang-6.2.4.1.4)

## Experiment Design

Standalone package with a minimal reproduction of `Path` and `Path.Component`, both conforming to `ExpressibleByStringLiteral` and `ExpressibleByStringInterpolation`. Five configurations tested:

| Configuration | Operators | `@_disfavoredOverload` | Path literal |
|--------------|-----------|----------------------|--------------|
| **Baseline** | `/ Component`, `/ Path` | Yes (on `/ Path`) | Yes |
| **Variant A** | `/ Component`, `/ Path`, `/ String` | Yes (on `/ Path` and `/ String`) | Yes |
| **Variant B** | `/ Component` only | N/A | Yes |
| **Variant C** | `/ Component`, `/ Path` | Yes (on `/ Path`) | **No** |
| **Variant D** | `/ Component`, `/ Path`, `/ String` | **No** | Yes |

Chain lengths tested: 2, 3, 4, 5, 6, 7, 8, 10, 12, 15.

Measurement: `-Xfrontend -warn-long-expression-type-checking=1` (1ms threshold — reports any expression taking ≥1ms).

## Results

### Type-Checking Times (chain expression only, excluding `#expect` macro)

| Chain Length | Baseline | Variant A | Variant B | Variant C | Variant D |
|-------------|----------|-----------|-----------|-----------|-----------|
| 2 | 1ms | 1ms | 1ms | 1ms | <1ms |
| 3 | <1ms | <1ms | — | — | <1ms |
| 4 | 1ms | 2ms | 1ms | 1ms | <1ms |
| 5 | 1ms | 1ms | — | — | <1ms |
| 6 | 1ms | 1ms | 1ms | 1ms | <1ms |
| 7 | 1ms | 1ms | — | — | <1ms |
| 8 | 1ms | 2ms | 1ms | 1ms | <1ms |
| 10 | <1ms | 1ms | 1ms | 1ms | <1ms |
| 12 | 1ms | 1ms | — | — | <1ms |
| 15 | 2ms | 1ms | 1ms | 2ms | <1ms |

All 48 tests pass across all configurations.

### Real swift-paths + swift-file-system Verification

Compiled the actual production code with `-warn-long-expression-type-checking=1`:

| Target | Warnings |
|--------|----------|
| `Paths Tests` (58 tests) | **0** |
| `File System Primitives Tests` | **0** |
| `File System Tests` (709 tests across both) | **0** |

Zero type-checking warnings from any chained `/` expression in the real codebase, even at the 1ms threshold.

### String Interpolation

Interpolation chains (`p / "\(i)" / "\(i+1)"` etc.) type-check identically to plain literal chains — 1ms for 4 and 6 chains. `ExpressibleByStringInterpolation` on `Path.Component` resolves without additional overhead.

### Type-Annotated Results

Adding `let r: Path = ...` did not measurably change type-checking time. The solver already infers `Path` from the operator return type — annotating the variable provides no additional constraint propagation benefit.

## Analysis

### No Exponential Blowup Observed

The theoretical concern was that N chained `/` with K overloads would explore K^N combinations. In practice, Swift 6.2.4's constraint solver handles this efficiently:

1. **Left-to-right evaluation**: Chained binary operators are parsed left-to-right. Each sub-expression `(Path / literal)` resolves independently — the solver doesn't need to consider all N literals simultaneously.

2. **`@_disfavoredOverload` effectiveness**: When present, the solver tries the preferred overload first. If it succeeds (which it always does — `Path.Component: ExpressibleByStringLiteral`), the disfavored overload is never explored.

3. **Even without `@_disfavoredOverload`** (Variant D, 3 overloads), type-checking stays under 1ms for all chain lengths. The solver's specificity ranking naturally selects `String` > `Component` > `Path` for literal arguments.

### Why the Original Timeout Might Have Occurred

The original timeout may have been caused by:

1. **Older toolchain**: Swift's constraint solver has improved significantly in recent versions. Overload resolution scaling was specifically addressed in Swift 5.x/6.x iterations.

2. **Cross-module complexity**: Types imported from separate modules with complex conformance chains (Kernel_Primitives, Path_Primitives) could create additional solver work not captured by a single-module reproduction.

3. **Interaction with other expressions**: The timeout may have occurred when the chained `/` was embedded in a larger expression (e.g., passed directly to a function call or combined with other operators).

4. **Concurrent type variables**: If the chain was inside an untyped closure or combined with generic inference, the additional type variables could multiply the search space.

## Recommendation

### Current state is safe — no changes needed

The current operator configuration (`Path / Component` primary, `Path / Path` with `@_disfavoredOverload`) shows no type-checking degradation up to 15 chained `/` operations on Swift 6.2.4. The real production code confirms this with zero warnings.

### Evaluation of proposed options

| Option | Effect | Recommended? |
|--------|--------|-------------|
| **Option 1**: Remove `Path / Path` | Eliminates one overload. Would require `path.appending(otherPath)` for Path-to-Path joining. Only 2 call sites use it (1 test, 1 doc example). | **Not necessary** — the overload causes no measurable harm |
| **Option 2**: Remove `Path: ExpressibleByStringLiteral` | Reduces literal ambiguity to zero (only `Component` matches). Would break `let path: Path = "/Users/coen"` — used widely. | **Not recommended** — high breakage, no demonstrated benefit |
| **Option 3**: Type-annotate results | No measurable effect — the solver already infers the result type. | **No effect** — not useful as a mitigation |

### If the issue resurfaces

If a type-checker timeout is observed in the future with chained `/`:

1. **Identify the exact expression** — is the `/` chain embedded in a larger expression?
2. **Check for additional overloads** — are there `File / String` or `File.Directory / String` operators in scope that multiply the search space?
3. **Break the chain** — assign intermediate results to separate `let` bindings, not a loop. Each binding constrains the type and prevents combinatorial explosion.

## Call Sites That Would Break Per Option

### Option 1 (Remove `Path / Path`)

| File | Line | Expression | Fix |
|------|------|-----------|-----|
| `swift-paths/Tests/.../Path Tests.swift` | 169 | `dir / rel` (where `rel: Path`) | `dir.appending(rel)` |
| `swift-paths/Sources/.../Path.Operators.swift` | 38 | Doc example: `base / rel` | Update doc example |

### Option 2 (Remove `Path: ExpressibleByStringLiteral`)

Would break `let path: Path = "..."` patterns across:
- `swift-paths` tests (5+ sites)
- `swift-file-system` tests (100+ sites via test helper path literals)
- `swift-tests` (10+ sites)

Not enumerated individually due to high count and low practical value.

## Files

- `Sources/PathOverloadExperiment/Path.swift` — Faithful reproduction of Path + Component
- `Sources/PathOverloadExperiment/Variants.swift` — 4 variant configurations (A, B, C, D)
- `Tests/.../BaselineTests.swift` — Chains 2–15, interpolation, annotations, Path/Path
- `Tests/.../VariantATests.swift` — 3-overload (original scenario) chains 2–15
- `Tests/.../VariantBTests.swift` — Single-overload chains 2–15
- `Tests/.../VariantCTests.swift` — No-literal chains 2–15
- `Tests/.../VariantDTests.swift` — 3-overload no-disfavored chains 2–15
