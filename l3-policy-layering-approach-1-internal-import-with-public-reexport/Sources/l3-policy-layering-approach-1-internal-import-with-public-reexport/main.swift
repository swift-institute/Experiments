// MARK: - Approach 1: internal import + public import of same module
// Purpose: Test whether Swift allows declaring `internal import X` AND
//          `public import X` for the same module in one source file. If so,
//          would the dual-import allow L3 to "see" L2's methods (via internal)
//          while NOT re-exporting them to consumers (via internal-only)?
// Hypothesis: Swift will likely reject the duplicate import, OR treat the
//             public import as winning (then L2's methods are visible to
//             consumers, defeating the purpose).
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.2 (arm64)
//
// Result: REFUTED — public import does NOT re-export to consumer scope
// Date: 2026-05-02
//
// Build: L3Policy compiles (Swift accepts duplicate `internal import X` +
//        `public import X`). Consumer fails to compile:
//          error: cannot find 'Foo' in scope
//          error: cannot find type 'Foo' in scope
//
// Diagnostic: `public import L2Methods` makes L2Methods part of L3Policy's
// API stability surface, but does NOT re-export L2Methods's exported
// symbols (Foo, FooError) into the consumer's name resolution scope.
// To re-export, the import must be `@_exported public import` — but
// adding @_exported makes L2Methods's `make()` visible to consumers,
// reintroducing the L2/L3 same-signature collision (= approach 8 territory).
//
// What it rules out: There is no Swift import-attribute combination that
// (a) lets L3's body see L2's methods AND (b) does NOT re-export those
// methods to consumers. `public import` without `@_exported` doesn't
// re-export at all (consumer can't see types). With `@_exported`, methods
// become visible to consumers and the disambiguation problem returns.
// Swift's import system has no "types-only re-export" granularity; that
// granularity must come from packaging (see approach 2: types-only
// module split).

import L3Policy

let result = try Foo.make()
print("Foo.make() returned tag = \(result.tag)")

let typed: Foo = result
print("Type identity preserved: \(typed.tag)")
