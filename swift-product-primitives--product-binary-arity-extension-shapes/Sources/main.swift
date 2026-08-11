// MARK: - Product Binary-Arity Extension Shapes
//
// Purpose: Discover whether Swift 6.3.1 admits any "evergreen" extension shape
//          for n=2-only operations on `Product<each Element>` other than the
//          baseline top-level free function.
//
// Hypothesis: At least one of the following compiles AND has a clean call site,
//             making it a better-than-free-function form for `swapped(_:)`:
//
//   V1. extension Product<First, Second> { func swapped() -> ... }
//   V2. extension Product where Self == Product<First, Second>
//   V3. extension Product where (each Element) == (First, Second)
//   V4. static func swap<First, Second>(_:) inside extension Product
//       (callable as `Product.swap(pair)` without explicit pack)
//   V5. nested enum Product.Binary with static method
//       (compiles AND callable as `Product.Binary.swap(pair)` without explicit pack)
//   V6. method-level generic instance method using values-tuple type
//   V7. init(swapping:) secondary initializer
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform:  macOS 26 (arm64)
// Date:      2026-05-08
//
// Status: PARTIAL
// Result: REFUTED for the "nested-on-Product evergreen form" hypothesis.
//         Two viable forms remain (V0 free function, V8 namespace enum); they
//         are structurally equivalent and migrate to the future `extension
//         Product<First, Second>` shape via a one-line rename when Swift
//         admits same-element/concrete-arity pack constraints.
//
// Output (verified): ("x", 1) for V0, V4, V5d, V8.
// Build:  Build complete. (0.61s)
//
// Each variant is its own #if/Swift block. Compile by un-commenting the block
// you want to test. Variants that do not compile are kept in /* ... */ with
// the captured diagnostic above.

// MARK: - Local Product (copy of swift-product-primitives' Product.swift body)

@dynamicMemberLookup
struct Product<each Element> {
    var values: (repeat each Element)
    init(_ values: repeat each Element) { self.values = (repeat each values) }
    subscript<T>(dynamicMember keyPath: KeyPath<(repeat each Element), T>) -> T {
        values[keyPath: keyPath]
    }
}

// MARK: - Baseline V0: Top-level free function (current state)
// Status: COMPILES (this is the existing form we're trying to improve on)

func swappedFree<First, Second>(
    _ p: Product<First, Second>
) -> Product<Second, First> {
    Product(p.values.1, p.values.0)
}

// MARK: - V1: extension Product<First, Second>
// Hypothesis: Swift 6.3.1 may admit concrete-arity extension on a parameter-pack
//             generic type, letting us write `extension Product<First, Second>`.
// Result: REFUTED — "same-element requirements are not yet supported".
//
// Diagnostic (verbatim):
//   error: same-element requirements are not yet supported
//
/*
extension Product<First, Second> {
    func swappedV1() -> Product<Second, First> {
        Product(values.1, values.0)
    }
}
*/

// MARK: - V2: extension Product where Self == Product<First, Second>
// Hypothesis: Self-equality constraint with method-level generics may bind
//             the pack to a concrete (First, Second) tuple of types.
// Result: REFUTED — `Self` cannot be constrained to a same-type pack
//                   instantiation; the method-level generics aren't visible
//                   in the where-clause.
//
// Diagnostic (verbatim):
//   error: cannot find type 'First' in scope
//   error: cannot find type 'Second' in scope
//
/*
extension Product {
    func swappedV2<First, Second>() -> Product<Second, First>
    where Self == Product<First, Second>
    {
        Product(values.1, values.0)
    }
}
*/

// MARK: - V3: extension Product where (each Element) == (First, Second)
// Hypothesis: SE-0411 (concrete same-type constraints for pack type parameters)
//             may admit a tuple on the right-hand side, binding the entire pack.
// Result: REFUTED — same-type constraints between a pack and a tuple type are
//                   not supported; SE-0411 only enables per-element constraints.
//
// Diagnostic (verbatim):
//   error: cannot find type 'First' in scope
//   error: cannot find type 'Second' in scope
//   (the (each Element) == (First, Second) form is rejected before the
//    method-level generics are visible)
//
/*
extension Product {
    func swappedV3<First, Second>() -> Product<Second, First>
    where (repeat each Element) == (First, Second)
    {
        Product(values.1, values.0)
    }
}
*/

