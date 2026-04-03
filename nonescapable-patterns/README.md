# nonescapable-patterns

Consolidated ~Escapable accessor, storage, protocol, lazy sequence, and pointer patterns.

## Coverage

| File | Origin | Status |
|------|--------|--------|
| V01_EscapableAccessorPatterns | escapable-accessor-patterns | CONFIRMED |
| V02_ClosureStorage | nonescapable-closure-storage | CONFIRMED |
| V03_GapRevalidation | nonescapable-gap-revalidation-624 | BUG REPRODUCED |
| V04_ProtocolCrossModule | escapable-protocol-cross-module | CONFIRMED |
| V05_LazySequenceBorrowing | escapable-lazy-sequence-borrowing | CONFIRMED (9/9) |
| V06_PointerStorage | pointer-nonescapable-storage | CONFIRMED (enum workaround) |
| V07_ContiguousProtocolEscapable | contiguous-protocol-escapable | MIXED |

## Multi-module structure

`PathPrimitivesLib` is an internal library target simulating `swift-path-primitives`.
V04 imports it and adds cross-module conformance.

## Consolidation

Created per EXP-018 consolidation. 7 experiment packages merged into one SwiftPM library package.
