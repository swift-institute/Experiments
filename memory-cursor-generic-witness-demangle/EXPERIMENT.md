# memory-cursor-generic-witness-demangle

Diagnoses the confirmed runtime crash in the Wave-1 memory→`Sequenceable` bridge on a
**generic** contiguous conformer:

```
failed to demangle witness for associated type 'Iterator' in conformance
'…Buffer.Linear.Inline<8>: Sequenceable'
→ swift_getAssociatedTypeWitnessSlowImpl → Sequenceable.collect()   (Signal 6)
```

- **Toolchains**: Apple Swift 6.3.2 (`swiftlang-6.3.2.1.108`) AND 6.4-dev (`LLVM a3655ee8d8c4d74`, `+assertions`).
- **Platform**: macOS 26 (arm64).
- **Date**: 2026-05-27.
- **Features**: `LifetimeDependence`, `Lifetimes`, `SuppressedAssociatedTypes` (the last is
  load-bearing — the institute `Sequenceable`/`Iterator.Protocol` declare `associatedtype
  Iterator: …, ~Copyable, ~Escapable`, which requires it).

## UPDATE 2026-05-28 — literal-topology REPRODUCED + RESHAPE FOUND

The 2026-05-27 verdict below ("not synthetically reproducible") **stands** — and was pushed
further: a faithful **3-module topology** reconstruction (target **E**: type module / ops
module / bridge-default module, plus doubly-nested value-generic `@_rawLayout` type, dual
`@_implements`, cross-module bridge-default witness, AND the span witness in the type module
while the `Memory.Contiguous` conformance is in the ops module) **also PASSES** (debug +
release). So even the one structural factor the original verdict flagged as un-reconstructed
does not fire synthetically.

To get a crashing baseline, a **principal-authorized transient-restore** of the crashing
`Memory.Cursor<Self>` Sequenceable conformance was applied to the **literal**
`Buffer.Linear.Inline` (2-file edit to `swift-buffer-linear-primitives`: Package.swift deps +
`Buffer.Linear.Inline+Sequence.Protocol.swift`), driven by target **F**. It **REPRODUCES**:

```
$ swift run F-literal-buffer-linear-exe           # DEBUG
failed to demangle witness for associated type 'Iterator' in conformance
'…Buffer<A>.Linear.Inline<8>: Sequenceable' from mangled name '}' - unknown error   # SIGABRT (134)
```

Two distinct failure modes were separated:
1. **DEBUG runtime demangle** (`mangled name '}'`, Signal 6 in `collect()`) — the
   `Memory.Cursor` generic-witness bug under investigation.
