// MARK: - Typealias Without Re-export
// Purpose: Validate that removing @_exported from String_Primitives
//          in Kernel_Primitives stops bare `String` from shadowing Swift.String,
//          while Kernel.String typealias still provides full access.
//
// Hypothesis: With `public import` (not @_exported), the typealias
//             exposes the type through the namespace but bare `String`
//             resolves to Swift.String in downstream modules.
//
// Toolchain: Swift 6.2 (Xcode 26 beta)
// Platform: macOS 26 (arm64)
//
// Result: PARTIALLY REFUTED — see variants below
// Date: 2026-02-27
//
// KEY FINDING: MemberImportVisibility creates an inescapable tension:
//   - Without importing StringLike: bare String = Swift.String, BUT
//     ALL member access on Kernel.String fails (init, properties, methods)
//   - With `internal import StringLike`: members work, BUT
//     bare String is shadowed again (resolves to StringLike.String)
//   - Option A (stop re-exporting) is insufficient on its own.

public import KernelLike

// MARK: - V1: Bare String resolves to Swift.String (NO StringLike import)
// Hypothesis: Without importing StringLike, bare `String` is Swift.String
// Result: CONFIRMED — bare String is Swift.String

let swiftString: String = "hello"  // This IS Swift.String
print("V1: type(of: swiftString) = \(type(of: swiftString))")
print("V1: count = \(swiftString.count)")

// MARK: - V2: Kernel.String type is accessible through typealias
// Hypothesis: The Kernel.String typealias resolves correctly
// Result: CONFIRMED — type is accessible, but NO members work

// let kernelString = Kernel.String(ascii: "world")
// ERROR: initializer 'init(ascii:)' is not available due to missing
//        import of defining module 'StringLike' [#MemberImportVisibility]

// MARK: - V3: Nested types through typealias
// Result: REFUTED — Kernel.String.Char also blocked by MemberImportVisibility

// let char: Kernel.String.Char = 65
// ERROR: type alias 'Char' is not available due to missing import
//        of defining module 'StringLike'

// MARK: - V5: Extension methods blocked too
// Result: REFUTED — isEmpty, count, all methods blocked

// MARK: - V7: Function signatures work (type-level only)
// Result: CONFIRMED — can declare function types, just can't call members

func takesSwiftString(_ s: String) -> Int { s.count }
let a = takesSwiftString("abc")
print("V7: swift=\(a)")

// MARK: - Results Summary
// V1: CONFIRMED - bare String = Swift.String (when StringLike not imported)
// V2: PARTIAL  - typealias resolves at type level, but MemberImportVisibility
//                blocks ALL member access (init, properties, methods, nested types)
// V3: REFUTED  - Kernel.String.Char blocked
// V4: REFUTED  - Kernel.String.View blocked
// V5: REFUTED  - extension methods blocked
// V6: N/A      - @inlinable needs public import (expected)
// V7: CONFIRMED - function signatures using Kernel.String compile
//
// CONCLUSION: Option A (stop re-exporting String_Primitives) prevents
// shadowing but makes Kernel.String unusable — a type without members.
// Adding `internal import StringLike` restores members but re-introduces
// shadowing. MemberImportVisibility makes Option A fundamentally insufficient.
//
// The tension: accessing members requires importing the defining module,
// but importing it shadows Swift.String. No import-level solution exists.
//
// Remaining viable paths:
//   Option B: Phantom-tagged String<Domain> (bare String stays Swift.String)
//   Option A+: Stop re-export + forwarding extensions in KernelLike
//              (re-declare all members in intermediary module)
