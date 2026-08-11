// Counterexample 01 — the CURRENT collision (the motivation).
// Expected: REFUTED — does NOT compile.
//   error: cannot specialize non-generic type 'Span'
//
// With the package's non-generic `enum Span {}` namespace in scope, a consumer
// cannot spell the stdlib span as the bare `Span<Int>` — they are forced to the
// fully-qualified `Swift.Span<Int>`. This is the problem the experiment addresses.
//
// Reproduce:
//   swiftc -swift-version 6 -parse-as-library -typecheck 01-baseline-collision.swift

public enum Span {}                        // the package's namespace enum (today)

func wants(_ s: Span<Int>) -> Int { 0 }    // intended: stdlib span — but `Span` is the enum
