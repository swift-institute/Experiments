# Experiment Validation Results

Date: 2026-03-21
Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2), arm64-apple-macosx26.0
Method: Clean build (`rm -rf .build`) before every individual target build.

---

## Experiment 1: rawlayout-llvm-verifier-crash

Path: `swift-buffer-primitives/Experiments/rawlayout-llvm-verifier-crash/`

| Target | Debug | Release | Error (if any) |
|--------|-------|---------|----------------|
| V01-baseline | PASS | PASS | -- |
| V02-struct-body-threshold | PASS | PASS | -- |
| V03-extension-file | PASS | PASS | -- |
| V04-cross-module | FAIL | FAIL | `'Container<Element>.Ring.Inline<capacity>' initializer is inaccessible due to 'internal' protection level` |
| V05-class-ref-interaction | PASS | PASS | -- |
| V06-wrapper-patterns | PASS | PASS | -- |
| V07-noncopyable-elements | PASS | PASS | -- |
| V08-storage-inline-deinit | FAIL | FAIL | `static property 'deinitCount' is not concurrency-safe because it is nonisolated global shared mutable state` [Swift 6 strict concurrency] |

### Documented vs Actual

| Variant | Documented Result | Build Outcome | Match? |
|---------|-------------------|---------------|--------|
| V01-baseline | No crash (REFUTED in isolation) | Builds clean, no crash | YES |
| V02-struct-body-threshold | Cannot reproduce standalone | Builds clean, no crash | YES |
| V03-extension-file | Cannot reproduce standalone | Builds clean, no crash | YES |
| V04-cross-module | Cannot reproduce standalone | Does not compile (visibility bug) | NO -- code defect prevents validation |
| V05-class-ref-interaction | Cannot reproduce standalone | Builds clean, no crash | YES |
| V06-wrapper-patterns | No crash standalone | Builds clean, no crash | YES |
| V07-noncopyable-elements | CONFIRMED -- works | Builds clean, no crash | YES |
| V08-storage-inline-deinit | CONFIRMED -- deinit skipped | Does not compile (concurrency safety) | NO -- code defect prevents validation |

### Notes

- **V04-cross-module**: The `Inline` type's synthesized `init()` is `internal` in the `V04-cross-module-core` module, but `main.swift` in `V04-cross-module` tries to call it across modules. The `init()` needs `public` access or a `@usableFromInline` annotation. This is a consolidation packaging error, not a compiler finding.
- **V08-storage-inline-deinit**: Swift 6 strict concurrency rejects `static var deinitCount` on a `Sendable` class. The `Marker` class needs `nonisolated(unsafe) static var deinitCount` or an `@MainActor` annotation. This is a Swift 6 migration issue in the experiment code.

---

## Experiment 2: rawlayout-sil-ownership-crash

Path: `swift-buffer-primitives/Experiments/rawlayout-sil-ownership-crash/`

| Target | Debug | Release | Error (if any) |
|--------|-------|---------|----------------|
| V01-copy-propagation-lib | PASS | PASS | -- |
| V01-copy-propagation | FAIL | FAIL | `instance method 'initialize(to:at:)' is internal and cannot be referenced from an '@inlinable' function`; `property cannot be declared public because its type uses an internal type`; `type referenced from a stored property in a '@frozen' struct must be '@usableFromInline' or public` |
| V02-enum-modify | PASS | PASS | -- |
| V03-enum-modify-recovery | PASS (warnings) | PASS (warnings) | Warnings only: `expression uses unsafe constructs but is not marked with 'unsafe'` [StrictMemorySafety] |

### Documented vs Actual

| Variant | Documented Result | Build Outcome | Match? |
|---------|-------------------|---------------|--------|
| V01-copy-propagation | REFUTED in isolation | Does not compile (visibility errors) | NO -- code defect prevents validation |
| V02-enum-modify | CONFIRMED -- language limitation | Builds clean in both modes | YES -- compiles successfully (the "confirmed" limitation is that certain _modify patterns are rejected by the compiler, which the variant documents via commented-out code and working alternatives) |
| V03-enum-modify-recovery | CONFIRMED -- heap _modify works | Builds clean in both modes | YES |

