// MARK: - ~Escapable Pointer Primitives Feasibility Test
// Purpose: Can we create a pointer type supporting ~Escapable pointees?
//
// Methodology: Incremental construction [EXP-004a]
// Toolchain: Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: BLOCKED - Fundamental language constraint
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-01-24
//
// Blog: BLOG-IDEA-025 "Why You Can't Build a ~Escapable Pointer"
//
// Related Pitches:
// - PITCH-0003 Escapable Pointer Operations
//   swift-institute/SE-Pitches/Draft/PITCH-0003 Escapable Pointer Operations.md
//
// =============================================================================
// EXECUTIVE SUMMARY
// =============================================================================
//
// A swift-pointer-primitives package supporting ~Escapable pointees is
// NOT FEASIBLE with current Swift.
//
// FUNDAMENTAL CONSTRAINT DISCOVERED:
// - Builtin.load<T> requires T: Copyable AND T: Escapable
// - This is the lowest-level memory access operation in Swift
// - All pointer abstractions ultimately depend on Builtin.load
// - There is no way to dereference a pointer to a ~Escapable value
//
// IMPLICATION FOR Property.View:
// - Property.View uses UnsafeMutablePointer<Base>
// - UnsafeMutablePointer requires Escapable pointee
// - Property.View CANNOT be extended to support ~Escapable base types
// - This is not a design flaw - it's a language constraint
//
// EVIDENCE (from compiler output):
//
// Builtin.load:1:13: note: 'where T: Escapable' is implicit here
// 1 | public func load<T>(_: Builtin.RawPointer) -> T
//
// Builtin.load:1:13: note: 'where T: Copyable' is implicit here  
// 1 | public func load<T>(_: Builtin.RawPointer) -> T
//
// =============================================================================
// WORKAROUND FOR BorrowingSequence
// =============================================================================
//
// Since Property.View cannot support ~Escapable:
// 1. Sequence.Borrowing.Protocol remains ~Copyable, ~Escapable
// 2. Property.View extension only requires ~Copyable (implicitly Escapable)
// 3. Types that are ~Escapable must use the protocols directly, not Property.View
// 4. Types that are Escapable can use Property.View normally
//
// This is the principled solution given language constraints.

import Builtin

print("=" * 70)
print("EXPERIMENT RESULT: swift-pointer-primitives NOT FEASIBLE")
print("=" * 70)
print("""

Builtin.load<T> requires both T: Copyable and T: Escapable.
This is a fundamental Swift language constraint.

No pointer-based abstraction can dereference ~Escapable values.

Property.View cannot support ~Escapable base types.
This is not a design limitation - it's a language constraint.

""")

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
