# unsafe-forin-release-crash

**Status**: Fixed (workaround applied), compiler bug not yet minimally reproduced
**Date**: 2026-03-14
**Swift**: 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)

## Bug

Expression-level `unsafe` on `for-in` loops over `[UnsafeMutablePointer<T>]`
crashes the SIL optimizer with signal 6 in release builds when
`StrictMemorySafety` is enabled.

## Primary Reproduction

The crash occurs deterministically in the original file:

```
swift-primitives/swift-path-primitives/Sources/Path Primitives/Path.String.swift
```

Before the fix, this command crashed:

```bash
cd swift-primitives/swift-path-primitives
swift build -c release
# error: compile command failed due to signal 6
```

The crash requires the specific combination of:
- `@inlinable` function attribute
- Generic parameters with `~Copyable` constraints (`R: ~Copyable`)
- Typed throws (`throws(Path.String.Error<E>)`)
- `defer { for buffer in unsafe buffers { unsafe buffer.deallocate() } }`
- Release-mode SIL optimization

The simplified reproduction in `Sources/UnsafeLib/Lib.swift` demonstrates the
pattern but does **not** trigger the crash because it lacks `~Copyable` generics
and typed throws. A full minimal reproduction requires further reduction of the
original 700-line file.

## Root Cause

The `for-in` loop desugars to Iterator protocol calls. `IndexingIterator.next()`
returns `UnsafeMutablePointer<T>?` which is an unsafe type. The compiler needs to
thread the `unsafe` annotation through the iterator's `next()` call, involving
`inout IndexingIterator<[UnsafeMutablePointer<T>]>`. The SIL optimizer crashes
processing this during release-mode optimization, likely during specialization
of the generic `@inlinable` function.

## Workaround (Applied)

Use index-based loops instead of `for-in`:

```swift
// CRASHES in release (with ~Copyable generics + typed throws):
defer { for buffer in unsafe buffers { unsafe buffer.deallocate() } }

// WORKS in release:
defer { for i in 0..<buffers.count { unsafe buffers[i].deallocate() } }
```

18 instances fixed in `Path.String.swift` (9 defer + 9 enumerated loops).

## Impact

Blocked ALL release-mode testing via nested packages that transitively depend
on swift-path-primitives.
