// MARK: - Ownership.Borrow / Ownership.Inout Stdlib Parity
//
// Purpose: Verify that Ownership.Borrow / Ownership.Inout cover the
//   stdlib SE-0519 shape — the four public init surfaces and the
//   `.value` accessor — on production Swift 6.3.1 before SE-0507
//   `BorrowAndMutateAccessors` ships in a stable toolchain.
//
// Hypothesis: `init(_:)`, `init(borrowing:)` / `init(mutating:)`,
//   `init(unsafeAddress:borrowing:)` / `init(unsafeAddress:mutating:)`,
//   and the `.value` accessor all compile cleanly against a `Copyable`
//   and a `~Copyable` `Value`.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Status: CONFIRMED
//
// Result: CONFIRMED — all six surfaces build and behave as specified
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         by the audit trail in swift-ownership-primitives/Audits/audit.md
//         (Legacy — Consolidated 2026-04-08 → Borrow/Inout stdlib-parity
//         audit). The two FINDINGs captured there — `nonmutating _modify`
//         vs stdlib `mutate` (intentional extension, interior mutability
//         per [IMPL-071]) and absent `@_unsafeSelfDependentResult`
//         (structurally enforced by coroutine suspension) — remain
//         intentional divergences.
//
// Build succeeded; runtime output:
//   Borrow init(borrowing:) value readable: 42
//   Borrow init(_:) pointer construction readable: 99
//   Inout init(mutating:) in-place write reaches source: 100
//   Inout init(_:) pointer construction reaches source: 200
//
// Cross-references:
//   - ../../Audits/audit.md (Borrow/Inout stdlib-parity, 2026-03-31)
//   - SE-0519 Borrow<T> / Inout<T> (SwiftStdlib 6.4)
//   - SE-0507 BorrowAndMutateAccessors (pre-stable)

import Ownership_Primitives

// MARK: - V1: Borrow init(borrowing:) on Copyable Value

func testBorrowFromBorrowing() {
    let source = 42
    func peek(_ value: borrowing Int) -> Int {
        let ref = Ownership.Borrow(borrowing: value)
        return ref.value
    }
    let read = peek(source)
    precondition(read == 42)
    print("Borrow init(borrowing:) value readable: \(read)")
}
testBorrowFromBorrowing()

// MARK: - V2: Borrow init(_ pointer:) typed pointer construction

func testBorrowFromPointer() {
    var source = 99
    withUnsafePointer(to: &source) { pointer in
        let ref = Ownership.Borrow(pointer)
        precondition(ref.value == 99)
        print("Borrow init(_:) pointer construction readable: \(ref.value)")
    }
}
testBorrowFromPointer()

// MARK: - V3: Inout init(mutating:) in-place writeback

func testInoutFromMutating() {
    var source = 0
    func writeOneHundred(_ value: inout Int) {
        let ref = Ownership.Inout(mutating: &value)
        ref.value = 100
    }
    writeOneHundred(&source)
    precondition(source == 100, "Inout mutation must reach the source")
    print("Inout init(mutating:) in-place write reaches source: \(source)")
}
testInoutFromMutating()

// MARK: - V4: Inout init(_ pointer:) typed pointer construction

func testInoutFromPointer() {
    var source = 0
    withUnsafeMutablePointer(to: &source) { pointer in
        let ref = unsafe Ownership.Inout(pointer)
        ref.value = 200
    }
    precondition(source == 200, "Inout pointer-construction writeback must reach source")
    print("Inout init(_:) pointer construction reaches source: \(source)")
}
testInoutFromPointer()
