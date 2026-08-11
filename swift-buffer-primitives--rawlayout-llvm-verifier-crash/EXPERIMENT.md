# @_rawLayout LLVM Verifier Crash Investigation

<!--
---
status: CONFIRMED (compiler bug)
date: 2026-03-21
toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
consolidation_of:
  - swift-buffer-primitives/Experiments/rawlayout-release-verifier-crash/
  - swift-storage-primitives/Experiments/rawlayout-deinit-investigation/
  - swift-storage-primitives/Experiments/rawlayout-deinit-incremental/
  - swift-storage-primitives/Experiments/rawlayout-deinit-crossmodule/
  - swift-storage-primitives/Experiments/rawlayout-wrapper-validation/
  - swift-storage-primitives/Experiments/rawlayout-noncopyable-elements/
  - swift-buffer-primitives/Experiments/cross-module-type-declaration/
supports: release-mode-llvm-verifier-crash-diagnosis.md (Steps 1-8)
---
-->

## Question

Under what conditions does `~Copyable` struct + `@_rawLayout` stored field + explicit `deinit` crash the LLVM verifier under `-O` optimization?

## Summary

The crash requires the **combination** of: (1) `~Copyable` struct with `@_rawLayout` stored field(s), (2) explicit `deinit` block, (3) `-O` optimization, (4) cross-module usage where a consumer stores 2+ fields of the @_rawLayout type.

**UPDATE 2026-03-21**: A standalone minimal reproducer now EXISTS — see `rawlayout-minimal-reproducer/`. The bug reproduces with a 3-module chain (Core → Middleware → Consumer) when the middleware stores 2+ fields of the @_rawLayout type. The earlier claim that "standalone reproducers do NOT crash" was incorrect for the cross-module 2-field pattern.

### Constraint Triangle (from diagnosis Steps 6-8)

1. **Struct-body threshold**: In the defining module, ≤2 types with `@_rawLayout` + `deinit` in the parent struct body → OK. 3+ → crash.
2. **Extension-file pattern**: Types via `extension` in separate files (or same file) → even 1 type crashes.
3. **Cross-module boundary**: Types extending a parent from a DIFFERENT module → even 1 type in struct-body crashes. Struct-body threshold only holds within the defining module.

### Workaround

`-Xfrontend -disable-llvm-verify` on Core target + `-Xfrontend -disable-sil-ownership-verifier` on all targets (release only). 391 tests pass.

## Variants

| Variant | Tests | Expected | Actual | Supports |
|---------|-------|----------|--------|----------|
| V01-baseline | Minimal @_rawLayout + deinit types, standalone | No crash | No crash (REFUTED in isolation) | Step 5: standalone doesn't reproduce |
| V02-struct-body-threshold | 1, 2, 3 types in struct body with real deps | ≤2 OK, 3+ crash | Cannot reproduce standalone | Step 6: struct-body ≤2 threshold |
| V03-extension-file | Types via extension, same or separate files | Even 1 crashes | Cannot reproduce standalone | Step 6: extension-file pattern |
| V04-cross-module | Types in separate module extending parent | Even 1 crashes | Cannot reproduce standalone | Step 8: cross-module boundary |
| V05-class-ref-interaction | Storage.Heap (class) + @_rawLayout in same type | Interaction with crash | Cannot reproduce standalone | New finding: Ring.Inline blocked by class ref |
| V06-wrapper-patterns | _Fields wrapper, single-field wrapper | Wrapper doesn't help | No crash standalone | Step 6: field count irrelevant in extension-file |
| V07-noncopyable-elements | @_rawLayout with ~Copyable elements | Works fine | CONFIRMED — works | Eliminates ~Copyable elements as cause |
| V08-storage-inline-deinit | Real Storage.Inline from pre-compiled package | Deinit not called | CONFIRMED — deinit skipped | Compiler bug: pre-compiled @_rawLayout deinit |

### New Session Findings (2026-03-20)

