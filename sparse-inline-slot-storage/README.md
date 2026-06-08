# sparse-inline-slot-storage

**Status: VERIFIED (2026-06-07)** · Cleave-9 gate **G1**. Empirical bed for the seat's
ruling that the `@_rawLayout` forced-concrete `.Inline`/`.Small` leaves can be **deleted** in
favour of a uniform `Buffer<Storage.Contiguous<Memory.X>>` end-state, *if* a slot-backed
`Memory.Inline`/`Memory.Small` clears the four must-resolve risks.

Consolidates the `/tmp/cdspikes2` + `/tmp/cdexp` spikes from
`.handoffs/REPORT-conditional-deinit-inlinearray-reopener.md` into a durable, reproducible
package, and closes the two open items that report flagged (move-out; Embedded floor).

## Hypothesis

`InlineArray<N, Slot<Element>>` — where `enum Slot<E: ~Copyable> { case empty; case occupied(E) }`
is a self-cleaning slot — gives a uniform, conditionally-`Copyable`, generic sparse-inline buffer
with **no custom `deinit`**, sidestepping both walls:

- **Wall 1** (SE-0427 `copyable_illegal_deinit`): never reached — `InlineArray`'s *automatic*
  recursive teardown cleans each `Slot` (`.occupied` tears down its payload; `.empty` is a no-op),
  so no custom `deinit` is written.
- **Wall 2** (`swift#86652`, cross-module deinit skip): absent — no `@_rawLayout`, so no
  value-witness-triviality surface to misclassify.

## Results (all on the snapshot toolchain, `TOOLCHAINS=swift`; release)

| # | Risk (seat's G1) | Verdict | Evidence |
|---|---|---|---|
| i | **Embedded deployment floor** (load-bearing) | ✅ **PASS** | `./embedded-check.sh` compiles `SlotStorage` (incl. move-out) to `arm64-apple-none-macho`. The macOS-26 floor is an OS-shipped *dynamic*-stdlib artifact; Embedded statically links and works. |
| ii | move-out-of-`InlineArray` (`Store.Protocol.move(at:)`) | ✅ **PASS** | `Slab.move(_:)` via `swap(&values[i], &.empty)` returns the `~Copyable` element; `Demo` TEST 4 shows teardown deferred to the caller's drop. Compiles Embedded. |
| iii | Wall-2 cross-module teardown | ✅ **PASS** | `Demo` (module) drops `SlotStorage` types (module) → `deinit` fires across the boundary (`swift run`, TESTs 1/3/4). Corroborated by the 2-package `/tmp/cdexp`. |
| iv | per-family layout (free vs ~2× taxed) | ✅ **CONFIRMED** | `Demo` TEST 5: `LinkedNode<PtrElem/RefElem>`, `TreeNode<RefElem>` all **FREE** (16→16); only full-range `UInt64` taxed. Production sparse families store pointer/ref `~Copyable Node`s → free. |

Plus: generational O(1) insert/remove + use-after-free detection (TEST 3); conditional `Copyable`
with value semantics (TEST 2). One ergonomic tax: a `~Copyable` slot cannot be borrow-peeked, so
occupancy/validity is read from a trivial `Meta` side-array (standard slot-map design).

## The honest deployment-floor trade (for the seat)

Deleting the `@_rawLayout` leaf in favour of the slot-backed one is **not floor-free**:

- `@_rawLayout` is a compiler attribute — **no** stdlib/OS/toolchain floor.
- The slot-backed leaf needs `InlineArray` in the stdlib → **macOS 26+** against the dynamic
  stdlib, and a **snapshot toolchain** for Embedded (the embedded stdlib must ship `InlineArray`;
  released 6.3.2 ships no embedded stdlib at all — the ecosystem already builds Embedded on the
  `2026-03-16` snapshot, so this is not a *new* dependency, but it is a real floor).

So G1 PASSES the seat's stated bar (*"can it deploy on Embedded"* → **yes**), at the cost of an
`InlineArray` deployment floor that the `@_rawLayout` leaf does not carry. The
uniformity-vs-floor weighing is the seat's call.

## Reproduce

```bash
TOOLCHAINS=swift swift run        # TESTs 1–5 (runtime teardown, move-out, generational, layout)
./embedded-check.sh               # G1(i): compile to arm64-apple-none-macho (Embedded)
```

## References

- `.handoffs/REPORT-conditional-deinit-inlinearray-reopener.md` (the reopener; Results 1–4)
- `swift-institute/Research/conditional-deinit-conditionally-copyable-generics.md` (the two-wall analysis)
- Cleave-9 `.handoffs/GOAL-cleave-9-allocation-arc.md`, `.handoffs/cleave-9-PROGRESS.md`
