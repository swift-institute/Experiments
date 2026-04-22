// MARK: - Unapplied-Init Literal-Inference Overload-Resolution Footgun
//
// Blog: BLOG-IDEA-060 "Why `.map(Type.init)` can silently compute wrong values"
//       Draft: swift-institute/Blog/Draft/unapplied-init-overload-footgun.md
//
// Purpose: Demonstrate that Swift's overload resolution, when forming an
//          unapplied function reference (`.map(Type.init)`), will silently
//          route through `ExpressibleBy*Literal` conformances on intermediate
//          types to produce a concrete function value — even when the resulting
//          selection performs a domain-crossing transformation the programmer
//          never asked for.
//
// No physical units, no Tagged types, no tags — just plain structs and numeric
// conversion. The hazard is purely a consequence of Swift's overload resolution
// + literal inference + function-reference rules.
//
// Hypothesis: `(0..<5).map(Target.init)` will produce `[0, 10, 20, 30, 40]`
//             (the scaling init) rather than `[0, 1, 2, 3, 4]` (what the
//             programmer intended), because Swift:
//               1. Forms `Target.init` as an unapplied function reference.
//               2. Searches for an unlabeled `init` matching `(_) -> Target`.
//               3. Finds `init(_ s: Source)`; infers `Element = Source`.
//               4. Routes `Int` literals → `Source` via `ExpressibleByIntegerLiteral`.
//               5. Each element passes through the ×10 scaling init.
//
// Toolchain: Swift 6.3.1 (Xcode 26.4.1 default; swiftlang-6.3.1.1.2)
// Platform:  macOS 26.0 (arm64)
// Date:      2026-04-22
//
// Result: CONFIRMED — footgun reproduces in pure-algebra form.
//
// Evidence (stdout on the default run):
//   === Unapplied-init literal-inference overload-resolution footgun ===
//   V1 (baseline):            [0, 10, 20, 30, 40]
//   V2 (disfavor literal):    [0, 10, 20, 30, 40]
//   V3 (no Strideable):       [COMPILE ERROR — chain broken]
//   V4 (explicit Source[]):   [0, 10, 20, 30, 40]
//
// Key findings:
//
// 1. The hazard is structurally present on current Swift whenever ALL of:
//    (a) Source conforms to `ExpressibleByIntegerLiteral`
//    (b) Source conforms to `Strideable` (so `Range<Source>` is iterable)
//    (c) Target has an unlabeled `init(_: Source)` as the ONLY single-arg init
//        matching `.map(Target.init)`'s function-reference shape
//    Then `(0..<5).map(Target.init)` silently resolves to that cross-domain
//    init and multiplies every value by the transformation factor.
//
// 2. `@_disfavoredOverload` on the cross-domain init provides ZERO protection
//    (V2 output matches V1). The attribute re-ranks among equally-applicable
//    candidates; it does not exclude the init from function-reference binding.
//
// 3. Removing `Strideable` from Source breaks the literal-inference chain at
//    Range construction (V3). `Range<Source>` is not a Sequence without
//    Strideable, so Swift can't form `0..<5` as `Range<Source>`, and no
//    `(Int) -> Target` path exists — compile error.
//
// 4. CAVEAT (discovered during the build of this reproducer): labeled inits
//    ARE visible to `.map(Type.init)` function references. The label is part
//    of the init's declaration name but NOT part of the function-value type.
//    If Target additionally had `init(raw: Int)`, `.map(Target.init)` would
//    resolve to `init(raw:)` directly (its `(Int) -> Target` type matches
//    `Range<Int>` without any literal inference) and the footgun would NOT
//    fire. The minimum condition for the footgun is: **no single-parameter
//    init on Target matches `(ContextType) -> Target` directly, and the
//    cross-domain init's parameter type is reachable via literal inference.**
//
// This reproducer is deliberately domain-free: no physical units, no phantom
// types, no ecosystem vocabulary. The hazard is a pure interaction of three
// Swift language rules: overload resolution for unapplied function references,
// literal-protocol-mediated type inference, and Range/Strideable interaction.

// MARK: - Variant 1: Baseline footgun (all three ingredients present)
// Ingredients: Source: ExpressibleByIntegerLiteral + Strideable; Target has
//              unlabeled non-identity init(_: Source).

