# @_rawLayout SIL Ownership Crash and Enum _modify Investigation

> **SUPERSEDED (2026-03-22)**: Bug 2 (CopyPropagation) root cause identified and fixed. The `~Escapable` + `@_lifetime(borrow)` combination on Property.View generated `mark_dependence` instructions classified as `PointerEscape`, causing CopyPropagation to produce double `end_lifetime`. Fix: removed `~Escapable` from Property.View. All `@_optimize(none)` annotations removed. Standalone reproducer: `../copypropagation-nonescapable-mark-dependence/`. The enum _modify limitation (V02-V03) remains current.

<!--
---
status: SUPERSEDED (Bug 2 fixed; enum _modify limitation remains)
date: 2026-03-21
toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
consolidation_of:
  - swift-buffer-primitives/Experiments/copy-propagation-noncopyable-enum/
  - swift-buffer-primitives/Experiments/noncopyable-enum-modify/
  - swift-buffer-primitives/Experiments/small-enum-modify-recovery/
supports: release-mode-llvm-verifier-crash-diagnosis.md, small-buffer-enum-compiler-workarounds.md
---
-->

## Question

Under what conditions do @_rawLayout types trigger SIL ownership crashes, and what are the limits of `_modify` on ~Copyable enum payloads?

## Summary

Two related issues in the SIL optimization pipeline:

**Bug 2: SIL Ownership Crash** — `@_rawLayout` types in serialized SIL trigger CopyPropagation pass → "Found ownership error?!" signal 6. Pre-existing bug, affects downstream modules regardless of deinit presence. Was masked by the LLVM verifier crash (Bug 1) preventing Core from building.

**Language Limitation: Enum _modify** — Swift cannot yield mutable references into ~Copyable enum payloads. Optional gets special compiler support via `unchecked_take_enum_data_addr` (single-payload optimization). Multi-payload enums lack this, making zero-cost `_modify` into enum cases impossible. This affects `Buffer.*.Small._Representation` which uses `case inline(Inline) | case heap(Heap)`.

### Workaround

`-Xfrontend -disable-sil-ownership-verifier` on all targets (release only) suppresses Bug 2. For enum _modify: heap case recoverable via let-binding pointer bypass; inline case must spill to heap first.

## Variants

| Variant | Tests | Expected | Actual | Supports |
|---------|-------|----------|--------|----------|
| V01-copy-propagation | CopyPropagation crash with ~Copyable enum switch | Crash in production | REFUTED in isolation | Context-sensitive per [EXP-004a] |
| V02-enum-modify | _modify into ~Copyable enum payloads (8 variants) | Cannot yield &payload | CONFIRMED — language limitation | Compiler source analysis |
| V03-enum-modify-recovery | Recovery strategies: heap pointer bypass, inline spill | Heap recoverable | CONFIRMED — heap _modify works | DiagnoseStaticExclusivity fix |

### New Session Findings (2026-03-20)

1. **SIL ownership crash is pre-existing**: Happens WITH all 4 Inline deinits intact. Not caused by removing deinits. Was masked by the LLVM verifier crash preventing Core from building.
2. **Adding deinit to Small types causes 85+ errors**: "cannot partially consume 'self' when it has a deinitializer" — breaks all consuming methods in the Small buffer types.

### Investigation Findings (2026-03-21)

3. **Bug 2 does NOT reproduce in isolation**: 7 standalone patterns tried (see `rawlayout-minimal-reproducer/`), including ~Escapable views with @_lifetime coroutines, ~Copyable enum consuming patterns, bitmap-conditional moves, and @_rawLayout dependency chains. None triggered the crash. Bug 2 is strictly context-sensitive per [EXP-004a].
4. **Property.View attribution was investigated and rejected**: SIL examination showed `end_lifetime`/`store ... to [init]` conflicts on Property.View.Typed values in Ring.arrayLiteral and Slab.Small.drain. However, source code review confirmed these functions do NOT use Property.View in the attributed way. The SIL patterns are correlated effects of the @_rawLayout + serialized SIL interaction, not the root cause. The original diagnosis (@_rawLayout in serialized SIL) remains correct.
5. **Affected modules (3 of 12)**: Ring Primitives, Ring Inline Primitives, Slab Inline Primitives. Other 9 downstream modules unaffected. The pattern appears to involve @inlinable functions that trigger generic specialization through the @_rawLayout type paths, but the exact discriminator between affected and unaffected modules is not isolated.
6. **Removing @inlinable does not help**: WMO (-whole-module-optimization) still optimizes all functions in the module, so removing @inlinable does not prevent CopyPropagation from processing them.
7. **@_transparent not applicable**: The crashing functions (arrayLiteral with loops, drain with enum switches) are too complex for mandatory inlining.
8. **@_optimize(none) is unbounded whack-a-mole**: Annotating crashing functions causes new functions to crash as the optimizer shifts its attention.
9. **AnyObject? workaround does NOT fix Bug 2**: Adding `_deinitWorkaround: AnyObject? = nil` to all 4 Inline types (to force non-trivial destructibility) and suppressing Bug 1 with `-disable-llvm-verify` on Core only — Bug 2 still crashes in Buffer Ring Primitives. The triviality classification change does not affect the SIL ownership verifier's handling of @_rawLayout types.
10. **Bug 2 is fully independent of Bug 1's workaround**: Every mitigation tested for Bug 1 (AnyObject?, field count changes, @inlinable removal) has zero effect on Bug 2. The two bugs share the same root cause (@_rawLayout cross-module mishandling) but manifest in different compiler passes (LLVM IR vs SIL) and require separate flags to suppress.

## Build Protocol

```bash
rm -rf .build
swift build -c release --target "V01-copy-propagation"
swift build --target "V02-enum-modify"      # debug only (tests compile behavior)
swift build --target "V03-enum-modify-recovery"
swift run V03-enum-modify-recovery          # runtime verification
```

## Cross-References

- [release-mode-llvm-verifier-crash-diagnosis.md](../../Research/release-mode-llvm-verifier-crash-diagnosis.md)
- [small-buffer-enum-compiler-workarounds.md](../../Research/small-buffer-enum-compiler-workarounds.md) — Bug 2 and 3 documented here
- [rawlayout-llvm-verifier-crash](../rawlayout-llvm-verifier-crash/) — Bug 1 (LLVM verifier)
- [rawlayout-deinit-alternatives](../rawlayout-deinit-alternatives/) — Workaround exploration
- [rawlayout-minimal-reproducer](../rawlayout-minimal-reproducer/) — Bug 2 reproduction attempts (7 patterns, all REFUTED)
