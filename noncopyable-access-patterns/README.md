# noncopyable-access-patterns

Consolidated experiment package for consuming, borrowing, iteration, and Optional unwrap patterns with `~Copyable` types.

Created per [EXP-018] by absorbing 7 scattered experiments.

## Coverage

| Variant | File | Origin | Status |
|---------|------|--------|--------|
| V01 | `V01_ConsumingIteration.swift` | swift-institute `consuming-iteration-pattern` | CONFIRMED |
| V02 | `V02_ForeachConsumingInstitute.swift` | swift-institute `foreach-consuming-accessor` | CONFIRMED |
| V03 | `V03_ForeachConsumingPrimitives.swift` | swift-primitives `foreach-consuming-accessor` (PRIMARY) | CONFIRMED |
| V04 | `V04_BorrowingForeachViewRead.swift` | swift-primitives `borrowing-foreach-view-read` | CONFIRMED |
| V05 | `V05_ConsumingChainCrossModule.swift` | swift-primitives `noncopyable-consuming-chain-cross-module` | CONFIRMED |
| V06 | `V06_ConsumptionEnforcement.swift` | swift-primitives `noncopyable-consumption-enforcement` | CONFIRMED |
| V07 | `V07_OptionalNoncopyableUnwrap.swift` | swift-primitives `optional-noncopyable-unwrap` | CONFIRMED |

## Multi-Module Targets

V05 requires cross-module verification. The following internal library targets are included:

- `StorageLib` — inline storage with `@_rawLayout` and consuming cleanup
- `BufferLib` — buffer wrapping storage, no deinit, consuming `removeAll()`
- `DataStructureLib` — tree with deinit driving consuming chain

## Property_Primitives Dependency

V02 and V03 originally imported `Property_Primitives` to test against real `Property.View` / `Property.Consuming` types. The consolidated package is self-contained:

- V02: Property_Primitives-dependent variants (5-7) are documented but not compiled
- V03: Includes standalone type definitions (`PropertyView`, `PropertyConsuming`) that capture the essential patterns

## Swift Settings

- `RawLayout` — required for V05 (cross-module) and V06 (consumption enforcement)
- `Lifetimes` — required for V04 (borrowing view read)
