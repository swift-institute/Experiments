# adt-tower-m11-iteration-0witness

Fresh compiling re-verification of the **M11 iteration contract** (design decision
**D9/Q9**) for the ADT tower, per `Research/adt-tower.md` §2 D9. Reproduces the lost
scratch spike `m11-iteration-0witness` from spec, against the REAL upstream Linear and
Ring columns (path-dep'd on their local `main` branches, exactly as the ratified
`adt-tower-worked-example` does — [EXP-020]).

## Claim under test (D9 / M11)

The ADT tier defines **no iteration of its own**. A tower container is iterable exactly
when its column vends borrowing iteration; iteration **flows from the column** as a
borrowing `forEach` lending `(borrowing Element)`, composed over the buffer tier and never
refined into the seams (D3). The guaranteed common surface is a **borrowing `forEach`** —
the one surface every occupancy discipline provides — and it must specialize to **zero
`witness_method`** cross-module, over a move-only element, for **both** disciplines:

- **Linear** ALSO vends the multipass `Iterable` protocol, element gate relaxed to
  `~Copyable` (`Buffer.Linear+Iterable.swift:22`) — plus its span-backed paths.
- **Ring** vends **ONLY** the bespoke single-pass borrowing `forEach`
  (`Buffer.Ring+forEach.swift`). Its multipass `Iterable` side was **active-pruned**
  (seat-ruled 2026-06-10, `Buffer.Ring+Sequence.Protocol.swift:11-17`).

Concretely: a cross-module `-O` client over a move-only `Job: ~Copyable` that
(1) counts via Linear's multipass `Iterable` path, (2) sums via Linear's bespoke borrowing
`forEach`, (3) sums via Ring's bespoke borrowing `forEach`, specializes to **0
`witness_method`** on all three executing paths. Any residual `witness_method` is allowed
**only** inside the retained `@inlinable` generic `Iterable.forEach` template
(`public_external`, unreachable from the concrete client).

## Verdict: **CONFIRMED**

| Gate | Result | Receipt |
|---|---|---|
| `swift build` (debug) | zero errors | `Outputs/build.txt` |
| `swift build -c release` | zero errors | `Outputs/release-mode-pass.txt` |
| `swift run -c release` | runtime-correct (count=5, sum=19) | `Outputs/run.txt` |
| `-O` witness_method SIL | 0-WITNESS CONFIRMED | `Outputs/sil-witness-classification.txt` |
| Cross-module ([EXP-017]) | `client` → buffer/storage/iterator modules | `Outputs/cross-module-pass.txt` |
| Ring ⊬ `Iterable` (negative) | Ring conforms only `Sequenceable` (Copyable-gated) | see Asymmetry below |

**Toolchain:** `swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)` — Target `arm64-apple-macosx26.0` (matches `swift --version` verbatim).

## The three iteration paths (executable `client`)

| # | Path | Surface exercised | Result |
|---|---|---|---|
| 1 | `countViaIterable(linear)` | Linear's multipass **`Iterable`** protocol (generic `Iterable.forEach`) | count = 5 |
| 2 | `sumViaLinearForEach(linear)` | Linear's **bespoke** borrowing `forEach` (`Buffer.Linear+forEach.swift`) | sum = 19 |
| 3 | `sumViaRingForEach(ring)` | Ring's **bespoke** borrowing `forEach` (`Buffer.Ring+forEach.swift`) | sum = 19 |

Path (1) dispatches **through the `Iterable` protocol** (a generic function constrained to
`Iterable`), not the concrete bespoke `Buffer.Linear.forEach` — otherwise overload
resolution would pick the concrete method and never touch the protocol-vended multipass
surface. Runtime observation (`Outputs/run.txt`):

```
linear-iterable-count: 5
linear-foreach-sum: 19
ring-foreach-sum: 19
OK: count=5 sum=19 (all three iteration paths agree)
```

## `witness_method` classification (`-O` client SIL)