### Notes

- **V01-copy-propagation**: The library target (`V01-copy-propagation-lib`) builds fine. The consumer target fails because `@inlinable` functions in `main.swift` reference `internal` methods from the library, and `@frozen` structs expose `internal` types. The `Storage` type and its methods in the lib need `@usableFromInline` annotations. This is a cross-module visibility error in the experiment code, not the SIL crash the variant aims to test.

---

## Experiment 3: rawlayout-deinit-alternatives

Path: `swift-buffer-primitives/Experiments/rawlayout-deinit-alternatives/`

| Target | Debug | Release | Error (if any) |
|--------|-------|---------|----------------|
| V01-discard-self | PASS (warnings) | PASS (warnings) | Warnings only: `variable 'v' was never mutated; consider changing to 'let' constant` |
| V02-guard-idempotence | PASS | PASS | -- |
| V03-escapable-lifetime | FAIL | FAIL | `'@_unsafeNonescapableResult' attribute cannot be applied to this declaration` |
| V04-slab-bitmap-cleanup | N/A | N/A | Documentation-only variant (no source target) |

### Documented vs Actual

| Variant | Documented Result | Build Outcome | Match? |
|---------|-------------------|---------------|--------|
| V01-discard-self | REFUTED -- @_rawLayout not trivially destructible | Builds and compiles (warnings only) | YES -- the variant demonstrates which types CAN use `discard self` and which cannot |
| V02-guard-idempotence | CONFIRMED -- dedicated guard class works | Builds clean | YES |
| V03-escapable-lifetime | CONFIRMED -- get + @_unsafeNonescapableResult | Does not compile | NO -- `@_unsafeNonescapableResult` no longer accepted on computed property getters |
| V04-slab-bitmap-cleanup | CONFIRMED -- breaks borrow chain | No compilable target | N/A (documentation only) |

### Notes

- **V03-escapable-lifetime**: The `@_unsafeNonescapableResult` attribute is rejected on a computed property `var view: View { get { ... } }`. This suggests the attribute's applicability rules changed in Swift 6.2.4, or it was never valid on computed properties (only on function declarations). The documented finding may have been verified with a different syntax or earlier toolchain behavior.

---

## Summary

### Overall Build Status

| Experiment | Total Targets | Pass (both modes) | Fail | Doc-only |
|------------|---------------|--------------------|----- |----------|
| rawlayout-llvm-verifier-crash | 8 (+1 lib) | 6 | 2 | 0 |
| rawlayout-sil-ownership-crash | 4 (3 + 1 lib) | 3 (lib + V02 + V03) | 1 | 0 |
| rawlayout-deinit-alternatives | 4 (3 + 1 doc) | 2 | 1 | 1 |
| **Totals** | **16** | **11** | **4** | **1** |

### Documented Results Validation

| Status | Count | Variants |
|--------|-------|----------|
| Documented result matches build | 9 | V01-V03, V05-V07 (exp1); V02-V03 (exp2); V01-V02 (exp3) |
| Code defect prevents validation | 4 | V04, V08 (exp1); V01 (exp2); V03 (exp3) |
| Documentation-only, no build | 1 | V04 (exp3) |

### Defects Found

All 4 build failures are code-level defects in the experiment packaging, not compiler crashes:

1. **V04-cross-module (exp1)**: Missing `public` init on `Container.Ring.Inline` in the core module.
2. **V08-storage-inline-deinit (exp1)**: `static var deinitCount` on `Sendable` class rejected by Swift 6 strict concurrency.
3. **V01-copy-propagation (exp2)**: `@inlinable` functions reference `internal` methods across modules; `@frozen` struct exposes `internal` types.
4. **V03-escapable-lifetime (exp3)**: `@_unsafeNonescapableResult` not applicable to computed property declarations.

None of the successful builds produced LLVM verifier crashes or SIL ownership crashes, which is consistent with the documented finding that these bugs are context-sensitive and cannot be reproduced in standalone packages (per [EXP-004a]).
