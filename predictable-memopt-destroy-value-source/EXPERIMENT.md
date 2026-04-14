# Experiment: Source of Spurious destroy_value in PredictableDeadAllocationElimination

## Purpose
Validate that the spurious `destroy_value` in the CopyPropagation ~Escapable crash
(swiftlang/swift#88022) comes from `completeOSSALifetime` during alloc_stack removal
in PredictableDeadAllocationElimination, NOT from `InstructionDeleter.forceDelete`.

## Hypothesis
The destroy_value is inserted by `completeOSSALifetime` when it processes values
stored to the alloc_stack being removed, not by the `forceDelete` compensation
logic (which correctly passes `fixLifetimes=false`).

## Toolchain
Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
Platform: macOS 26.0 (arm64)

## Method
Compile the known reproducer's Core module with `-O` and SIL dumps around
`predictable-deadalloc-elim` (pass 32), filtering for the `Container.view.read`
accessor function.

Command:
```bash
swiftc -emit-sil -O -enable-experimental-feature Lifetimes \
  Core/View.swift -module-name Core \
  -Xllvm -sil-print-around=predictable-deadalloc-elim \
  -Xllvm '-sil-print-function=$s4Core9ContainerV4viewAA4ViewVyACGvr'
```

## Result: CONFIRMED

Swift 6.3: FIXED — workaround no longer required
Status: SUPERSEDED (2026-04-14) — bug fixed in Swift 6.3, workaround removed from production code

**Before pass 32** (PredictableDeadAllocationElimination):
```sil
%5  = alloc_stack $UnsafeMutablePointer<Container>
%6  = struct $UnsafeMutablePointer<Container> (...)
store %6 to [trivial] %5
%11 = apply %10<Container>(%6, %2)              // @owned View
%12 = mark_dependence [nonescaping] %11 on %5   // base = alloc_stack
yield %12, resume bb1, unwind bb2
bb1: destroy_value %12
bb2: destroy_value %12
```

Ownership is clean: `%11` consumed once by mark_dependence, `%12` consumed once per path.

**After pass 32**:
```sil
%5  = struct $UnsafeMutablePointer<Container> (...)  // alloc_stack eliminated
%9  = apply %8<Container>(%5, %2)               // @owned View
%10 = mark_dependence [nonescaping] %9 on %5    // base promoted to trivial
destroy_value %9                                 // ← SPURIOUS: %9 already consumed by mark_dependence
yield %10, resume bb1, unwind bb2
bb1: destroy_value %10
bb2: destroy_value %10
```

`%9` has TWO consumers: mark_dependence (ForwardingConsume) + destroy_value. This is a
double consume introduced by the pass.

## Key Finding
The alloc_stack (`%5`) was removed. The mark_dependence base was promoted from
`%5` (address) to `%5` (trivial struct value). During alloc_stack removal,
`completeOSSALifetime` was called on `%9` (the value stored to the alloc_stack
via the init pattern), inserting a destroy_value — even though `%9` is already
consumed by the new mark_dependence.

## Date
2026-03-24
