// Counterexample 02 — you cannot keep BOTH a non-generic `Span` host and the alias.
// Expected: REFUTED — does NOT compile.
//   error: invalid redeclaration of 'Span'
//
// This is why the capability protocols cannot simply stay under a non-generic
// `enum Span` while `Span<E>` also aliases the stdlib type: Swift has no
// arity-based overloading of type names. One name, one declaration. Hence the
// capability must move (Design B) or be surfaced as a member of the alias's
// underlying type (Design A).
//
// Reproduce:
//   swiftc -swift-version 6 -parse-as-library -typecheck 02-host-alias-redeclaration.swift

enum Span {}                                            // host
typealias Span<Element: ~Copyable> = Swift.Span<Element>   // alias — collides
