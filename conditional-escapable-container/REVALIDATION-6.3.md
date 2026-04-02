# Revalidation: conditional-escapable-container

- **Date**: 2026-04-02
- **Swift version**: 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
- **Build result**: SUCCESS
- **Runtime result**: All 8 test variants pass

## What changed vs previous finding

Nothing changed. All three blockers from the original experiment remain on Swift 6.3:

1. **UnsafeMutablePointer<T: ~Escapable> blocked** -- Still blocked. `UnsafeMutablePointer<Element>` still implicitly requires `Element: Escapable`. Heap-backed containers for ~Escapable elements remain impossible.

2. **Optional<Element> in ~Escapable container blocked** -- Still blocked. `Optional<Element>` stored properties in a `~Escapable` container still produce "lifetime-dependent variable 'self' escapes its scope", even when both slots are filled (no nil). Confirmed with standalone test.

3. **Partial reinit of ~Copyable self rejected** -- Still blocked (structural, not expected to change).

Working paths remain the same: single-element Box, struct fields (Pair, Triple), enum-based variable-occupancy (EnumStack2, EnumStack4), nested containers, and @_rawLayout declaration (layout only, not access).

## Original documented finding still accurate?

Yes. The original finding is fully accurate on Swift 6.3. No blockers have been lifted.
