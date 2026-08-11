# escapable-heap-storage

**Purpose**: Investigate whether `Builtin.addressof` + `UnsafeMutableRawPointer.copyMemory` can replace `ManagedBuffer` for storing `~Escapable` elements in heap storage.

**Result**: BLOCKED — waiting for upstream `nonescapable-pointers` branch to land.

| Phase | Hypothesis | Result |
|-------|-----------|--------|
| 1 | Builtin.addressof works for ~Copyable (Escapable) types | CONFIRMED |
| 2a | Builtin.addressof on inout ~Escapable parameter | REFUTED |
| 2b | @unsafe suppresses lifetime-escape diagnostic | REFUTED |
| 2c | unsafeBitCast to Escapable tuple | REFUTED |
| 2d | @_unsafeNonescapableResult detach + addressof | REFUTED |
| 3 | Field-by-field storeBytes/load as alternative | CONFIRMED |
| 4 | Full lifecycle: store, read, borrow, mutate, take | CONFIRMED |
| 5a | @_lifetime(borrow self) on computed property | CONFIRMED |
| 5b | @_lifetime(borrow self) on borrowing method | CONFIRMED |
| 6 | ARC correctness with shared references | CONFIRMED |

## Key Finding

`Builtin.addressof` is categorically blocked for `~Escapable` values. The compiler treats it as an escape, which violates `~Escapable`'s scope confinement. This is enforced during SIL generation (not Sema) and cannot be suppressed by `@unsafe`, `@_unsafeNonescapableResult`, or `inout` parameters.

A field-by-field workaround exists but does not generalize — it requires compile-time knowledge of the type's field layout.

## Upstream Resolution: `nonescapable-pointers` Branch

The proper fix is in progress in `swiftlang/swift` on branch `origin/nonescapable-pointers` (Nate Cook, 2026-03-19, commit `885fa6e1f87`):

```diff
-public struct UnsafePointer<Pointee: ~Copyable>: Copyable { }
+public struct UnsafePointer<Pointee: ~Copyable & ~Escapable>: Copyable, ~Escapable { }
+extension UnsafePointer: Escapable where Pointee: ~Copyable & Escapable {}
```

Changes in the WIP:
- `UnsafePointer<Pointee: ~Copyable & ~Escapable>` — pointer itself becomes `~Escapable` when pointee is
- `Span<Element: ~Copyable & ~Escapable>` — Span gains `~Escapable` element support
- `assumingMemoryBound(to:)` accepts `~Escapable` (FIXME: uses `@_lifetime(immortal)`)
- `@_lifetime(copy self)` on `pointee` and subscript accessors
- `Strideable` conformance gated on `Escapable` (FIXME: uses `Builtin.gep_Word` workaround)

Once this lands, `Builtin.addressof` becomes unnecessary. The normal typed pointer APIs (`UnsafeMutablePointer<T: ~Escapable>`, `initializeMemory`, `assumingMemoryBound`) will work directly, and `Storage.Heap<Element: ~Escapable>` via `ManagedBuffer` becomes possible without workarounds.

**Decision**: Wait for `nonescapable-pointers` to land. Do not build a workaround layer.

**Toolchain**: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
**Date**: 2026-04-02