// MARK: - V4: static func with method-level generics inside extension Product
// Hypothesis: Even though we can't constrain the extension, the static method's
//             own <First, Second> may infer the pack from its argument.
//             Already shown REFUTED at the call site (each Element can't be
//             inferred for `Product`); re-confirming here.
// Result: REFUTED at call site — `Product.swapV4(pair)` cannot infer
//                                  `each Element` for `Product`.
//
// Diagnostic at call site (verbatim):
//   error: generic parameter 'each Element' could not be inferred
//   note:  explicitly specify the generic arguments to fix this issue

extension Product {
    static func swapV4<First, Second>(
        _ p: Product<First, Second>
    ) -> Product<Second, First> {
        // NOTE: explicit `Product<Second, First>(...)` is required here.
        // Bare `Product(...)` resolves to `Self` (the outer pack) and yields:
        //   error: pack expansion requires that 'each Element' and 'Second, First'
        //          have the same shape
        Product<Second, First>(p.values.1, p.values.0)
    }
}

// Call the static method, fully spelling the type each time, to verify the
// declaration itself compiles even if the natural call site doesn't.
let _v4_pair = Product(1, "x")
let _v4_swapped: Product<String, Int> = Product<Int, String>.swapV4(_v4_pair)

// The natural call would be:
//   let mapped = Product.swapV4(pair)
// which fails as documented above.

// MARK: - V5: nested enum namespace `Product.Binary`
// Hypothesis: An empty nested enum that does not reference the pack may compile
//             inside `extension Product`. If yes, static methods on that nested
//             enum could be callable as `Product.Binary.swap(pair)`.
// Result: REFUTED at declaration — Swift rejects ANY enum declared inside
//         `extension Product { ... }`, regardless of whether the enum's body
//         references the pack. The check fires on the enum declaration itself
//         because `each Element` is in scope at the declaration site.
//
// Diagnostic (verbatim, captured 2026-05-08):
//   error: enums cannot declare a type pack
//
// Workaround attempted: `struct Binary {}` instead of `enum Binary {}` —
// this DOES compile (struct doesn't trip the type-pack check), so a struct
// namespace would be the workaround if pursued. But the call-site issue
// remains: `Product.Binary.swap(p)` cannot infer `each Element` (same as V4).
// Documenting as REFUTED for the ergonomic outcome.
//
/*
extension Product {
    enum Binary {}                  // <-- rejected: "enums cannot declare a type pack"
}

extension Product.Binary {
    static func swap<First, Second>(
        _ p: Product<First, Second>
    ) -> Product<Second, First> {
        Product<Second, First>(p.values.1, p.values.0)
    }
}
*/

// V5-alt: try the same shape with `struct Binary` instead of `enum Binary`.
// Hypothesis: `struct` does not trip the type-pack check, so the namespace
// can be declared. Call site still fails inference (same as V4).

extension Product {
    struct Binary {}
}

extension Product.Binary {
    static func swap<First, Second>(
        _ p: Product<First, Second>
    ) -> Product<Second, First> {
        // Bare `Product(...)` would infer Self with the outer pack; explicit
        // `Product<Second, First>(...)` is required.
        Product<Second, First>(p.values.1, p.values.0)
    }
}

let _v5_pair = Product(1, "x")
// Natural call site: `Product.Binary.swap(_v5_pair)` — fails inference.
//   error: generic parameter 'each Element' could not be inferred
//
// Explicit pack spelling: works, but is strictly worse than the free function:
let _v5_explicit: Product<String, Int> =
    Product<Int, String>.Binary.swap(_v5_pair)

// MARK: - V6: method-level generics on values-tuple type
// Hypothesis: A method-level generic instance method could match the pack via
//             the values-tuple's static type, returning a swapped Product.
// Result: REFUTED — there is no syntactic way to require `(repeat each Element)`
//                   to be a 2-tuple at the method level. The constraint
//                   needed (`Self.values: (First, Second)`) doesn't exist as
//                   syntax in 6.3.1.
//
// (No code form is even expressible to reject; documented for completeness.)

// MARK: - V7: secondary initializer `init(swapping:)`
// Hypothesis: A secondary initializer may sidestep the extension constraint by
//             accepting a `Product<Second, First>` and mapping fields.
// Result: REFUTED — declaration cannot resolve a body. The `where Self ==
//                   Product<Second, First>` constraint does NOT bind the pack
//                   inside the init body; `other.values` retains type
//                   `(First, Second)` but `self.init(...)` still expects a pack
//                   matching the OUTER `each Element`, not the concrete pair.
//
// Diagnostic (verbatim, captured 2026-05-08):
//   error: cannot convert value of type 'each Element' to expected argument type '_, _'
//   error: value of tuple type '(First, Second)' has no member '1'
//   error: value pack expansion can only appear inside a function argument list,
//          tuple element, or as the expression of a for-in loop
//
/*
extension Product {
    init<First, Second>(
        swapping other: Product<First, Second>
    ) where Self == Product<Second, First> {
        self.init(other.values.1, other.values.0)
    }
}
*/

