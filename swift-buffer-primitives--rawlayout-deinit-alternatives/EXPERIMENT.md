# @_rawLayout Deinit Alternatives Investigation

<!--
---
status: CONFIRMED (viable alternatives documented)
date: 2026-03-21
toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
consolidation_of:
  - swift-storage-primitives/Experiments/discard-self-availability/
  - swift-storage-primitives/Experiments/deinit-guard-idempotence/
  - swift-storage-primitives/Experiments/escapable-deinit-lifetime/
  - swift-buffer-primitives/Experiments/slab-deinit-workaround/
supports: release-crash-resolution-handoff.md, inline-deinit-ownership.md, escapable-deinit-lifetime.md
---
-->

## Question

What workaround patterns exist for the @_rawLayout + deinit compiler bugs? Can cleanup be expressed without explicit `deinit`?

## Summary

Four alternative approaches to the standard `deinit` pattern were investigated. Each addresses a different aspect of the constraint triangle:

1. **`discard self`** — Cannot be used with @_rawLayout types (not trivially destructible)
2. **Guard idempotence** — Reference-type guards enable idempotent cleanup from non-mutating functions
3. **Escapable lifetime** — `@_unsafeNonescapableResult` on `get` accessor enables ~Escapable values in deinit
4. **Slab bitmap cleanup** — MoveOnlyChecker crash workaround: extract Copyable view to local variable

### Key Finding

The `discard self` approach (Candidate C from the resolution handoff) is blocked because @_rawLayout types are NOT trivially destructible. The guard idempotence and escapable lifetime patterns are viable workarounds for specific sub-problems but don't eliminate the need for `deinit` itself. The current production workaround is `-Xfrontend -disable-llvm-verify` + `-Xfrontend -disable-sil-ownership-verifier`.

## Variants

| Variant | Tests | Expected | Actual | Supports |
|---------|-------|----------|--------|----------|
| V01-discard-self | `discard self` with various storage types (10 variants) | @_rawLayout compatible | REFUTED — @_rawLayout not trivially destructible | Eliminates discard self as workaround |
| V02-guard-idempotence | Reference-type guard for idempotent cleanup (6 variants) | Idempotent cleanup possible | CONFIRMED — dedicated guard class works | Option for preventing double-free |
| V03-escapable-lifetime | ~Escapable values in deinit (18 variants) | _read accessor in deinit | CONFIRMED — get + @_unsafeNonescapableResult | Property.View accessor pattern |
| V04-slab-bitmap-cleanup | MoveOnlyChecker crash in forEach closure | Extract Ones.View to local | CONFIRMED — breaks borrow chain | Slab.Inline deinit fix |

## Build Protocol

```bash
swift build --target "V01-discard-self"
swift run V01-discard-self
swift build --target "V02-guard-idempotence"
swift run V02-guard-idempotence
swift build --target "V03-escapable-lifetime"
swift run V03-escapable-lifetime
# V04 is documentation-only (cannot reproduce outside production context)
```

## Cross-References

- [inline-deinit-ownership.md](../../../swift-storage-primitives/Research/inline-deinit-ownership.md)
- [escapable-deinit-lifetime.md](../../../swift-storage-primitives/Research/escapable-deinit-lifetime.md)
- [inline-deinitialize-state-reset.md](../../../swift-storage-primitives/Research/inline-deinitialize-state-reset.md)
- [rawlayout-llvm-verifier-crash](../rawlayout-llvm-verifier-crash/) — Bug 1 (LLVM verifier)
- [rawlayout-sil-ownership-crash](../rawlayout-sil-ownership-crash/) — Bug 2 (SIL ownership)
