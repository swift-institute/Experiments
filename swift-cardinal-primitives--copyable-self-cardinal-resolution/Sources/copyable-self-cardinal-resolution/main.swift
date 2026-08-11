// MARK: - ~Copyable Self Extension Cardinal SLI Resolution Stress (REFUTED)
// Purpose: Reproduce the production failure observed at
//   `swift-sequence-primitives @ 1f8965a / Sequence Hint/Sequence.Protocol+collect.swift:25`.
//
// Toolchain: Apple Swift 6.x (Xcode 26.x)
// Platform: macOS 26.x (arm64)
//
// Status: REFUTED
// Date: 2026-05-21
//
// Result: REFUTED — the hypothesized Swift compiler overload-resolution bug
// (typed-Cardinal SLI not seen in `~Copyable Self` + `@inlinable consuming`
// contexts) does NOT exist. Every variant tested — minimal-single-module,
// minimal-cross-module, full-Carrier.Protocol-shape multi-module, and
// real-deps via SwiftPM mirror — compiles clean and resolves the SLI overload
// correctly.
//
// Actual root cause (discovered 2026-05-21 mid-investigation):
// SwiftPM `Package.resolved` in `swift-sequence-primitives` was pinned to
// `swift-cardinal-primitives @ 4b7a83a` (Initial publication, 2026-05-12),
// which PRE-DATES the entire Cardinal SLI arc (35bff16 → 3ffa3cd → 1fb2691).
// The pinned revision had NO `RangeReplaceableCollection+Cardinal.swift` at
// all — so the typed-Cardinal `reserveCapacity` overload genuinely did not
// exist in the resolved module, and the compiler correctly failed to find it.
//
// The diagnostic that led to the discovery was a module-scope `@inlinable`
// probe outside the `~Copyable Self` extension: it failed identically,
// proving the bug was NOT extension-context-specific. The extension shape
// was a red herring; the resolution failure was due to a stale Package.resolved.
//
// Fix: `swift package update` in the consumer package re-resolves the local
// mirror to current `main` HEAD, picking up the SLI work.
//
// Lessons for future Cardinal SLI work:
// 1. When SLI overloads "silently don't resolve" in a consumer, check
//    `Package.resolved` for the cardinal-primitives revision FIRST. The pin
//    can lag local HEAD when SwiftPM resolves before the consumer is built.
// 2. Mirror configurations DO honor Package.resolved pins — `swift package
//    update` is required to re-resolve against the mirror's current branch
//    HEAD.
// 3. The `~Copyable Self` extension resolution-stress described in the
//    `cardinal-sli-overload-expansion-survey.md` Dead Ends section was
//    misdiagnosed — protocol-level placement DOES resolve cleanly across
//    module boundaries in such contexts; the historical failure was
//    Package.resolved staleness, not a Swift compiler limitation.

public import QLib
public import Cardinal_Primitives_Core
public import Cardinal_Primitives_Standard_Library_Integration

// MARK: - V_REAL — production-shape resolution test

extension Q where Self: ~Copyable, Element: Copyable {
    /// Mirrors `Sequence.Protocol+collect.swift:25` directly.
    @inlinable
    public consuming func collectReal() -> [Element] {
        let hint = Cardinal(0 as UInt)
        var iterator = self.makeIterator()
        var result: [Element] = []
        result.reserveCapacity(hint)  // <-- production-shape resolution test
        while let e = iterator.next() { result.append(e) }
        return result
    }
}

// MARK: - Driver

let result = EmptyQ<Int>().collectReal()
print("V_REAL: \(result)")
