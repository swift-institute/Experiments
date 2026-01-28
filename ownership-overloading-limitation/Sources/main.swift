// MARK: - Consuming Semantics Investigation
// Purpose: Determine if Swift's ownership modifiers can replace naming conventions
//
// Toolchain: Apple Swift version 6.2.3
// Date: 2026-01-22
//
// ============================================================================
// FINDINGS SUMMARY
// ============================================================================
//
// [Q1] Can we overload methods by ownership modifier (borrowing vs consuming)?
//      ANSWER: NO - "invalid redeclaration" error
//
// [Q2] Can consuming func forEach coexist with borrowing func forEach?
//      ANSWER: NO - Same signature, different ownership = redeclaration error
//
// [Q3] Does the compiler disambiguate based on call-site context?
//      ANSWER: NO - Reports "ambiguous use" even with different return types
//
// [Q4] Can closure parameter ownership disambiguate?
//      ANSWER: NO - (borrowing Element) vs (consuming Element) = ambiguous
//
// [Q5] What about property vs consuming method with same name?
//      ANSWER: NO - "invalid redeclaration" error
//
// [Q6] Can ~Copyable types conform to Sequence?
//      ANSWER: NO - Sequence requires Copyable conformance
//
// CONCLUSION: The naming convention (consumingForEach, makeConsumingIterator)
// is REQUIRED. Swift 6.2 does not support ownership-based overloading.
//
// ============================================================================

// MARK: - What DOES Work

// 1. Different names for different ownership semantics
struct Container1<Element: Hashable>: ~Copyable {
    var elements: [Element]

    init(_ elements: [Element]) {
