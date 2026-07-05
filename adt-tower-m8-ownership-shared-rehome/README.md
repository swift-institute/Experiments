# adt-tower-m8-ownership-shared-rehome — [EXP-003d]

Re-verification (fresh compiling experiment) of the **M8 (W1.8) mechanism** from
`Research/adt-tower.md` §D4.5: re-homing the CoW column onto the `Ownership.Shared` name via a
cross-package namespace extension, plus pinning the **rename-first ordering constraint** the move
depends on. The prior session's scratch evidence was gone; this rebuilds it from source.

- **Toolchain:** `swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)` · `Target: arm64-apple-macosx26.0`
- **Platform:** macOS 26 (arm64)
- **Date:** 2026-07-05

## The design claim (M8, §D4.5)

W1.8 executes three coordinated moves: (a) the immutable ARC box `Ownership.Shared<Value>`
(`public final class Shared<Value: ~Copyable & Sendable>` in swift-ownership-primitives) is
renamed `Ownership.Immutable<Value>`, freeing the name; (b) the CoW column — today the top-level
`public struct Shared<Element, B>` in swift-shared-primitives, wrapping `Ownership.Box<B>` — moves
onto the freed name via a **cross-package** namespace extension
`extension Ownership { public struct Shared<Element, B> … }` declared from the column's own
package; (c) vocabulary re-points. This spike proves the **mechanism** compiles and behaves, and
pins the ordering constraint.

## H1 (positive) — cross-package re-home + runtime CoW — **CONFIRMED**

A faithful copy of the real CoW column source (`swift-shared-primitives/.../Shared.swift`,
`Shared+Unique.swift`, `Shared+Store.Protocol.swift`), re-homed as
`extension Ownership { public struct Rehomed<Element, B> }` (non-colliding name so H1 does not
trip H2), against the **real** swift-ownership-primitives (`Ownership` enum + `Ownership.Box`) and
the **real** storage / buffer / index / memory stack the column's conformances need:

- **Compiles debug AND release**, cross-module (`RehomeKit` → the executable), byte-identical
  output both configs. Receipts: `Outputs/build.txt`, `Outputs/release-mode-pass.txt`,
  `Outputs/run.txt`, `Outputs/cross-module-pass.txt`.
- **CoW semantics hold at runtime** over the real direct heap-linear column
  (`Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Linear`):

  ```
  a (initial): [10, 20, 30]                    · a.isUnique (sole owner): true
  after copy — same box: true                  · a.isUnique while shared: false · b.isUnique while shared: false
  after mutation — boxes diverged: true        · a.isUnique after divergence: true · b.isUnique after divergence: true
  a (unchanged): [10, 20, 30]                  · b (mutated): [10, 20, 30, 99]
  unique-handle in-place (box stable): true -> [1, 2]
  H1 VERDICT: CONFIRMED
  ```

  Two handles share the box until mutation (`_boxID` equal); mutation on the **non-unique** handle
  clones and diverges (`_boxID` differs, original unchanged); a **unique** handle mutates in place
  (`_boxID` stable). The run `precondition`s these, so a regression fails the run rather than the
  eye.

The mechanism — declaring a generic struct nested in another package's namespace enum via
`extension Ownership { public struct … }`, wrapping that package's `Ownership.Box`, and consuming
it across a module boundary — works exactly as §D4.5 asserts.

## H2 (negative / ordering) — the arity collision — **rename-first is compiler-forced at use sites**

Question: while the real 1-parameter `Ownership.Shared<Value>` box class still exists, what happens
if the 2-parameter `extension Ownership { public struct Shared<Element, B> {} }` is **also**
declared from another module? Redeclaration error, use-site ambiguity, or clean arity
disambiguation? Probe: a faithful 1-param box stub module + a 2-param struct module + a consumer
importing both (`Probes/`, driven by `Probes/drive-h2.sh`, captured verbatim to
`Outputs/h2-collision.txt`).

**Answer — two distinct behaviors:**

1. **Declaration coexists (no redeclaration error).** Building the 2-param struct module against
   the 1-param class module produces **zero diagnostics, exit 0** (probe steps 2 & 3). Cross-module,
   a same-named nested class and struct of different arity can both be declared. Arity is
   irrelevant to whether they may exist.

