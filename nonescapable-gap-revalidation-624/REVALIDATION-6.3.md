# Revalidation: nonescapable-gap-revalidation-624

- **Date**: 2026-04-02
- **Swift version**: 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
- **Build result**: SUCCESS
- **Runtime result**: All working variants pass

## What changed vs previous finding

Nothing changed. Both gaps remain blocked on Swift 6.3:

**Gap A** (`@_lifetime` on Escapable closure parameter): Still blocked. Standalone test confirms:
```
error: invalid lifetime dependence on an Escapable value with consuming ownership
```
The `@_lifetime(immortal)` workaround still works.

**Gap B** (~Escapable captured in non-escaping closure): Still blocked. Standalone test confirms:
```
error: lifetime-dependent variable 'ne' escapes its scope
note: this use causes the lifetime-dependent value to escape
```

**Working variants** (all still pass):
- Gap B+ (withLock-style inline closure returning value): PASS
- Gap B++ (immortal ~Escapable in closure): PASS
- `@_lifetime(immortal)` workaround for Gap A: PASS

## Original documented finding still accurate?

Yes. The original 6.2.4 finding is fully accurate on Swift 6.3. Gap A and Gap B remain blocked with identical error messages. Workarounds remain valid.
