# DRAFT — swiftlang/swift issue (NOT FILED)

> **Status: DRAFT. Do NOT file publicly.** Filing is a separate, principal-confirmed step
> (outward action). Before filing, complete the standalone-reduction follow-up (see
> "Reduction status" below) so the report carries a bare-`swiftc` reproducer — issues
> requiring a multi-package project to reproduce are deprioritized per the maintainers'
> triage ([ISSUE-017]).

---

**Title**: SIGSEGV in `DiagnoseStaticExclusivity` when a borrow (`Span`/`MutableSpan`/`_read`-view) is returned out of a `switch` over a `~Copyable` enum payload

**Classification**: ICE / Crash (compiler SIGSEGV)

**Environment**: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101), Xcode default toolchain, SDK MacOSX26.5, macOS 26 (arm64). Experimental features: `Lifetimes`. `-swift-version 6`.

**Command**: `swift build` (emit-module phase); equivalently `swiftc -emit-module -experimental-skip-non-inlinable-function-bodies-without-types …`

**Observed**:
```
error: emit-module command failed due to signal 11 (use -v to see invocation)
While running pass #N SILModuleTransform "DiagnoseStaticExclusivity".
4  swift-frontend  … (anonymous namespace)::DiagnoseStaticExclusivity::run() + 5000
```
The crash fires only for `@inlinable` accessors (it is in the emit-module path that
processes inlinable bodies; non-`@inlinable` accessors with the same body do not crash).

**Expected**: clean compilation, or a diagnostic — not a compiler SIGSEGV.

**Trigger (generalized)**: an `@inlinable` accessor that, inside a `switch` over a
`~Copyable` enum's payload, **returns a borrow obtained from the bound payload** — where
the borrow is a `Span`, a `MutableSpan`, or a `_read`/borrow-view projection. Two
observed shapes, same crash:

```swift
// Shape 1 — Span borrow delegated through the payload
var span: Span<Element> {
    @_lifetime(borrow self) @inlinable borrowing get {
        switch _storage {
        case .heap(let inner):  return inner.span   // SIGSEGV
        case .inline(let inner): return inner.span
        }
    }
}

// Shape 2 — _read borrow-VIEW projection delegated through the payload
// (`peek` is a `_read` accessor `yield View(self)`; `.front` returns a copy,
//  but the projection still borrows through the payload)
@inlinable var front: Element {
    switch base.value._storage {
    case .heap(let inner):  return inner.peek.front   // SIGSEGV
    case .inline(let inner): return inner.peek.front
    }
}
```

**Reduction status (context-sensitive — standalone reducer NOT YET isolated)**:
The minimal shape does NOT reproduce in isolation. Variants that compile cleanly:
- V1: concrete element type, non-inlinable getter, no `deinit`.
- V2: generic `<Element: ~Copyable>` + `@inlinable` getter.
- V3: V2 + `deinit` on the inner `~Copyable` type.

So `{~Copyable enum + Span-borrow delegation + generics + @inlinable + deinit}` alone is
insufficient. The reproduction requires additional structure from the production types
(`swift-buffer-linear-primitives` `Buffer.Linear.Small`): candidate missing ingredients —
(1) a class-backed `~Copyable` storage handle as the payload's field, (2) `@_rawLayout` on
the inline storage type, (3) the inner `.span` getter performing `_overrideLifetime(...)`,
(4) two-level delegation. Pre-filing TODO: add these one at a time over V3 ([ISSUE-013]/
[EXP-021]) until a bare-`swiftc` reproducer is isolated.

**Workaround in use** (downstream): route the borrow ops via package-scoped windows that
surface the inner base pointer, build the `Span`/`MutableSpan`/element **outside** the
`switch`, and mark those ops **non-`@inlinable`** (the package window is not
cross-package-inlinable; consumers reach them via a static call — no `witness_method`,
SIL acceptance preserved). Tracked in-source with `// TODO(C):` markers.

**Investigation artifacts**: `swift-buffer-linear-primitives/Experiments/small-span-diagnose-static-exclusivity-crash/` (this directory). Catalog: `swift-institute/Research/swift-compiler-bug-catalog.md` (Section A).
