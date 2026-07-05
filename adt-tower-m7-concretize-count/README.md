# adt-tower-m7-concretize-count

Fresh compiling re-verification of the **M7 seam amendment** to the ADT tower's
observability seam `Buffer.Protocol` (`__BufferProtocol`), per
`Research/adt-tower.md` §4.2 ([DS-025]/[DS-026], RATIFIED 2026-07-03,
SPIKE-GATED → GREEN). Reproduces the lost scratch spike `m7-concretize-count`
from spec.

## Claim under test (M7)

The seam currently declares `associatedtype Count: Carrier.`Protocol`<Cardinal>`
and vends `count: Count`; op extensions then need a reach-through pin
`S.Count == Index<S.Element>.Count`. M7 amends the seam:

- **DELETE** `associatedtype Count`.
- Vend the **concrete** `count: Index<Element>.Count`. `Element: ~Copyable`
  becomes the seam's **only** associated type.
- The `isEmpty` default becomes **unconstrained** (`count == .zero`) — it compiles
  because the concrete `Index<Element>.Count` (= `Tagged<Element, Cardinal>`)
  surfaces both `==` and `.zero`, resolving §3 **W18**.
- Conformers whose native occupancy is **Bit-domain** (slab-like) re-tag via the
  in-tree `.retag(Element.self)` idiom (phantom-label change, numerically sound).
- A conformer returning a Bit-domain count **without** retag must be **REJECTED**
  by the compiler (the constraint is load-bearing).

## Verdict: **CONFIRMED**

| Gate | Result | Receipt |
|---|---|---|
| `swift build` (debug) | zero errors | `Outputs/build.txt` |
| `swift build -c release` | zero errors | `Outputs/release-mode-pass.txt` |
| `swift run` | output sane | `Outputs/run.txt` |
| Negative control REJECTED | compile fails with the expected type mismatch | `Outputs/negative-control.txt` |
| Cross-module ([EXP-017]) | executable → Witnesses → SeamKit | `Outputs/cross-module-pass.txt` |
| Dep-surface secondary win | holds under strict imports | see below |

**Toolchain:** `swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)` — Target `arm64-apple-macosx26.0` (matches `swift --version` verbatim).

## Six-conformer ↔ production-shape mapping

| # | Witness (this experiment) | Native count domain | `count` derivation | Production shape modeled |
|---|---|---|---|---|
| a | `Linear`       | element | stored `Index<Int>.Count` verbatim | dense Linear / Aligned / Unbounded / Arena |
| b | `Ring`         | element | derived `tail − head` from typed cursors | Ring (occupancy = cursor distance) |
| c | `SlabStatic`   | **Bit** | `occupancy.retag(Element.self)` | `Buffer.Slab` (bitmap-popcount `Bit.Index.Count`) |
| d | `SlabBounded`  | **Bit** | `occupancy.retag(Element.self)` | `Buffer.Slab.Bounded` |
| e | `SlabSmall`    | **Bit** | `occupancy.retag(Element.self)` | `Buffer.Slab.Small` (inline slots) |
| f | `Generational` | element | stored `Index<Int>.Count` verbatim | slot-map / generational (already element-domain) |

The real slab family stores occupancy as `Bit.Index.Count` in
`Buffer.Slab.Header` (`bitmap.popcount`); its constructor already retags
capacity (`Buffer.Slab+Operations.swift:20`, `.retag(Bit.self)`). The three slab
witnesses here mirror that ledger and apply the inverse retag at the `count`
witness, exactly as the M7 conformer cost prescribes.

Runtime observation (`Outputs/run.txt`) — every conformer dispatched through the
generic seam consumer:

```
Linear(4)      : count=4 isEmpty=false
Linear(empty)  : count=0 isEmpty=true
Ring[2,7)      : count=5 isEmpty=false
Ring(empty)    : count=0 isEmpty=true
SlabStatic(3)  : count=3 isEmpty=false
SlabBounded(5) : count=5 isEmpty=false
SlabSmall(0)   : count=0 isEmpty=true
Generational(9): count=9 isEmpty=false
```

`SlabSmall(0) → isEmpty=true` is the load-bearing datum: the **unconstrained**
`isEmpty` default (`count == .zero`) fires on a **retagged** slab count — the
exact W18 case that pre-M7 forced every sparse conformer to hand-roll `isEmpty`.

## Negative control — the constraint is load-bearing

`Probes/negative-control.swift` (NOT a build target) declares a slab-like witness
that returns its Bit-domain occupancy with **no** retag. Compiled manually via
`run-negative-control.sh` (swiftc against the built modules). It is correctly
**REJECTED**:

```
Probes/negative-control.swift:33:9: error: cannot convert return expression of type
'Bit.Index.Count' (aka 'Tagged<Bit, Cardinal>') to return type 'Index<Int>.Count'
(aka 'Tagged<Int, Cardinal>')
   note: arguments to generic parameter 'Tag' ('Bit' and 'Int') are expected to be equal
```

A conformer therefore cannot silently mis-report a Bit-domain count as an
element count — the phantom tag on the concrete `Count` is enforced.

## Dep-surface secondary win — CONFIRMED (strict)

The M7 doc claims deleting the `Count: Carrier.`Protocol`<Cardinal>` bound removes
`swift-buffer-protocol-primitives`' direct imports of `Carrier_Protocol` and
`Cardinal_Primitive` — `.zero`/`==` still resolve via `Index_Primitives`'
`@_exported` re-exports. Here `SeamKit`:

- depends on **only** `Index Primitives` (not cardinal/carrier packages),
- imports **only** `Index_Primitives`,
- is built with `InternalImportsByDefault` + `MemberImportVisibility` (the strict
  regime the production seam ships under),

and compiles clean. `.zero` (from `Carrier.`Protocol` where `Underlying == Cardinal`,
in `Cardinal_Carrier_Primitives`) and `==` (Tagged's `Equatable`, in
`Tagged_Primitives`) both resolve transitively through `Index_Primitives`'
re-export chain — **the claim holds even under `MemberImportVisibility`.**

## Boundary statement ([EXP-020])

> **This experiment proves the DESIGN (concretized seam + real atomic-type
> packages). It does NOT prove the production seam change: W1.7 additionally
> requires the same green reproduced against the REAL slab / slot-map /
> generational packages before the seam change lands. Design-proven, not
> production-proven.**

The replica seam is a faithful transcription of `__BufferProtocol`'s M7 shape
against the identical atomic type layer (`Index<Element>.Count = Tagged<Element,
Cardinal>`, `.retag`, `.zero`, `==`), but the conformers are minimal stand-ins
([EXP-004]) for the production `Buffer.Slab*` / slot-map / generational types, not
those types themselves.

## Layout

```
Package.swift                                   3 targets, path-deps to real packages
Sources/SeamKit/__M7BufferProtocol.swift        concretized replica seam + isEmpty default
Sources/Witnesses/{Linear,Ring,SlabStatic,      six conformers (one type per file)
                   SlabBounded,SlabSmall,Generational}.swift
Sources/adt-tower-m7-concretize-count/main.swift  cross-module consumer + [EXP-003b] header
Probes/negative-control.swift                   non-target; MUST fail to compile
run-negative-control.sh                         swiftc driver for the probe
Outputs/                                         build / release / run / negative-control / cross-module receipts
```
