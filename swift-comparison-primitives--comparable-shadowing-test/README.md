# Experiment: Comparable Shadowing Test

<!--
---
experiment_id: comparable-shadowing-test
date: 2026-01-22
toolchain: swift-6.2
result: HYPOTHESIS REFUTED
---
-->

## Hypothesis

If comparison-primitives declares a top-level `Comparable` protocol, it will "trump" `Swift.Comparable` so that consuming packages can just import and "magically" have all their existing `Comparable` conformances work with `~Copyable` support and fluent APIs.

## Result: REFUTED

The "magic" is **not achievable** with current Swift. Shadowing works but breaks existing code rather than enhancing it.

## Findings

### 1. Shadowing Works (But Not Helpfully)

When a module declares `public protocol Comparable`, any consumer using bare `Comparable` resolves to that module's protocol, not `Swift.Comparable`.

```swift
import ComparableShadow

func compare<T: Comparable>(_ a: T, _ b: T) -> Bool { ... }
// ↑ This is ComparableShadow.Comparable, NOT Swift.Comparable

compare(5, 10)  // ERROR: Int doesn't conform to Comparable
```

### 2. No Automatic Conformance

`Int`, `String`, `Double`, etc. conform to `Swift.Comparable`, not our `Comparable`. They are completely separate protocols with no relationship.

### 3. Signature Incompatibility

The protocols have fundamentally different signatures:

| Protocol | Signature |
|----------|-----------|
| `Swift.Comparable` | `static func < (lhs: Self, rhs: Self) -> Bool` |
| Our `Comparable` | `static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool` |

The `borrowing` annotation makes them incompatible.

### 4. Retroactive Conformance Fails

Attempted to add retroactive conformances for stdlib types:

```swift
extension Int: Comparable {
    public static func < (lhs: borrowing Int, rhs: borrowing Int) -> Bool {
        return (lhs as Int) < (rhs as Int)
    }
}
```

**Errors:**
- "Multiple matching functions named '<'" - Int has several `<` operators from `BinaryInteger`, `Strideable`, etc.
- Ambiguous operator usage when delegating to Swift's implementation
- Would break stdlib's internal usage

### 5. Breaking Change

If we named our protocol `Comparable`:
- Consumers writing `T: Comparable` expecting `Int` to work → compilation errors
- Consumers must write `Swift.Comparable` explicitly everywhere
- Defeats the purpose of "magic" adoption

## Conclusion

**Keep `Comparison.Protocol`** as the name. The explicit opt-in is the correct design:

1. Clearly signals a different protocol with different semantics
2. No naming collision with stdlib
3. Consumers can use both `Swift.Comparable` and `Comparison.Protocol` without confusion
4. `~Copyable` support is an explicit feature, not implicit magic

## Files

- `Sources/ComparableShadow/Comparable.swift` - Module declaring top-level `Comparable`
- `Sources/Consumer/main.swift` - Consumer testing shadowing behavior

## Running the Experiment

```bash
cd experiments/comparable-shadowing-test
swift run
```

## Related Proposals

This experiment motivated the following draft SE proposals:

- [SE-XXXX Borrowing Parameter Witness Relaxation](../../../../swift-institute/Sources/Swift%20Institute/Swift%20Institute.docc/SE-Proposals/SE-XXXX%20Borrowing%20Parameter%20Witness%20Relaxation.md) — Foundational language change to allow non-`borrowing` implementations to satisfy `borrowing` requirements for `Copyable` types
- [SE-YYYY Noncopyable Equatable and Comparable](../../../../swift-institute/Sources/Swift%20Institute/Swift%20Institute.docc/SE-Proposals/SE-YYYY%20Noncopyable%20Equatable%20and%20Comparable.md) — Standard library evolution to add `~Copyable` support to `Equatable` and `Comparable`

These proposals would enable the "magic" adoption that this experiment proved impossible with current Swift.
