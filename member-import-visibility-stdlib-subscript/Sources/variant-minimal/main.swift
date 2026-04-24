// MARK: - Swift 6.2 Generic Subscript Parameter Name Bug
//
// Purpose: Minimal reproduction of a compiler bug where generic extension
//          subscripts fail when the external label equals the internal param name.
//
// Hypothesis: subscript<O: P>(position: O) fails at call site because the compiler
//             treats the unified label/name `position` incorrectly during subscript
//             lookup, reporting "extraneous argument label 'position:'".
//             Using separate label/name subscript<O: P>(position o: O) works.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — Bug reproduces on ANY type (Array, UnsafePointer, custom structs).
//         Not feature-dependent — fails with and without MemberImportVisibility/InternalImportsByDefault.
//         Not cross-module — fails even in the same file.
//         Non-generic subscripts and generic methods unaffected.
//
// Date: 2026-02-10

// ── Setup ──

protocol P { var rawValue: Int { get } }
struct Idx: P { var rawValue: Int }

// ── FAILS: label == param name ──
//
// extension Array {
//     subscript<O: P>(position: O) -> Element { self[position.rawValue] }
// }
// print([1, 2, 3][position: Idx(rawValue: 0)])
// ^ error: extraneous argument label 'position:' in subscript

// ── WORKS: separate label and param name ──

extension Array {
    subscript<O: P>(position position_: O) -> Element { self[position_.rawValue] }
}

print([1, 2, 3][position: Idx(rawValue: 0)])
// Output: 1

// ── Results Summary ──
//
// BROKEN patterns (all fail with same error):
//   subscript<O: P>(position: O)     — unified label/name
//   subscript<O: P>(foo: O)          — any label, as long as label == name
//
// WORKING patterns (all compile and run):
//   subscript<O: P>(position o: O)   — separate label and name
//   subscript<O: P>(position _: O)   — underscore internal name
//   subscript(position: Idx)         — non-generic subscript
//   func element<O: P>(at: O)        — generic METHOD (not subscript)
//
// Affected types: ALL — Array, UnsafePointer, UnsafeMutablePointer,
//   UnsafeBufferPointer, UnsafeMutableBufferPointer, InlineArray,
//   ContiguousArray, Dictionary, and custom user-defined types.
//
// Impact on swift-primitives: 4 files in Ordinal_Primitives_Standard_Library_Integration
//   all use subscript<O: Ordinal.Protocol>(position: O) — the broken pattern.
//   Workaround: change to subscript<O: Ordinal.Protocol>(position position_: O)