The `-O` SIL of the `client` module contains **4** raw `grep witness_method` lines — which
decompose into **2 real `= witness_method` instructions** plus **2 `$@convention(witness_method:)`
type annotations** on the `apply`s of those two (an annotation is a calling-convention marker
in a type, not a dynamic dispatch). Both real instructions sit in **one** function.

| Enclosing SIL function | Linkage | Real `witness_method` instrs | Reachable from client? |
|---|---|---|---|
| `countViaIterable` (specialized, for `Buffer<…Job>.Linear`) | `shared` | **0** | yes (called by `main`) |
| `sumViaLinearForEach` | `hidden` | **0** | yes (called by `main`) |
| `sumViaRingForEach` | `hidden` | **0** | yes (called by `main`) |
| `Iterable.forEach<A>(_:)` (generic template) | **`public_external`** | **2** (`makeIterator`, `next`) | **no** (client calls the specialized copy) |

All three executing client paths hold **0**. The only two real `witness_method` instructions
(`Iterable.makeIterator`, `__IteratorChunkProtocol.next`) are inside the retained `@inlinable`
generic `Iterable.forEach` template — `public_external` and unreachable, because the concrete
client calls the **specialized** `countViaIterable` (which inlines the concrete chunk iterator).
Iteration bottoms out in the concrete column's `Span.Protocol` span (Linear) / ledger-walked
`storage[slot]` subscript (Ring) with no protocol dispatch — it flows from the column exactly
as D3 requires. Full receipt + raw enclosing-header evidence: `Outputs/sil-witness-classification.txt`.

## The Linear / Ring asymmetry (load-bearing)

The two disciplines are **not symmetric** on the protocol-vended surface, and the D9 contract
is stated over `forEach` precisely because of it:

- **Linear** vends the multipass `Iterable` protocol (element gate `~Copyable`), so a
  Linear-backed family may additionally expose multipass iteration.
- **Ring** vends **no** multipass `Iterable`. On current `main` the ring conforms **only**
  `Sequenceable` (single-pass, consuming) and that conformance is `S.Element: Copyable`-gated
  (`Buffer.Ring+Sequence.Protocol.swift:18`), so it does not apply to a move-only `Job` at
  all; the ring's move-only iteration surface is exactly its bespoke borrowing `forEach`. The
  multipass side was active-pruned 2026-06-10 and re-materializes only when a borrowing
  *segment iterator* is designed against the move-only substrate.

Grep of the ring package source finds **no** `extension Buffer.Ring … : Iterable` conformance
(only `: Sequenceable`), confirming the asymmetry is intact. **Any claim of iteration
*uniformity* across the disciplines would overstate** — a family MUST NOT claim multipass
`Iterable` unless its column vends it (Linear yes; Ring no, until the segment iterator lands).
This is why D9 states the contract as "a borrowing `forEach` over the column" (the surface both
columns satisfy at 0-witness), NOT the `Iterable` protocol.

## Boundary note

This proves D9's design contract on real Linear/Ring columns; **W1.9 executes the ADT-tier
re-home** (delete or re-point the ADT-tier hand-walk iteration to the column flow-through per
`Research/adt-tower.md` §2 D9; sites enumerated by grep at dispatch).

## Files

```
Package.swift                              path-deps to the REAL upstream packages (local mains)
Sources/client/main.swift                  [EXP-017] cross-module consumer + the 3 iteration paths
classify-sil.py                            witness_method classifier (real instr vs annotation)
run-sil-probe.sh                           emits -O SIL + runs the classifier
Outputs/build.txt                          debug build receipt
Outputs/release-mode-pass.txt              release build receipt
Outputs/run.txt                            runtime-correctness receipt
Outputs/client.sil                         emitted -O SIL of the client module
Outputs/sil-witness-classification.txt     the 0-witness verdict + classification + evidence
Outputs/cross-module-pass.txt              [EXP-017] cross-module leg note
```

## Building

```
swift build
swift build -c release
swift run -c release
./run-sil-probe.sh          # re-emits -O SIL and re-runs the classification
```

Requires Swift 6.3 or newer (verified on 6.3.3).
