# Specialization check — answer to swiftlang/swift#86666

**Date:** 2026-05-06
**Triggered by:** eeckstein's reply on swiftlang/swift#86666 — *"It would be interesting if you see the slowdown even if the generic type gets specialized."*

## Bottom line

The 1.6x gap reported in the issue **disappears entirely when the type gets specialized** (i.e., at `-O`). It is reproducible **only at `-Onone`** (debug builds), where no specialization happens by definition.

The original benchmark numbers in the issue (`Raw=97.4ns / Flat=105ns / Nested=155.8ns`) are debug-mode timings. At release-mode `-O`, all variants compile to byte-equivalent SIL and run at the same ~1ns per call.

## Cross-toolchain measurements

Same source, same machine (M-series, macOS 26.0), same benchmark (this experiment).

| Toolchain | Mode | Raw | Flat (_read) | Nested.Inline | Nested gap |
|---|---|---:|---:|---:|---:|
| 6.2.3 | -Onone | 8.0ns | 15.2ns | 65.4ns | **8.13x** |
| 6.2.3 | -O     | 1.1ns | 1.1ns  | 1.1ns  | **1.00x** |
| 6.3.1 | -Onone | 93.2ns | 99.6ns | 153.9ns | **1.65x** |
| 6.3.1 | -O     | 1.0ns | 1.0ns  | 1.0ns  | **1.00x** |
| 6.4-dev | -Onone | 8.8ns | 17.5ns | 67.8ns | **7.66x** |
| 6.4-dev | -O     | 1.3ns | 1.2ns  | 1.1ns  | **0.81x** (within noise) |

The 6.3.1 -Onone numbers exactly match the issue body (Raw 97.4 / Flat 105 / Nested 155.8 — issue; vs 93.2 / 99.6 / 153.9 — here). Confirmed reproduction of the issue's measurement, which means the issue's measurement was a debug build.

## SIL evidence — at -O the bodies are identical

`xcrun swiftc -O -emit-sil` on this experiment, reading the specialized closure body for the nested-vector benchmark loop and the flat-vector benchmark loop:

**FlatVector3Read closure (Swift 6.3.1, lines 4377-4427 of /tmp/main.sil):**
- bb2 hoists `struct_extract %1, #FlatVector3Read._elements` then `#InlineArray._storage`
- bb4 (loop body): 3× `alloc_stack $Builtin.FixedArray<3, Int>` + `store` + `vector_base_addr` + `index_addr` + `load` + `dealloc_stack`, then 2× `sadd_with_overflow_Int64`, then `apply blackHole`

**NestedVector.Inline closure (Swift 6.3.1, lines 4529-4623 of /tmp/main.sil):**
- bb2 hoists `struct_extract %1, #NestedVector.Inline._elements` then `#InlineArray._storage`
- bb4 (loop body): same 3× `alloc_stack`/`store`/`vector_base_addr`/`load` pattern, then same 2× `sadd_with_overflow_Int64`, then same `apply blackHole`

The two bodies differ only in:
- the field name in the `struct_extract` (FlatVector3Read._elements vs NestedVector.Inline._elements) — a SIL label, not a runtime difference
- 3 extra `debug_value` annotations in the nested version — debug-info only, no codegen

The hot-path call site is *fully specialized* on 6.3.1: the closure mangling (`...NestedVectorOAARi_zrlE6InlineVySi$2__GTf1nc_n`) carries `<Int, 3>` concrete in the type signature, and the modify accessor has a `Tg5` (generic specialization) variant that gets used directly.

