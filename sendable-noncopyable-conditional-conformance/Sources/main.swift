// MARK: - Protocol & ~Copyable in Conditional Conformance Where Clauses
// Purpose: Determine which `Protocol & ~Copyable` compositions compile in
//          conditional conformance where clauses on Swift 6.3.
// Hypothesis: `Sendable & ~Copyable` fails like `Equatable & ~Copyable`
//             because the limitation is in the where-clause syntax, not
//             protocol-specific.
//
// Toolchain: Swift 6.3
// Platform: macOS 26.0 (arm64)
//
// Result: HYPOTHESIS REFUTED
//   - `Sendable & ~Copyable` COMPILES — Sendable opts out of Copyable (protocol Sendable: ~Copyable)
//   - `Equatable & ~Copyable` FAILS — Equatable requires Copyable (inherited)
//     Error: "composition cannot contain '~Copyable' when another member requires 'Copyable'"
//   - The `& ~Copyable` in where clauses suppresses the clause's implicit Copyable,
//     but cannot contradict a protocol's own Copyable requirement.
//
// Impact: Pair's Sendable conformance should use `Sendable & ~Copyable` unconditionally,
//         not gated behind #if compiler(>=6.4). Only Equatable/Hashable need the guard.
//
// Date: 2026-04-03

// --- Test infrastructure ---

struct MoveOnly: ~Copyable, Sendable {
    let value: Int
}

struct Box<T: ~Copyable>: ~Copyable {
    var stored: T
    init(_ stored: consuming T) { self.stored = stored }
}

func requireSendable<S: Sendable & ~Copyable>(_: borrowing S) {}

// MARK: - Variant 1: `where T: Sendable` (no ~Copyable suppression)
// Hypothesis: Adds implicit Copyable — Box<MoveOnly> won't be Sendable
// Result: CONFIRMED
//   error: requires that 'MoveOnly' conform to 'Copyable'
//   note: requirement from conditional conformance of 'Box<MoveOnly>' to 'Sendable'

// extension Box: Sendable where T: Sendable {}

// MARK: - Variant 2: `where T: Sendable & ~Copyable`
// Hypothesis: Fails like Equatable & ~Copyable
// Result: REFUTED — Compiles and runs. Build Succeeded.

extension Box: Sendable where T: Sendable & ~Copyable {}

func testVariant2() {
    let copyableBox = Box(42)
    requireSendable(copyableBox)

    let noncopyableBox = Box(MoveOnly(value: 1))
    requireSendable(noncopyableBox)
    print("V2: Sendable & ~Copyable — PASS")
}

// MARK: - Variant 3: `where T: Equatable & ~Copyable`
// Hypothesis: Does not compile on 6.3
// Result: CONFIRMED — does not compile
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   error: composition cannot contain '~Copyable' when another member requires 'Copyable'
//   error: type 'EqBox<T>' does not conform to protocol 'Copyable'
//   note: type 'EqBox<T>' does not conform to inherited protocol 'Copyable'
//   (Equatable implicitly inherits Copyable — the composition is a contradiction)

// struct EqBox<T: ~Copyable>: ~Copyable { var stored: T }
// extension EqBox: Equatable where T: Equatable & ~Copyable {
//     static func == (lhs: borrowing EqBox, rhs: borrowing EqBox) -> Bool { true }
// }

// MARK: - Results Summary
// V1: CONFIRMED — `where T: Sendable` adds implicit Copyable
// V2: REFUTED   — `where T: Sendable & ~Copyable` compiles on 6.3
// V3: CONFIRMED — `where T: Equatable & ~Copyable` fails on 6.3
//
// Key insight: `& ~Copyable` in where clauses suppresses the clause's own
// implicit Copyable addition. It works when the protocol itself opts out of
// Copyable (Sendable). It fails when the protocol requires Copyable (Equatable,
// Hashable) — the suppression contradicts the protocol's requirement.

// MARK: - Entry point

testVariant2()
print("Done")
