# Nested Package Source Ownership — Experiment Results

<!--
---
version: 1.0.0
last_updated: 2026-03-13
status: CONFIRMED
hypothesis: SwiftPM allows parent to claim sources via explicit path inside a directory with its own Package.swift
---
-->

## Hypothesis

SwiftPM's "ignore directories with Package.swift" behavior applies only to automatic
discovery. A parent package with explicit `path: "Tests/Unit Tests"` can still compile
sources from within `Tests/` even when `Tests/Package.swift` exists.

## Setup

```
experiment/
  Package.swift              ← parent, exports Lib, testTarget path: "Tests/Unit Tests"
  Sources/Lib/Lib.swift
  Tests/
    Package.swift            ← nested, depends on parent's Lib product
    Unit Tests/
      UnitTest.swift         ← @Test func libGreets()
    Extended Tests/
      ExtendedTest.swift     ← @Test func libGreetsExtended()
```

**Parent Package.swift**: declares `Lib` as product + `Unit Tests` testTarget with
explicit `path: "Tests/Unit Tests"`.

**Nested Package.swift**: depends on parent (`path: ".."`), declares `Extended Tests`
testTarget with explicit `path: "Extended Tests"`.

## Results

| Command | Working Dir | Tests Found | Result |
|---------|------------|-------------|--------|
| `swift test` | `experiment/` | `libGreets()` (1 test) | PASS |
| `swift test` | `experiment/Tests/` | `libGreetsExtended()` (1 test) | PASS |

## Findings

1. **Explicit `path:` overrides automatic discovery**: The parent's test target at
   `Tests/Unit Tests/` compiles and runs correctly despite `Tests/Package.swift` existing.

2. **Complete isolation**: Each `swift test` invocation discovers only its own package's
   test targets. No cross-contamination.

3. **No source ownership conflict**: SwiftPM does not consider the entire `Tests/` directory
   as "owned" by the nested package. Each package claims only explicitly declared paths.

4. **Nested package depends on parent via `path: ".."`**: One level up (was `../..` in the
   `Tests/Testing/` pattern). Simpler relative paths.

5. **Parent must export products**: The nested package depends on the parent's products
   (not targets), so the parent must declare `products: [.library(name: "Lib", ...)]`.
   This is already the case for all ecosystem packages.

## Conclusion

**CONFIRMED**: Option B (Flatten to `Tests/Package.swift`) is viable. SwiftPM allows both
packages to coexist with explicit `path:` declarations. The flattened structure eliminates
the `Tests/Testing/Tests/` stutter and reduces snapshot path depth from 5 to 3 levels.

## Cross-References

- Research: [nested-testing-package-flattening.md](../../Research/nested-testing-package-flattening.md)
- Prior: [nested-testing-package-structure.md](../../Research/nested-testing-package-structure.md)
