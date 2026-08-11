# CopyPropagation mark_dependence ~Escapable Reproducer

<!--
---
status: CONFIRMED (bug reproduces) + CONFIRMED (fix validated)
date: 2026-03-22
toolchain: Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
supports: rawlayout-release-crash-investigation.md (Bug 2)
---
-->

## Question

What minimal structure triggers the SIL CopyPropagation "Found ownership error?!" crash (Bug 2), and what source-level fixes eliminate it?

## Summary

A 3-module package that reliably reproduces Bug 2. The crash is caused by `~Escapable` + `@_lifetime(borrow base)` on a view type yielded from a `_read` coroutine accessor. CopyPropagation generates double `end_lifetime` for the view value when used across control flow paths (if/else, try/catch).

### Root Cause

`~Escapable` + `@_lifetime(borrow base)` generates `mark_dependence` instructions in SIL. These are classified as `OperandOwnership::PointerEscape` by `OperandOwnership.cpp:699-720`. The `OSSACanonicalizeOwned` utility bails out on PointerEscape (line 216-219), and in deep `@inlinable` chains this partial bailout leaves SIL inconsistent — producing double `end_lifetime` for the same `~Copyable ~Escapable` value.

The compiler team has a TODO about this at `OSSACanonicalizeOwned.cpp:40-46`:
> "Canonicalization currently bails out if any uses of the def has OperandOwnership::PointerEscape. Once [...] mark_dependence is associated with an end_dependence, those will no longer be represented as PointerEscapes"

### Previous Reproduction Attempts

7 standalone patterns tried in `rawlayout-minimal-reproducer/` — all failed to trigger Bug 2. They tested general `~Copyable`, `@_rawLayout`, coroutine yield, and control flow patterns but **missed the specific `~Escapable` + `@_lifetime(borrow)` ingredient** that generates `mark_dependence`.

## Variants

| Variant | Change | Debug | Release | Supports |
|---------|--------|-------|---------|----------|
| V1 (baseline) | `~Copyable, ~Escapable` view + `@_lifetime(borrow)` + control flow | Builds | **CRASH**: double `end_lifetime` | Confirms Bug 2 mechanism |
| V2 | Remove `~Escapable` + `@_lifetime` from view types | Builds | **Builds** | Validates Fix A |
| V3 | Keep `~Escapable`, add `@_optimize(none)` on `_read` accessor | Builds | **Builds** | Validates Fix B |
| V4 | Keep `~Escapable`, add `@_optimize(none)` on `View.Typed.init` | Builds | **CRASH** | Confirms init-level insufficient |

### V1 Crash Signature

```
Begin Error in Function: '$s6Middle7WrapperVAARi_zrlE13clearAndCheckSiyF'
Found over consume?!
Value:   %7 = apply ... -> @lifetime(borrow 0) @owned View<Access, Container<Element>>.Typed<Element>
Consuming Users:
  end_lifetime %7 : $View<Access, Container<Element>>.Typed<Element> // id: %16
  end_lifetime %7 : $View<Access, Container<Element>>.Typed<Element> // id: %8
```

Pass #1257 `CopyPropagation` on `Wrapper.clearAndCheck()`.

## Applied Fix

**Fix A (root cause)** was applied to the production codebase:
1. Removed `~Escapable` from 7 Property.View struct declarations in swift-property-primitives
2. Removed `@_lifetime(borrow base)` from all Property.View inits
3. Removed `@_lifetime(&self)` from all Property.View extension methods (~61 files)
4. Removed all 149 `@_optimize(none)` Bug 2 annotations across 12 sub-repos
5. Inlined 4 extracted static methods in async-primitives back into closures
6. `swift build -c release` passes clean with zero workarounds

## Build Protocol

```bash
cd Experiments/copypropagation-nonescapable-mark-dependence
rm -rf .build && swift build -c release
# V1: signal 6 (CopyPropagation double end_lifetime)
# V2/V3: Build complete
```

## Cross-References

- [rawlayout-release-crash-investigation.md](../../Research/rawlayout-release-crash-investigation.md) — Authoritative Bug 1 + Bug 2 investigation
- [rawlayout-sil-ownership-crash/](../rawlayout-sil-ownership-crash/) — Prior Bug 2 experiments (SUPERSEDED for Bug 2)
- [rawlayout-minimal-reproducer/](../rawlayout-minimal-reproducer/) — Prior Bug 2 reproduction attempts (7 patterns, all REFUTED)
