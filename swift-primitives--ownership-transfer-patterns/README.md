# ownership-transfer-patterns

Consolidated experiment package covering ownership transfer patterns for ~Copyable values through Mutex-based synchronization. Tests against primitives types (CoroutineMutex, Bridge patterns, ~Escapable views).

## Coverage

| File | Origin | Variants | Status |
|------|--------|----------|--------|
| V01_MutexCoroutineRealistic | mutex-coroutine-realistic | 8 | CONFIRMED |
| V02_MutexEscapableAccessor | mutex-escapable-accessor | 5 | CONFIRMED (V1-V3, V5) / REFUTED (V4) |
| V03_BridgeOwnership | bridge-noncopyable-ownership | 9 | CONFIRMED |

**Total**: 22 variants across 3 experiments.

## Theme

Mutex coroutine accessors, ~Escapable scoped views, and bridge ownership transfer patterns:

- **V01**: Real os_unfair_lock mutex with _read/_modify coroutine accessors, ~Escapable locked view, consuming ~Copyable in/out, concurrent safety, action enum dispatch
- **V02**: ~Escapable accessor pattern feasibility — ToyMutex proving the concept, Synchronization.Mutex limitation (yield cannot appear in closures)
- **V03**: Mutex extension APIs for ~Copyable ownership transfer (deposit, consuming, caller-owned slot), UnsafeContinuation Copyable constraint, Element?? vs _Take enum, Sequence iteration inside lock

## Key Findings

- Coroutine-based `locked` accessor is a production-viable replacement for closure-based `withLock`
- `Synchronization.Mutex` cannot support coroutine accessors without stdlib changes (V02-V4 REFUTED)
- `slot.take()!` is the simplest Bridge.push() pattern — no Mutex extension needed (V03-V5)
- `UnsafeContinuation<T, Never>` requires T: Copyable — void-signal pattern is mandatory (V03-V6)
- `Element??` compiles but `_Take` enum has better readability (V03-V7)

## Build

```bash
swift build
```

Requires Swift 6.2+, macOS 26, Lifetimes experimental feature.