1. **Storage Primitives Core threshold 0**: Even 1 @_rawLayout+deinit in struct-body (within Buffer's enum body) crashes when sufficient cross-module SIL exists. Tested empirically in production.
2. **Class-ref interaction**: Ring.Inline can't be in Ring's struct body because Ring stores Storage.Heap (class ref). Slab/Arena CAN host Inline because their storage types aren't class-based.
3. **Same-file extension = extension-file**: Defining Ring.Inline via `extension Buffer.Ring { }` in Buffer.swift (same file) still crashes. The compiler treats ALL extensions identically regardless of file.
4. **`-disable-llvm-verify` + `-disable-sil-ownership-verifier`**: The combination suppresses both bugs. 391 tests pass.

### Minimal Reproducer Findings (2026-03-21)

A standalone reproducer for Bug 1 was found at `rawlayout-minimal-reproducer/`. Key discoveries:

1. **Cross-module threshold is 2 fields, not 3**: A struct in module B storing 2+ fields of an @_rawLayout+deinit type from module A crashes. Within-module threshold remains ≤2 types in struct body.
2. **@inlinable NOT required**: Neither on the core type's init nor the consumer struct. The crash is purely structural.
3. **Same type, different capacities crashes**: `Inline<8>` + `Inline<4>` of the same type triggers it. No need for distinct types.
4. **Crash is in the consumer module**: Bug1Middleware crashes, not Bug1Core. The @_rawLayout type metadata from Core is incorrectly lowered to LLVM IR when the consumer struct's destructor needs to destroy 2+ @_rawLayout fields.
5. **Minimal trigger**: Generic enum + @_rawLayout(likeArrayOf: Element, count: capacity) + value generic + deinit + 2+ fields cross-module + release mode. Removing ANY ONE prevents the crash.

### AnyObject? Workaround Test (2026-03-21)

The `_deinitWorkaround: AnyObject? = nil` pattern (from swiftlang/swift#86652) was tested on all 4 Inline types. It forces non-trivial destructibility classification, which fixes the **minimal reproducer** (consumer-module 2-field pattern). However, it does **NOT** fix the production crash:

| Configuration | Bug 1 (LLVM verifier) | Bug 2 (SIL ownership) |
|---------------|----------------------|----------------------|
| AnyObject? on 4 Inline types, NO flags | **Still crashes** (4 errors in Core) | Not reached |
| AnyObject? + `-disable-llvm-verify` on Core only | Suppressed by flag | **Still crashes** (Ring Primitives) |
| Original flags (both) + AnyObject? | Suppressed | Suppressed |

**Why it fails in production but works in the reproducer**: The minimal reproducer uses the consumer-module 2-field pattern (struct in module B stores 2+ fields from module A). The production code uses the extension-file pattern (types defined via `extension` in the defining module under WMO). These are different trigger paths. Adding `AnyObject?` changes the type's triviality classification but doesn't fix the LLVM IR lowering for extension-defined @_rawLayout+deinit types under WMO.

**Conclusion**: `AnyObject?` is NOT a viable workaround for the production crash. The `.unsafeFlags` remain the only working solution.

### Production Context

The experiment variants (V01-V08) are standalone packages that test individual patterns. The `rawlayout-minimal-reproducer/` captures the consumer-module 2-field trigger, but this is a DIFFERENT trigger path from production. The production crash (extension-file pattern under WMO) has no standalone reproducer — it requires the full Buffer Primitives Core module.

## Build Protocol

```bash
rm -rf .build                                    # REQUIRED — incremental builds give false results
swift build -c release --target "V01-baseline"   # Per-variant build
swift build -c release 2>&1 | grep -c "Instruction does not dominate"  # Count errors
```

## Cross-References

- [release-mode-llvm-verifier-crash-diagnosis.md](../../Research/release-mode-llvm-verifier-crash-diagnosis.md) — Full diagnosis (Steps 1-8)
- [release-crash-resolution-handoff.md](../../Research/release-crash-resolution-handoff.md) — Resolution handoff
- [rawlayout-sil-ownership-crash](../rawlayout-sil-ownership-crash/) — Bug 2 (SIL ownership)
- [rawlayout-deinit-alternatives](../rawlayout-deinit-alternatives/) — Workaround exploration
- [rawlayout-minimal-reproducer](../rawlayout-minimal-reproducer/) — Standalone reproducer (Bug 1 REPRODUCES, Bug 2 does not)
