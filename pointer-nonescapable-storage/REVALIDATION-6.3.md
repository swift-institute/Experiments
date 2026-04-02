# Revalidation: pointer-nonescapable-storage

- **Date**: 2026-04-02
- **Swift version**: 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
- **Build result**: SUCCESS (1 new warning: `no unsafe operations occur within 'unsafe' expression` on `UnsafeMutableRawPointer.allocate`)
- **Runtime result**: All working variants pass, all blocked variants confirmed still blocked

## What changed vs previous finding

**Minor change**: Swift 6.3 now emits a warning that `UnsafeMutableRawPointer.allocate(byteCount:alignment:)` does not require an `unsafe` annotation. This is a refinement in StrictMemorySafety diagnostics -- raw allocation is no longer considered an unsafe operation. The experiment code still compiles and runs correctly; this is a cosmetic diagnostic improvement only.

**No substantive change**: All pointer constraints remain identical:

- V1 (UnsafeMutablePointer<~Escapable>): BLOCKED
- V2b (initializeMemory): BLOCKED
- V2c (assumingMemoryBound): BLOCKED
- V6/V7/V8/V11 (Optional<Element> in ~Escapable container): BLOCKED
- V17/V17b (@_rawLayout element access): BLOCKED
- V14/V15 (enum-based storage): PASS
- V16 (@_rawLayout declaration): PASS

Confirmed with standalone test: `Optional<Element>` stored property in ~Escapable container still produces "lifetime-dependent variable 'self' escapes its scope".

## Original documented finding still accurate?

Yes. The core finding (heap-backed blocked, Optional slots blocked, enum workaround works, @_rawLayout layout-vs-access gap) is fully accurate on Swift 6.3.
