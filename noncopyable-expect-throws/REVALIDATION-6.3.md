# Revalidation: noncopyable-expect-throws

- **Date**: 2026-04-02
- **Swift version**: 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
- **Build result**: SUCCESS
- **Test result**: All 16 tests in 8 suites pass (0.001s total)

## What changed vs previous finding

The original experiment was designed to isolate which combination of factors causes `#expect(throws:)` to hang with ~Copyable types. On Swift 6.3, **all 16 tests pass without hanging**, including:

- Phase 1: Minimal ~Copyable (PASS)
- Phase 2: ~Copyable with deinit (PASS)
- Phase 3: ~Copyable with AnyObject? field (PASS)
- Phase 4: Value generic parameter (PASS)
- Phase 5: Nested ~Copyable field with deinit (PASS)
- Phase 6: Full composition (multiple ~Copyable fields + value generic + AnyObject?) (PASS)
- Phase 7: Deep nesting (Dictionary<K,V>.Ordered.Static<N> pattern) (PASS)
- Phase 8: Cross-module (all 6 cross-module variants) (PASS)

The experiment code notes suggest the hang was observed in a specific production context (Dictionary.Ordered.Static) rather than in these isolated reproductions. The experiment's finding was "Phase 1 REFUTED -- minimal ~Copyable + #expect(throws:) works fine" with progressive complexity additions. All phases pass on 6.3 as they did on 6.2.

## Original documented finding still accurate?

Yes. The experiment's conclusion (that isolated ~Copyable types work fine with `#expect(throws:)` across all complexity levels) remains accurate. If the original hang was specific to a production type not fully reproduced here, it would need separate verification. No regression detected.