2. **RELEASE LLVM "Broken module" verifier ICE** — **AMBIENT to buffer-linear**: it fires at
   clean HEAD with the *production hand-written scalar* iterator too (verified by building the
   standalone `Buffer Linear Inline Primitives` target at HEAD, `-c release`). Almost certainly
   the documented `@_rawLayout`+deinit verifier issue (cf. swiftlang/swift#86652). NOT a
   `Memory.Cursor` problem; a Memory.Cursor reshape neither causes nor fixes it.

**The corrupt mangled name is literally the single byte `'}'`** — the runtime relative-pointer /
mangled-name accessor for the `Sequenceable.Iterator` associated-type witness resolves to a
truncated/garbage string. IRGen emits a corrupt associated-type-witness mangled name for the
**deep generic instantiation** `Memory.Cursor<Buffer<A>.Linear.Inline<8>>`.

### Reshape directions tested against F (the literal crash), hard-clean

| Reshape | Change | Result |
|---------|--------|--------|
| 1 | conform `Iterator.\`Protocol\`` **unconditionally** on the struct (vs conditional `extension … where Base: ~Copyable`) | **FAIL** — still `'}'` |
| 2 | **element-only-generic erased witness** `Memory.Snapshot.Cursor<Element>` (eager span→`[Element]` snapshot), vended by `makeSnapshotIterator()` | **PASS** — dodges (debug `[10,20,30]`; release `-disable-llvm-verify` `[10,20,30]`) |
| 3 | remove `@frozen` from `Memory.Cursor` | **FAIL** — still `'}'` |

**Reshape 2 is the working dodge.** Triangulation (1 & 3 fail, 2 passes) pins the trigger to the
**deep generic instantiation in the witness mangled name**: flattening the witness to an
Element-only-generic type (the conforming type absent from the witness's mangling) is the only
lever that works. Layout/`@frozen` and conditional-vs-unconditional conformance are NOT levers.
The reshape lives in `swift-memory-cursor-primitives` (`Memory.Snapshot.Cursor<Element>`,
`Memory.Snapshot.Cursor.swift`) + a `makeSnapshotIterator()` witness in
`swift-memory-sequence-primitives`. See
`swift-institute/Research/memory-cursor-generic-witness-demangle-reshape.md`.

**Trade-off**: the snapshot eagerly copies the span into one `[Element]` allocation up front
(vs the lazy cursor's per-`next()` re-derivation). For inline `@_rawLayout` conformers this is
the *only* safe element-only-generic shape (a lazy element-only iterator would dangle a pointer
into consumed inline storage). Adoption (replace vs alongside the lazy `Memory.Cursor`, final
name, and the separate ambient release ICE) is a principal decision.

> **All transient buffer-linear edits were fully reverted after capture** (`git checkout`;
> package clean at HEAD `dd9b8c2`). No production package was left altered. No commits.

---

## Original verdict (2026-05-27) — retained

**NEITHER cleanly demonstrated. The crash is NOT reproducible from any synthetic
reconstruction — single-pass result per [EXP-011a] / [ISSUE-013] / [ISSUE-025] /
ground-rule-5: the minimal repro needs a factor specific to the literal
`Buffer.Linear.Inline` type that cannot be isolated synthetically, and which the parallel
in-flight migration in `swift-buffer-linear-primitives` has now removed from that package's
working tree.**

The discriminating hand-rolled bare-generic case (target B) does **NOT** crash, which by the
brief's discriminator rules out a *general* generic-associated-type-witness compiler/runtime
bug. But every faithful institute-bridge reconstruction (targets A / C / D, including the
production-faithful module split, value generics, dual `@_implements`, `@_rawLayout` storage,
and the cross-module bridge-default witness) ALSO passes — so the crash is NOT explained by
`Memory.Cursor`'s shape alone either. The trigger is narrower than any structural factor
isolable outside buffer-linear.

## Result matrix — ALL PASS (debug + release, both toolchains)

| Target | Conformer shape | Module | Crash? |
|--------|-----------------|--------|--------|
| `B-handrolled-bare-generic` | hand-rolled minimal protocol + assoc-type + constrained-extension witness returning generic owned `Cursor<Self>`; ZERO institute deps | single | **no** |
| `C-institute-bridge-concrete` | concrete `Memory.ContiguousProtocol` conformer → `Memory.Cursor`, single `Sequenceable` | single | **no** |
| `A-institute-bridge-generic` | generic `Region<Element>` → `Memory.Cursor<Self>`, single `Sequenceable` | single | **no** |
| `A-xmodule-exe` (Region) | same, conformance in lib, `.collect()` in exe | **cross** | **no** |
| `A-xmodule-exe` (RegionVG) | value-generic `RegionVG<Element, let capacity: Int>` (capacity fixed=8 AND generic) | **cross** | **no** |
| `A-xmodule-exe` (RegionDual) | DUAL `Iterable, Sequenceable` + `@_implements` split (2 different generic Iterator witnesses) | **cross** | **no** |
| `A-xmodule-exe` (RegionBD) | relies on the **cross-module bridge-default** `makeIterator()` (no explicit one) — like the crashing conformer | **cross** | **no** |
| `D-real-buffer-linear-exe` | `@_rawLayout` `RawRegion<Element, let capacity: Int>` OWNING a real `Storage.Inline`; single `Sequenceable` | **cross** | **no** |
| `D-real-buffer-linear-exe` (dual) | `@_rawLayout` + value-generic + DUAL `@_implements` + cross-module — **highest-fidelity** reconstruction | **cross** | **no** |

Every isolable structural factor of `Buffer.Linear.Inline<8>: Sequenceable` — generic-ness,
value-generic capacity, `@_rawLayout` storage, dual conformance with `@_implements`,
cross-module conformance, cross-module bridge-default witness — was tested in isolation and in
the closest-achievable combination. None reproduce the Signal-6 demangle.

## What could NOT be built (the boundary)

The *literal* `Buffer.Linear.Inline: Sequenceable` could not be reconstructed because:

1. **The crashing shape no longer exists in buffer-linear's working tree.** When this
   investigation started, `Buffer.Linear.Inline+Sequence.Protocol.swift` (in the ops module
   `Buffer Linear Inline Primitives`) declared `extension Buffer.Linear.Inline: Iterable,
   Sequenceable` with `@_implements(Sequenceable, Iterator) typealias SequenceableIterator =
   Memory.Cursor<Self>`. A **parallel subordinate's in-flight migration** has since rewritten
   that file to `Iterable`-only, with a comment: *"Sequenceable-on-contiguous is DEFERRED
   behind a separate investigation: the generic contiguous Sequenceable path crashes at
   runtime (Signal-6 swift_getAssociatedTypeWitness demangle, clean-build-verified)."* The
   committed HEAD never had the `Sequenceable` bridge form — HEAD has an older hand-rolled
   `Sequence.Protocol` (borrowing) iterator with no `Memory.Cursor`.
2. **A retroactive `Sequenceable` on the real type hit a COMPILE-time collision** (not the
   runtime crash): because the working-tree migration already conforms the real type to
   `Iterable`, adding `Sequenceable` from a consumer module recreates the dual-conformance
   `Iterator`-unification, and the cross-module witness thunk resolves to `Iterable`'s
   *borrowing* `makeIterator` for the `Sequenceable` *consuming* requirement → "lifetime-
   dependent value escapes its scope" (demangled symbol confirmed: *protocol witness for
   `Sequenceable.makeIterator()` in conformance `Buffer.Linear.Inline : Sequenceable`*). This
   is an artifact of the in-flight migration's `Iterable` conformance colliding with a
   retroactive `Sequenceable`, NOT the verified runtime demangle. Per ground rules, buffer-
   linear was NOT edited to remove the collision.

The one structural property the synthetic `RawRegion` substitutes is buffer-linear's
**two-module type/ops split for a single type** (the type lives in `Buffer Linear Inline
Primitive` (singular); the `Memory.Contiguous` + `Sequenceable` conformances live in `Buffer
Linear Inline Primitives` (plural); the bridge default lives in a third module). The leading
remaining hypothesis is that the demangle failure is triggered by the witness thunk for a
generic conformer whose conformance, type, and protocol-extension-default witness are spread
across ≥3 modules with this specific topology — which the experiment's flat lib/exe split does
not replicate.

## If pursued further (NOT in this track's scope)

- Reconstruct buffer-linear's exact 3-module topology (type module / ops-conformance module /
  bridge module) for a synthetic `@_rawLayout` generic conformer, in a controlled experiment
  (not buffer-linear).
- OR, with the principal's coordination (the parallel migration owner), transiently restore
  the crashing dual `Iterable, Sequenceable` conformance on the real `Buffer.Linear.Inline`
  on a throwaway branch and confirm-then-reduce there. This is the only path that exercises
  the literal failing type; it MUST be coordinated because buffer-linear has uncommitted
  parallel work.

No `[ISSUE-*]` upstream writeup is warranted yet: there is no `swiftc`-reproducible (or even
SwiftPM-reproducible-outside-buffer-linear) reducer. Filing now would violate [ISSUE-002] /
[ISSUE-017] (no standalone reproducer) and [ISSUE-025] (synthetic-to-production extrapolation
without a verified failing baseline in the experiment).

## Files

- `Sources/A-institute-bridge-generic/` — single-module generic institute-bridge repro.
- `Sources/AConformerLib/` — generic conformers (`Region`, `RegionVG`, `RegionDual`,
  `RegionBD`) for the cross-module exe.
- `Sources/A-xmodule-exe/` — drives `.collect()` cross-module on all AConformerLib conformers.
- `Sources/B-handrolled-bare-generic/` — verdict discriminator (zero institute deps).
- `Sources/C-institute-bridge-concrete/` — concrete control.
- `Sources/D-real-buffer-linear-lib/` + `Sources/D-real-buffer-linear-exe/` — `@_rawLayout`
  conformer (owns a real `Storage.Inline`), single + dual `Sequenceable`, cross-module.
- `Sources/E-type-module/` + `Sources/E-ops-module/` + `Sources/E-xmodule-exe/` — **(2026-05-28)**
  faithful **3-module topology** reconstruction (type / ops / bridge-default split + span-witness-
  in-type-module). PASSES — the 3-module factor does not fire synthetically either.
- `Sources/F-literal-buffer-linear-exe/` — **(2026-05-28)** drives `.collect()` on the **literal**
  `Buffer.Linear.Inline` (real buffer-linear, transiently-restored crashing form). The only target
  that exercises the literal failing type; REPRODUCES the demangle (debug) and validates the
  reshape.
- `Outputs/F-literal-baseline-debug.txt`, `F-reshape-snapshot-cursor-{debug,release}.txt`,
  `E-3module-reconstruction-debug.txt`, `reshape-attempts-summary.txt` — **(2026-05-28)**.