// MARK: - V8: top-level namespace enum at module scope (`ProductOps.swap(_:)`)
// Hypothesis: A top-level enum namespace may host the swap function as a static
//             method, replacing the global `swappedFree(_:)` with `ProductOps.swap(_:)`.
//             Call site is namespaced; cost is adding ONE top-level type
//             instead of ONE top-level function.
// Result: COMPILES; call site is clean.

enum ProductOps {}

extension ProductOps {
    static func swap<First, Second>(
        _ p: Product<First, Second>
    ) -> Product<Second, First> {
        // V8 lives at module scope (not in `extension Product`), so bare
        // `Product(...)` correctly infers from arguments. No outer-pack collision.
        Product(p.values.1, p.values.0)
    }
}

let _v8_pair = Product(1, "x")
let _v8_swapped = ProductOps.swap(_v8_pair)
// V8 Result: COMPILES. Trades a top-level function for a top-level enum
//            namespace. The verb (`swap`) is the namespace's only member, so
//            it doesn't shadow stdlib `swap(_:_:)` either way. Whether this
//            is "better than V0 free function" is a taste call: V0 is one
//            global identifier (the function), V8 is one global identifier
//            (the enum), and both have the same arity-1 namespace surface.

// MARK: - Results Summary
//
// | Variant | Declaration  | Natural call site | Verdict                                 |
// |---------|--------------|-------------------|-----------------------------------------|
// | V0 free | COMPILES     | clean             | Baseline; namespace pollution is the only cost |
// | V1      | REFUTED      | n/a               | Pack same-type-to-tuple not supported   |
// | V2      | REFUTED      | n/a               | Self-equality with method generics not supported |
// | V3      | REFUTED      | n/a               | (each Element) == (T, U) not supported  |
// | V4      | COMPILES     | REFUTED           | Static; pack inference fails on call    |
// | V5      | REFUTED      | n/a               | `enum Binary {}` inside `extension Product` rejected ("enums cannot declare a type pack") |
// | V5-alt  | COMPILES     | UNUSABLE          | `struct Binary {}` workaround compiles but call site still requires explicit pack |
// | V6      | NOT EXPRESSIBLE | n/a            | No syntax for pack-arity-2 constraint   |
// | V7      | REFUTED      | n/a               | init body can't access pack-as-tuple inside `where Self == ...` |
// | V8      | COMPILES     | clean             | `ProductOps.swap(p)` — module-scope namespace enum, clean call site |
//
// CONCLUSION: PARTIAL — there is no nested-on-Product evergreen form in
//             Swift 6.3.1. Every alternative that lives inside `extension
//             Product` either fails to compile (V1/V2/V3/V6/V7), fails
//             inference at the call site (V4/V5c), or requires explicit pack
//             spelling that's strictly worse than the baseline (V5d).
//
//             Two viable forms remain, both at MODULE SCOPE: V0 (free function)
//             and V8 (namespace enum). Both add exactly one top-level identifier.
//             V0's identifier is the verb `swappedFree`; V8's is the noun
//             `ProductOps`. Choice is stylistic.
//
// EVERGREEN HYPOTHESIS: When Swift admits either (a) tuple-to-pack same-type
//             constraints OR (b) concrete-arity extensions on packs (the V1
//             form, today refused as "same-element requirements are not yet
//             supported"), the canonical evergreen form becomes
//             `extension Product<First, Second> { func swapped() -> Product<Second, First> }`.
//
//             Migration cost from today's V0/V8 to that future V1 is one rename
//             — the call site changes from `swappedFree(p)` (or `ProductOps.swap(p)`)
//             to `p.swapped`. Both V0 and V8 are equally forward-compatible.

// Output a sentinel so `swift run` produces non-empty output.
print("v0-free:", swappedFree(Product(1, "x")).values)
print("v4-explicit:", _v4_swapped.values)
print("v5d-explicit:", _v5_explicit.values)
print("v8-namespace:", _v8_swapped.values)
