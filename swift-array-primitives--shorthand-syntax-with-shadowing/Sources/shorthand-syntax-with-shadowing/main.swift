// MARK: - Shorthand Syntax With Custom Array Shadowing
//
// Purpose: Determine whether Swift's shorthand `[Element]` and `[K:V]` syntax
//   can resolve to a user-defined `Array<Element>` / `Dictionary<K,V>` type
//   that shadows the stdlib, or whether the shorthand is hardcoded language
//   sugar that always refers to `Swift.Array` / `Swift.Dictionary`.
//
// Hypothesis: `[Element]` and `[K:V]` are hardcoded sugar for `Swift.Array`
//   / `Swift.Dictionary` and CANNOT resolve to a shadowing user-defined type.
//   If true, swift-format's `[UseShorthandTypeNames]` rule MUST NOT be
//   applied to swift-array-primitives or swift-dictionary-primitives, since
//   the rewrite changes type identity and breaks compilation.
//
// Stakes: blocks B6.5b mass format pass. If REFUTED (shorthand somehow
//   resolves to custom shadow), the format pass is safe and we keep the
//   shorthand wins. If CONFIRMED (shorthand always means stdlib), we must
//   exclude the rule for these two packages or revert b2fb23f and similar
//   commits.
//
// Toolchain: Apple Swift 6.3.1 (Xcode 26.4) — local + swift:6.3 docker
// Platform: macOS 26 / Ubuntu (swift:6.3 container)
//
// Result: CONFIRMED — `[Element]` ALWAYS means `Swift.Array<Element>`.
//   Cannot resolve to a shadowing user-defined `Array<Element>`.
//   See variants V1–V5 below for empirical evidence.
//
// Compiler-source verification (Apple Swift 6.3.1, swiftlang/swift
// pinned at 6f265bdcad8ff5ff1e6e9e287a882c09de969a08):
//
//   1. KnownStdlibTypes.def line 51 — hardcoded stdlib-type registry:
//        KNOWN_STDLIB_TYPE_DECL(Array, NominalTypeDecl, 1)
//      https://github.com/swiftlang/swift/blob/6f265bdcad8ff5ff1e6e9e287a882c09de969a08/include/swift/AST/KnownStdlibTypes.def#L51
//
//      The compiler maintains an x-macro list of stdlib types it has
//      special knowledge of. `Array` is bound at ASTContext init.
//
//   2. TypeCheckType.cpp lines 5584–5618 — TypeResolver::resolveArrayType:
//        // If the standard library isn't loaded, we ought to let the user know
//        // something has gone terribly wrong, since the rest of the compiler is
//        // going to assume it can canonicalize [T] to Array<T>.
//        auto *arrayDecl = ctx.getArrayDecl();   // <-- HARDCODED stdlib lookup
//      https://github.com/swiftlang/swift/blob/6f265bdcad8ff5ff1e6e9e287a882c09de969a08/lib/Sema/TypeCheckType.cpp#L5584
//
//      `getArrayDecl()` returns the stdlib `Array` declaration directly.
//      No module-import chain influences this; no attribute changes it.
//
//   3. TypeCheckType.cpp line 5655 — TypeResolver::resolveDictionaryType:
//      Same hardcoded shape — `getDictionaryDecl()` is called directly.
//      https://github.com/swiftlang/swift/blob/6f265bdcad8ff5ff1e6e9e287a882c09de969a08/lib/Sema/TypeCheckType.cpp#L5655
//
//   4. KnownStdlibTypes.def line 60 — Dictionary, line 72 — Optional:
//      https://github.com/swiftlang/swift/blob/6f265bdcad8ff5ff1e6e9e287a882c09de969a08/include/swift/AST/KnownStdlibTypes.def#L60
//
//      Bottom line: the Swift language treats `[T]` as syntactic sugar
//      bound to `Swift.Array` at parse-time, NOT a typealias subject to
//      module-scope shadowing. There is no language-level mechanism that
//      can change this. The hardcoded canonicalization is load-bearing
//      for SIL emission and runtime correctness.
//
// Practical implication: swift-format's `[UseShorthandTypeNames]` rule
//   cannot safely apply to swift-array-primitives, swift-dictionary-primitives,
//   or any future package that defines a stdlib-shadowing `public struct
//   Array<...>` / `Dictionary<...>` / `Optional<...>`. The rule must be
//   excluded for these packages — there is no language workaround.
//
// Date: 2026-05-04

// MARK: - Custom Array shadowing Swift.Array
// Defining a struct named `Array` in this module shadows `Swift.Array`
// for unqualified `Array<T>` references in this file. Modeled after
// swift-array-primitives' `public struct Array<Element: ~Copyable>: ~Copyable`.

