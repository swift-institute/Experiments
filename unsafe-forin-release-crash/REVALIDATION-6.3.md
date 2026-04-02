# Revalidation: unsafe-forin-release-crash

- **Date**: 2026-04-02
- **Swift version**: 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
- **Build result**: SUCCESS (`swift build -c release`)
- **Runtime result**: Runs correctly, outputs "Converted 2 strings"

## What changed vs previous finding

**Potential fix**: The simplified reproduction in this experiment builds and runs in release mode on Swift 6.3 without crashing. On 6.2.4, the README noted this simplified reproduction "does not trigger the crash because it lacks ~Copyable generics and typed throws" -- the actual crash required the specific combination in `Path.String.swift` (700-line file with @inlinable + ~Copyable generics + typed throws + defer with unsafe for-in + release-mode SIL optimization).

**New diagnostics**: Swift 6.3 now warns that `UnsafeMutablePointer<CChar>.allocate(capacity:)` and `UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(capacity:)` do not require `unsafe` annotations. This is a StrictMemorySafety refinement -- pointer allocation is no longer flagged as unsafe.

**Cannot fully verify**: The actual crash required the original `Path.String.swift` file in swift-primitives with its full complexity. This simplified reproduction was never sufficient to trigger it. To confirm the compiler bug is fixed, the index-based loop workaround in `Path.String.swift` would need to be reverted and tested in release mode.

## Original documented finding still accurate?

Partially. The simplified reproduction still builds/runs (as it always did). The actual bug's status on 6.3 is **indeterminate from this experiment alone** -- it requires testing the original file in swift-path-primitives. The workaround (index-based loops) remains in place and is harmless regardless.