2. **Any type-level use site is ambiguous — and arity does NOT disambiguate.** A module importing
   **both** and naming `Ownership.Shared` at the type level fails (exit 1) with the verbatim
   diagnostic:

   ```
   error: ambiguous type name 'Shared' in 'Ownership'
   note: found candidate with type 'Ownership.Shared'   (the 1-param final class)
   note: found candidate with type 'Ownership.Shared'   (the 2-param struct)
   ```

   Critically, **both** `Ownership.Shared<Int>` (1 arg) **and** `Ownership.Shared<Int, Int>`
   (2 args) are flagged — type-name lookup collects all candidates *before* the generic argument
   list is considered, so the argument count cannot select between them. (The lone exception: an
   *initializer-expression* `Ownership.Shared(7)` / `Ownership.Shared<Int, Int>()` resolves via
   constructor overloading — but every type-annotation, metatype, generic-argument, conformance,
   or extension-target reference, which dominate real code, is ambiguous.)

**Ordering verdict:** **rename-first (M8(a)) is compiler-FORCED, not merely hygiene-driven** — but
the forcing lives at the *use site*, not the declaration boundary. The two `Ownership.Shared`
declarations can coexist in the tree in isolation; the moment any single module sees both, every
type-level reference to `Ownership.Shared` is a hard `ambiguous type name` error that arity will
not rescue. Because M8's entire purpose is to make `Ownership.Shared` *be* the 2-param column
under one visible namespace, the box's prior claim on the name must be vacated first: M8(a) (rename
the box → `Ownership.Immutable`) must land before M8(b) (move the column onto `Ownership.Shared`).
The diagnostic is `error: ambiguous type name 'Shared' in 'Ownership'`.

## [MEM-SAFE-028] — the drain-box is untouched

The re-homed struct **wraps** the real `Ownership.Box<B>` (swift-ownership-primitives) and never
reimplements the copy-on-write cell or its `Storage.deinit` drain. Element teardown stays owned by
`Ownership.Box`'s single audited drain-box home; each construction site here supplies the buffer's
own `removeAll`-class drain and (for Copyable elements) its `clone`, exactly as the real
`Shared+Unique.swift` does. The spike wraps the drain, it does not touch it.

## Boundary statement

This proves the **W1.8 mechanism** (cross-package namespace re-home over the real `Ownership.Box` +
real column stack) and the ordering constraint that governs it. Production W1.8 additionally
executes the real box rename (M8(a)), the real column move onto `Ownership.Shared` (M8(b)), the
`Column.Shared` re-point (M8(c)), and the ~45-site sweep across ~14 files (plus the
`swift-shared-primitives` → `swift-ownership-shared-primitives` basename rename ruled at §D4.5).
**This spike does not touch any of those packages** — it reproduces the mechanism and the compiler
behavior in an isolated experiment directory, under a non-colliding name (`Rehomed`), leaving the
real tower untouched.

## Layout

| Path | Role |
|------|------|
| `Sources/RehomeKit/Ownership.Rehomed.swift` | The cross-package re-home: `extension Ownership { public struct Rehomed<Element, B> }` + conditional `Copyable`/`Sendable`. |
| `Sources/RehomeKit/Ownership.Rehomed.Column.swift` | Pinned direct heap-linear column init (Copyable/`~Copyable` split), uniqueness gate, CoW-checked `append`/`removeLast`. |
| `Sources/RehomeKit/Ownership.Rehomed.Store.Protocol.swift` | The `Store.Protocol` / `Buffer.Protocol` seam conformances (full declared bounds, subscript, `prepareForMutation`). |
| `Sources/adt-tower-m8-ownership-shared-rehome/main.swift` | H1 runtime leg — cross-module CoW evidence ([EXP-017]). |
| `Probes/OwnershipBoxStub.swift` | Faithful 1-param `Ownership.Shared<Value>` box stand-in (mirrors the real declaration shape). |
| `Probes/h2-collision.swift` | The 2-param `extension Ownership { struct Shared<Element, B> }` — the M8(b)-before-M8(a) hazard. |
| `Probes/h2-usesite.swift` | Consumer importing both — the arity-ambiguity leg. |
| `Probes/drive-h2.sh` | Manual `swiftc` drive (kept off the package build). |
| `Outputs/` | `build.txt`, `release-mode-pass.txt`, `run.txt`, `cross-module-pass.txt`, `h2-collision.txt`. |
