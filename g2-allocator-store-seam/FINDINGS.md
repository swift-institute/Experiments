# G2 Allocator/Store-Seam — Findings

**Question.** Can the typed `Store.\`Protocol\`` seam (swift-store-primitives)
absorb the two allocator disciplines — a fixed-slot **Pool** (free-list) and a
bump **Arena** — or must they stay raw `Memory.Allocator.\`Protocol\``? This
decides how allocators relate to the typed `Buffer<Storage<…>>` tower (the "G2
seam").

**Toolchain.** Built with `TOOLCHAINS=org.swift.64202605271a` (Apple Swift 6.5-dev,
the snapshot with `~Escapable Hashable`). Swift 6 language mode + the ecosystem
upcoming/experimental feature set, `.strictMemorySafety()`.

**Method.** Three probes built FRESH over raw `Memory.Contiguous<Byte>` (not by
depending on the existing `Storage.Pool`/`Storage.Arena`, so the seam stress is
observed directly rather than inherited). Each probe carries an in-file
`// FINDING:` block. Probe 1 is also exercised at runtime (`g2-seam-run`).

**Build status.**

| Probe | What | Compiles | Runs |
|-------|------|----------|------|
| 1 | `G2.Pool<Element: ~Copyable>` : `Store.\`Protocol\`` | **YES** | **YES** — round-trips `[100,101,102,100,200]`, sparse, no UB |
| 1b | `Storage.Contiguous<G2.Pool<Node>>` (dense-over-sparse) | **YES** (via faithful local replica†) | YES (one-slot path) |
| 2 | `G2.Arena` (bump) : `Store.\`Protocol\`` | **NO** — genuine non-conformer, error preserved | n/a |
| 3 | `G2.Arena` : `Memory.Allocator.\`Protocol\`` (raw baseline) | **YES** | YES — `bump(8)` returns an address |

† Probe 1b cannot depend on the real `swift-storage-primitives`: its
`Storage Protocol Primitives` target does **not compile** under this toolchain (an
unrelated upstream `~Copyable`-ownership skew — full error in
`Probe1b.DenseOverSparse.swift`'s `#if false` block). The probe replicates
`Storage.Contiguous`'s generic constraint verbatim to answer (d). Ground rules
forbid editing the real package.

---

## (a) Does Pool fit `Store.\`Protocol\`` cleanly?

**Mostly yes for the slot mechanics; but the seam is NOT self-sufficient for a
pool.**

All four requirements have natural, direct witnesses over the carved byte region:
`capacity` is the slot count; `subscript(slot:)` / `initialize(at:)` / `move(at:)`
are per-slot, random-access, typed — which is *exactly* a pool's access shape, so
the four verbs map 1:1 with zero impedance. The `_read`/`_modify` idiom transfers
verbatim from the heap conformer. `Element: ~Copyable` flows straight through (raw
bytes never demand `BitwiseCopyable`). The runtime driver confirms a sparse
allocate/init/read/move/free interleaving round-trips and `deinit` cleans up
exactly the live slots — no UB.

**The forced part — the sparse-occupancy crux.** Store's *model* is a **dense**
store: the `subscript` precondition is "the slot must be initialized," and the
derived traversals (`forEach`/`reduce`/`contains` in `Store.Protocol+Sequence.swift`)
explicitly require *every* slot in `[0, capacity)` to be initialized. A pool's
defining feature is the opposite — **sparse** occupancy, free slots interspersed
with live ones. The seam gives the conformer **no place to record or answer "is
slot i initialized?"**, so two things must live **out-of-band**, invisible through
`Store.\`Protocol\``:

1. the **free-list** (the allocation oracle), and
2. the **occupancy bitset** (the init oracle that `deinit` and safe subscripting
   need).

The one ledger the seam *does* ship, `Store.Initialization`, is a **≤2-range** view
(`.empty` / `.one(range)` / `.two(first,second)`). A pool's live set is an
*arbitrary* subset of slots — inexpressible as ≤2 contiguous ranges the moment any
interior slot is freed. So a pool can only honestly vend `.empty`. **This is
exactly what the real `Storage.Pool` does** — confirmed in
`swift-storage-pool-primitives/.../Storage.Pool+Store.Protocol.swift`, which vends
`.empty` with the comment "the ≤2-range `Storage.Initialization` view cannot
express it."

Finally, **allocation cannot be modeled by Store at all**: `allocate()` returns an
*uninitialized* slot, then the seam initializes it — two surfaces, two steps. Store
has no allocation verb.

**Verdict:** Pool *conforms* cleanly (the typed slot surface is genuinely natural),
but the conformance is a **partial view**: it exposes the slot mechanics and hides
the allocation/occupancy discipline that makes a pool a pool. The pool needs an
out-of-band occupancy oracle to be correct.

## (b) Does Arena fit `Store.\`Protocol\``?

**No — a genuine bump arena cannot conform without ceasing to be a bump arena.**

Probe 2's `#if false` block preserves the real compiler error. The *first*
unsatisfiable requirement is the associated type itself:

```
error: type 'G2.Arena' does not conform to protocol '__StoreProtocol'
note: protocol requires nested type 'Element'
  2 | associatedtype Element : ~Copyable
```

Every requirement is meaningless for a bump cursor:

- **`Element`** — a bump arena is element-**agnostic**: it bumps raw bytes for
  allocations of many, variable-size, possibly heterogeneous types. There is no
  single `Element` to bind. (Picking `Byte` is a lie — you cannot read a 4 KB
  struct back through `subscript(slot:) -> Byte`.)
- **`capacity: Index<Element>.Count`** — an arena's capacity is **bytes**; how many
  `Element`s fit is undefined under variable-size allocation. `bytes / stride` is a
  fiction the instant you bump something of a different size.
- **`subscript(slot: Index<Element>)`** — `Index<Element>` is an **ordinal**
  coordinate implying **fixed stride** (slot k at `base + k*stride`). A bump arena
  has no fixed stride and no "k-th Element" — allocation k may be 3 bytes, k+1 may
  be 4 KB. Random ordinal access is undefined.
- **`initialize(at:)` / `move(at:)`** — no addressable slot to target; and a bump
  arena has **no per-allocation reclamation** (it reclaims only en masse), so
  `move(at:)` (init → uninit, ownership out) has no counterpart.

To force *any* conformance you must destroy the bump discipline and rebuild it as a
fixed-stride slot pool with an occupancy oracle — i.e. Probe 1's Pool minus reuse.
**This is precisely what the real ecosystem did:** `Storage.Arena` is documented as
a fixed-slot SoA (meta array + element array, addressed `_elementRegionOffset +
slot*stride`, generation tokens). The raw `Memory.Arena` bump cursor is **demoted to
a byte-region provider underneath**; the typed `subscript(slot:)` addresses fixed
slots, not bump output. **The bump semantics do not survive the lift; only the
byte-backing role does.**

## (c) Is there a Pool-vs-Arena asymmetry?

**Yes, a sharp one. Pool-fits / Arena-doesn't.**

| | Pool | Arena (bump) |
|---|---|---|
| Access shape | per-slot, fixed-stride, random | sequential, variable-size, cursor |
| Maps to Store's `subscript(slot:)`? | **Yes** (1:1) | **No** (no fixed slot) |
| Has a single `Element`? | Yes | **No** (heterogeneous) |
| Per-element reclamation? | Yes (free-list) | **No** (en-masse only) |
| `Store.\`Protocol\`` conformance | compiles & runs | **cannot be written** |
| Natural seam | typed Store **or** raw | **raw only** |

The asymmetry is structural: **Store is a typed, fixed-stride, random-access,
per-slot, single-element contract.** A pool *is* that (its sparsity is the only
friction, handled out-of-band). A bump arena is the categorical opposite on every
axis. Probe 3 confirms the positive counterpoint — the *same* arena that cannot be
a Store conforms to raw `Memory.Allocator.\`Protocol\`` trivially (a near-identity
wrap of its `bump`), mirroring the real `Memory.Arena`'s raw-allocator conformance
with a no-op `deallocate`.

## (d) Does `Storage.Contiguous<Pool>` make sense (dense-over-sparse)?

**It type-checks but is semantically unsound — a category error the compiler can't
catch.**

`Storage.Contiguous<Substrate: Store.\`Protocol\` & ~Copyable> where
Substrate.Element == Element` accepts `G2.Pool<Node>`: the bound has no axis on
which to reject a sparse substrate (Probe 1b proves the type-check with a verbatim
replica of the real constraint). But `Storage.Contiguous` is **the dense
single-plane storage**: it forwards the four ops unchanged and its derived
traversals assume `[0, capacity)` all-initialized; sparsity is meant to be layered
**above** by a Buffer occupancy discipline, never **below** by the substrate.

Wrapping a sparse pool in the dense plane **erases** the free-list/occupancy truth
(out-of-band in the pool) while **asserting** the dense contract upward. Two
incompatible occupancy models are now stacked with no reconciliation; any dense
consumer reading or tearing down `[0, capacity)` touches uninitialized pool slots →
UB. **This is exactly why the real ecosystem does *not* model a pool as
`Storage.Contiguous<pool>`:** `Storage.Pool` is its *own* sparse single-region
discipline conforming to `Store.\`Protocol\`` directly (occupancy in its own
bitmap). The dense `Storage.Contiguous` wrapper is reserved for genuinely-dense
substrates (`Memory.Heap`, `Memory.Contiguous`).

So: a pool can **be** a `Store.\`Protocol\``, but must **not** be dressed as a dense
`Storage.Contiguous`.

## (e) Recommendation (with evidence)

**Mixed seam: Pool typed (`Store.\`Protocol\``), Arena raw
(`Memory.Allocator.\`Protocol\``).**

Evidence:

- **Pool → typed Store** is sound and the slot surface is genuinely natural
  (Probe 1 compiles *and* runs with sparse occupancy, no UB). The one cost — an
  out-of-band occupancy oracle and `Store.Initialization == .empty` — is real but
  contained, and is already the accepted shape of the production `Storage.Pool`. The
  payoff is a single centralized typed slot surface vs. `assumingMemoryBound(to:)`
  smeared across every raw call site.
- **Arena → raw allocator** is the *only* honest option: the typed Store
  conformance **cannot be written** (Probe 2's preserved compiler error), whereas
  the raw conformance is a near-identity wrap (Probe 3 compiles & runs). Forcing
  Arena into Store requires rebuilding it as a slot pool — at which point it is no
  longer a bump arena.
- A **uniform-typed-Store** recommendation is refuted by Probe 2 (Arena can't
  conform). A **both-raw** recommendation needlessly discards the working, natural,
  safer typed slot surface that Pool genuinely supports (Probe 1).

This matches what the ecosystem converged on independently: a *fixed-slot* pool
discipline sits on the typed Store seam; the *bump* allocator sits on the raw
`Memory.Allocator` seam and is only ever *recast* into a fixed-slot SoA (a
different type) when a typed slot surface is needed.

### One-line seam recommendation

> **Pool conforms to the typed `Store.\`Protocol\`` (with an out-of-band occupancy
> oracle); a bump Arena stays raw `Memory.Allocator.\`Protocol\`` — the Store seam
> is fixed-stride/per-slot/single-element and a bump arena is none of those.**

---

## Side findings

1. **Upstream non-compiler under the required toolchain.**
   `swift-storage-primitives`'s `Storage Protocol Primitives` target fails to build
   under `org.swift.64202605271a`:
   `Store.Protocol+Sequence.swift:100/103: error: parameter of noncopyable type
   'Self.Element' must specify ownership` (a `~Copyable` closure parameter
   `candidate: Element` needs `borrowing` on 6.5-dev; the package declares
   tools-version 6.3.1). Blocks any dependant of `Storage Contiguous Primitives` on
   this toolchain until the upstream source adds the ownership annotation. Reported
   here, not fixed (experiment is standalone).

2. **`Memory.Contiguous<Byte>` is a read-only owner.** Its pointer is `internal
   let`, `unsafeBaseAddress` is `UnsafePointer`, and it exposes no mutation API. To
   carve mutable typed slots both probes re-derive a mutable pointer via
   `UnsafeMutableRawPointer(mutating:)` on the documented `unsafeBaseAddress` escape
   hatch. Worth noting if `Memory.Contiguous` is meant to back mutable typed slot
   stores directly — a mutable variant (or a `withUnsafeMutableBytes`) would remove
   the escape-hatch detour.

3. **The seam confirms the dense assumption in its own derivations.**
   `Store.Protocol+Sequence.swift` documents "every slot in `[0, capacity)` must be
   initialized" as a precondition on its generic traversals — independent textual
   evidence that `Store.\`Protocol\`` is a *dense* contract, which is the root of
   both the Pool sparse-occupancy friction (a) and the dense-over-sparse unsoundness
   (d).
