# Revalidation: ownership-overloading-limitation

- **Date**: 2026-04-02
- **Swift version**: 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
- **Build result**: SUCCESS
- **Runtime result**: All runnable variants pass

## What changed vs previous finding

**SIGNIFICANT CHANGE in Q1-Q3**: Swift 6.3 has partially lifted the ownership overloading restriction:

| Question | 6.2 Result | 6.3 Result | Change |
|----------|-----------|-----------|--------|
| Q1: borrowing vs consuming | "invalid redeclaration" | Declarations compile, calls ambiguous | PARTIAL FIX |
| Q2: borrowing vs inout | "invalid redeclaration" | **Fully works** (& disambiguates) | **FIXED** |
| Q3: consuming vs inout | "invalid redeclaration" | **Fully works** (& disambiguates) | **FIXED** |

**Details**:
- `borrowing` vs `consuming` on the same name now compiles the declarations (previously rejected outright), but calls are ambiguous because the compiler cannot distinguish at the call site. There is no syntax to explicitly mark a call as "borrowing" vs "consuming".
- `borrowing` vs `inout` now fully works: `t.update(42)` resolves to borrowing, `t.update(&x)` resolves to inout. The `&` sigil disambiguates.
- `consuming` vs `inout` now fully works: `t.take(42)` resolves to consuming, `t.take(&x)` resolves to inout. The `&` sigil disambiguates.

**No change in Q6-Q10**: Constraint-based overloading, callAsFunction crash, two-tier patterns, and static method delegation all behave the same as 6.2.

## Original documented finding still accurate?

**Partially outdated**. The blanket statement "Ownership modifiers are NOT an overload axis" is no longer fully accurate on Swift 6.3:
- `borrowing` vs `inout`: now a valid overload axis (fixed)
- `consuming` vs `inout`: now a valid overload axis (fixed)
- `borrowing` vs `consuming`: declarations accepted but calls ambiguous (not usable in practice)

The static method delegation workaround (Q10/IMPL-023) remains the canonical pattern for the borrowing-vs-consuming case specifically. The experiment source code and findings should be updated to reflect the 6.3 changes.