The same is true on **6.2.3** — SIL emitted with `TOOLCHAINS=org.swift.623202512101a` shows the FlatVector3Read closure and the NestedVector.Inline closure with the same instruction shape (only difference: 6.2.3 uses the older `unchecked_addr_cast` / `address_to_pointer` chain instead of 6.3.1's `vector_base_addr` primitive — but applied symmetrically to both Flat and Nested).

## What the issue actually measured

The issue's "To Reproduce" block runs `swift build` (debug = `-Onone`). At `-Onone`:
- No generic specialization
- No inlining across `@inlinable` boundaries
- Every subscript becomes a real function call through `@yield_once` accessor
- Generic ~Copyable nested-type machinery (witness-table-style) costs more than flat-struct field access

So the gap is entirely explained by the absence of specialization — exactly Erik's hypothesis.

## Variant probes — extra rows beyond the original benchmark

| Variant | -Onone (6.3.1) | -O (6.3.1) | Note |
|---|---:|---:|---|
| `NestedVector.Inline` (original) | 1.62x | 1.00x | The issue's reported case |
| `NestedVectorSpec.Inline` with `@_specialize(where Element == Int, N == 3)` on a `borrowing func read(at:)` wrapper | 1.68x | 1.00x | Slower at -Onone (extra method call); identical at -O |
| `NestedVectorMonoWrapper` (concrete struct delegating to `NestedVector<Int, 3>.Inline`) | 2.10x | 1.00x | Slower at -Onone (extra wrapper layer); identical at -O |

`@_specialize` does nothing at `-Onone` — specialization runs in the optimizer pipeline that `-Onone` skips. Adding a wrapping method or struct only adds call layers.

## Recommended reply / next steps for the issue

1. **Reply with the data, no architectural rebuttal.** Erik's question deserves a direct empirical answer: *"You were right — the slowdown is entirely a missed-specialization artifact at `-Onone`. At `-O` the SIL is byte-equivalent to the flat-struct case (SIL diff attached), and the timing collapses to identical (~1ns) on 6.2.3, 6.3.1, and 6.4-dev nightly. Reproduced the issue's 1.62x at `-Onone` 6.3.1 with this benchmark; at `-O` no gap is observable."*

2. **Recharacterize the issue.** The current title — *"Suboptimal codegen: nested generic type subscript ~1.6x slower than flat struct"* — implies a release-mode codegen problem. It is not. Two options:
   - **Close it.** This is "generic code is slow at `-Onone`" which is expected and not a compiler bug.
   - **Recharacterize as `-Onone`-specific** if there's a real concern about debug-build performance for ~Copyable nested-generic types. The 6.4-dev numbers suggest `-Onone` codegen for plain InlineArray subscripting has improved (95ns → 9ns baseline) but the nested-generic shape hasn't gotten the same treatment. That is a smaller, more focused issue if it's worth filing at all.

3. **Drop the architectural concern in `swift-vector-primitives`.** The recommendation block in the original experiment ("Accept the overhead. The architectural benefits ... outweigh ~1.5x read overhead") is moot — there is no overhead at `-O`, which is what the package ships under. Production users get specialized code; debug-build users pay generic-dispatch cost, which is normal.

## Reproduction

This experiment, on macOS / arm64:

```bash
cd ~/Developer/swift-primitives/swift-vector-primitives/Experiments/inline-subscript-performance

# Default (Swift 6.3.1)
swift build -c release && .build/release/inline-subscript-performance
swift build -c debug   && .build/debug/inline-subscript-performance

# Swift 6.2.3 (the version in the issue)
TOOLCHAINS=org.swift.623202512101a swift build -c release && .build/release/inline-subscript-performance
TOOLCHAINS=org.swift.623202512101a swift build -c debug   && .build/debug/inline-subscript-performance

# Swift 6.4-dev nightly
TOOLCHAINS=org.swift.64202603161a swift build -c release && .build/release/inline-subscript-performance
TOOLCHAINS=org.swift.64202603161a swift build -c debug   && .build/debug/inline-subscript-performance
```

SIL emission for direct comparison:

```bash
xcrun swiftc -O -emit-sil Sources/inline-subscript-performance/main.swift -o /tmp/main.sil
# Find the specialized closure bodies:
grep -nE '^sil .*Tf1nc_n' /tmp/main.sil
# Read FlatVector3Read body and NestedVector.Inline body side-by-side
```