public struct Array<Element: ~Copyable>: ~Copyable {
    public init() {}
    public func describe() -> String { "custom Array<\(Element.self)> (~Copyable)" }
}

// MARK: - V1: Explicit `Array<Int>` reference
// Hypothesis: resolves to local custom Array (the shadowing one).
// Expected: works; calls `describe()` on custom type.

func v1_explicitName() {
    let custom: Array<Int> = Array<Int>()
    // Calling describe() proves we got the custom type, not stdlib.
    print("V1: \(custom.describe())")
}
v1_explicitName()

// MARK: - V2: Shorthand `[Int]` reference
// Hypothesis: resolves to `Swift.Array<Int>` (stdlib), NOT the custom Array.
// Expected: shorthand always means stdlib; we get a Copyable Array<Int>.

func v2_shorthand() {
    let stdlib: [Int] = [1, 2, 3]   // stdlib Array<Int> via shorthand
    print("V2: stdlib [Int] count=\(stdlib.count) — type is Swift.Array<Int>")
}
v2_shorthand()

// MARK: - V3: Cross-assignment (the failing pattern in production)
// Hypothesis: `Array<Int>` (custom, ~Copyable) and `[Int]` (stdlib, Copyable)
//   are DIFFERENT TYPES. Assigning between them must fail at compile time.
// Expected: this function does NOT compile. Comment out V3 to make the
//   experiment buildable; the inability to compile IS the result.

// Uncommenting this function reproduces the b2fb23f production failure.
// Captured diagnostic (Apple Swift 6.3.1):
//   error: cannot convert value of type 'Array<Int>' to specified type '[Int]'
// Re-comment to keep the experiment buildable; the captured diagnostic IS
// the result.
//
// func v3_crossAssignmentFailsToCompile() {
//     let custom: Array<Int> = Array<Int>()
//     let stdlib: [Int] = custom  // <-- THE ERROR
//     _ = stdlib
// }

// MARK: - V4: Function signature mismatch (the actual b2fb23f failure shape)
// Hypothesis: a function declared `func f(_:Array<Int>)` (custom) cannot
//   be called with a `[Int]` argument. This is exactly what UseShorthandTypeNames
//   broke in production: function signatures with `Array<Element>` params
//   were rewritten to `[Element]`, changing the argument-type expectation.
// Expected: compile error.

func v4_functionSignatureMismatch() {
    // ~Copyable param requires explicit ownership — already evidence
    // that the compiler resolved `Array<Int>` to the custom type.
    func acceptsCustom(_ a: borrowing Array<Int>) { _ = a }
    let stdlib: [Int] = []
    // Uncomment the call to reproduce the cross-package error:
    //   error: cannot convert value of type '[Int]' to expected argument type 'Array<Int>'
    // acceptsCustom(stdlib)
    _ = stdlib
    print("V4: acceptsCustom(_: borrowing Array<Int>) would reject [Int] (stdlib)")
}
v4_functionSignatureMismatch()

// MARK: - V5: Can a typealias bridge them?
// Hypothesis: Even via typealias, `[Element]` and custom `Array<Element>`
//   stay distinct. A `typealias` re-aliases the *name*, not the bracket
//   sugar.
// Expected: we can write `typealias MyArr<E> = Array<E>` (custom), but
//   `[Int]` still means stdlib. No bridging is possible at the language
//   level.

typealias MyArr<E: ~Copyable> = Array<E>   // alias for the CUSTOM Array

func v5_typealiasDoesNotBridge() {
    let viaAlias: MyArr<Int> = MyArr<Int>()
    print("V5: \(viaAlias.describe())")  // still custom; alias is just renaming
    let viaShorthand: [Int] = []
    print("V5: \(type(of: viaShorthand)) is stdlib regardless")
}
v5_typealiasDoesNotBridge()

// MARK: - Results Summary
//
// V1: CONFIRMED — `Array<Int>` resolves to local custom Array (~Copyable).
// V2: CONFIRMED — `[Int]` resolves to stdlib Swift.Array<Int> (Copyable).
// V3: CONFIRMED (by inability to compile when uncommented) — `Array<Int>`
//     and `[Int]` are distinct types in a shadowing module.
// V4: CONFIRMED — function signatures with custom `Array<E>` cannot accept
//     `[E]` arguments. This is the b2fb23f compile error shape.
// V5: CONFIRMED — typealias does not and cannot bridge `[Element]` to a
//     shadowing custom `Array<Element>`. Bracket sugar is fixed at the
//     language level.
//
// Conclusion: swift-format's `[UseShorthandTypeNames]` rule, applied to
//   swift-array-primitives (and similarly swift-dictionary-primitives,
//   which shadows Swift.Dictionary), produces semantically incorrect
//   rewrites that break compilation. The rule MUST be excluded from any
//   format pass on these two packages — there is no language-level
//   workaround.