enum V1 {
    struct Source: ExpressibleByIntegerLiteral, Comparable, Strideable, CustomStringConvertible {
        let value: Int
        init(_ value: Int) { self.value = value }
        init(integerLiteral value: Int) { self.value = value }
        static func < (lhs: Source, rhs: Source) -> Bool { lhs.value < rhs.value }
        func advanced(by n: Int) -> Source { Source(value + n) }
        func distance(to other: Source) -> Int { other.value - self.value }
        var description: String { "Source(\(value))" }
    }

    // Target has ONLY the cross-domain init from Source. Crucially: no
    // `(Int) -> Target` path exists, so Swift has no choice but to route
    // through literal inference on Source.
    struct Target {
        let value: Int
        init(_ source: Source) { self.value = source.value * 10 }
    }

    static func run() {
        let result: [Target] = (0..<5).map(Target.init)
        print("V1 (baseline):            \(result.map { $0.value })")
    }
}

// MARK: - Variant 2: Does @_disfavoredOverload on the literal init protect?
// Hypothesis: no — attribute re-ranks among equally-applicable candidates but
//             does not exclude the cross-domain init from function-reference
//             resolution.

enum V2 {
    struct Source: ExpressibleByIntegerLiteral, Comparable, Strideable {
        let value: Int
        init(_ value: Int) { self.value = value }
        @_disfavoredOverload
        init(integerLiteral value: Int) { self.value = value }
        static func < (lhs: Source, rhs: Source) -> Bool { lhs.value < rhs.value }
        func advanced(by n: Int) -> Source { Source(value + n) }
        func distance(to other: Source) -> Int { other.value - self.value }
    }

    struct Target {
        let value: Int
        @_disfavoredOverload
        init(_ source: Source) { self.value = source.value * 10 }
    }

    static func run() {
        let result: [Target] = (0..<5).map(Target.init)
        print("V2 (disfavor literal):    \(result.map { $0.value })")
    }
}

// MARK: - Variant 3: Remove Strideable — can Range<Source> still form?
// Hypothesis: without Strideable, Range<Source> is not a Sequence. Swift
//             cannot form 0..<5 as Range<Source>, so .map(Target.init)
//             falls back to the Int range path, where no Target.init(_: Int)
//             exists as an unlabeled init, and Swift picks no cross-domain
//             init. This confirms Strideable presence is load-bearing.

enum V3 {
    struct Source: ExpressibleByIntegerLiteral, Comparable {  // NO Strideable
        let value: Int
        init(_ value: Int) { self.value = value }
        init(integerLiteral value: Int) { self.value = value }
        static func < (lhs: Source, rhs: Source) -> Bool { lhs.value < rhs.value }
    }

    // Target has ONLY the cross-domain init. No literal init, no Int init.
    struct Target {
        let value: Int
        init(_ source: Source) { self.value = source.value * 10 }
    }

    static func run() {
        // Without Strideable on Source, Range<Source> is not a Sequence.
        // Swift cannot form 0..<5 as Range<Source>. The only Target.init
        // candidate matching a single unlabeled parameter is init(_: Source);
        // there is no `(Int) -> Target` path available. Uncommenting the line
        // below produces:
        //   error: cannot convert value of type 'Int' to expected argument type 'V3.Source'
        //
        //     let result: [Target] = (0..<5).map(Target.init)
        //
        // The compile error IS the result: removing Strideable from the
        // intermediate type breaks the literal-inference chain that the
        // footgun depends on.
        print("V3 (no Strideable):       [COMPILE ERROR — chain broken]")
    }
}

// MARK: - Variant 4: Explicitly form Source range — cross-domain init fires
// as expected. Confirms the scaling semantics work when the programmer
// genuinely intends a Source → Target conversion.

enum V4 {
    typealias Source = V1.Source
    typealias Target = V1.Target

    static func run() {
        let sources: [Source] = (0..<5).map { Source($0) }
        let result: [Target] = sources.map { Target($0) }
        print("V4 (explicit Source[]):   \(result.map { $0.value })")
    }
}

// MARK: - Execution

print("=== Unapplied-init literal-inference overload-resolution footgun ===")
V1.run()
V2.run()
V3.run()
V4.run()
print()
print("Legend:")
print("  V1 [0, 10, 20, 30, 40]  → FOOTGUN: .map(Target.init) silently picked cross-domain init")
print("  V2 [0, 10, 20, 30, 40]  → @_disfavoredOverload provides NO protection")
print("  V3 [COMPILE ERROR]      → removing Strideable on Source breaks the chain")
print("  V4 [0, 10, 20, 30, 40]  → cross-domain init works correctly when explicitly called")
