// Status: SUPERSEDED -- ~Copyable verification absorbed into [MEM-COPY-*] and [COPY-FIX-*]. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ===----------------------------------------------------------------------===//
// Experiment: Verify ~Copyable Behavior
// ===----------------------------------------------------------------------===//
//
// QUESTION:
// With class-based storage, is Hash.Table<MoveOnlyType> correctly ~Copyable?
// Or does it incorrectly become Copyable (sharing storage reference)?
//
// METHODOLOGY: [EXP-004a] Compile-time verification
// Code that should compile + code that should NOT compile.
//
// EXPECTED:
// - Set.Ordered<Int> (Copyable) should allow copy
// - Set.Ordered<MoveOnly> should NOT allow copy (compile error)
// ===----------------------------------------------------------------------===//

import Set_Primitives
import Hash_Primitives
import Equation_Primitives

// A move-only type for testing
struct MoveOnly: ~Copyable, Hash.`Protocol` {
    var value: Int

    static func == (lhs: borrowing MoveOnly, rhs: borrowing MoveOnly) -> Bool {
        lhs.value == rhs.value
    }

    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

print("=== Verify ~Copyable Behavior ===\n")

// MARK: - Test 1: Copyable elements CAN be copied

print("Test 1: Set.Ordered<Int> should be Copyable")
do {
    var set1 = Set<Int>.Ordered()
    set1.insert(1)
    set1.insert(2)

    let set2 = set1  // This SHOULD compile - Int is Copyable

    // Verify they are independent (CoW)
    var set3 = set1
    set3.insert(3)

    print("  set1.count: \(set1.count)")  // Should be 2
    print("  set2.count: \(set2.count)")  // Should be 2
    print("  set3.count: \(set3.count)")  // Should be 3
    print("  ✅ Copyable elements work correctly")
}

// MARK: - Test 2: ~Copyable elements should NOT allow copy

print("\nTest 2: Set.Ordered<MoveOnly> should be ~Copyable")
do {
    var set1 = Set<MoveOnly>.Ordered()
    set1.insert(MoveOnly(value: 1))
    set1.insert(MoveOnly(value: 2))

    // UNCOMMENT THE LINE BELOW - IT SHOULD FAIL TO COMPILE
    // let set2 = set1  // ERROR: Cannot copy value of type '~Copyable'

    print("  set1.count: \(set1.count)")
    print("  ✅ ~Copyable elements prevent copying (line commented out)")
    print("  ⚠️  MANUALLY VERIFY: Uncomment the copy line to confirm compile error")
}

// MARK: - Test 3: Consuming transfer works

print("\nTest 3: Consuming transfer should work for ~Copyable")
do {
    var set1 = Set<MoveOnly>.Ordered()
    set1.insert(MoveOnly(value: 1))
    set1.insert(MoveOnly(value: 2))

    let set2 = consume set1  // Transfer ownership

    // set1 is now uninitialized - cannot use
    // print(set1.count)  // ERROR: used after consume

    print("  set2.count: \(set2.count)")
    print("  ✅ Consuming transfer works")
}

print("\n=== Verification Complete ===")
print("\nTo fully verify, uncomment the copy line in Test 2 and confirm it fails to compile.")
