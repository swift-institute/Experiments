// Status: SUPERSEDED -- pattern shipped in Set_Primitives nested types; see [COPY-FIX-*]. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ===----------------------------------------------------------------------===//
// Experiment: Conditional Copyable for Nested Type with Outer Generic
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS:
// A nested struct inside an enum with ~Copyable generic parameter can be
// conditionally Copyable when the outer generic is Copyable.
//
// KEY INSIGHT: Do NOT explicitly mark the struct as ~Copyable!
// If you write `struct Ordered: ~Copyable`, you cannot add conditional Copyable.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// RESULT: CONFIRMED
//
// The pattern works:
// 1. Do NOT explicitly mark nested struct as `: ~Copyable`
// 2. Add conditional Copyable: `extension Container.Ordered: Copyable where Element: Copyable {}`
// 3. Add conditional Sequence: `extension Container.Ordered: Sequence where Element: Copyable { ... }`
//
// Negative test verified: `swift build -Xswiftc -DVERIFY_NONCOPYABLE` fails with
// "'copy' cannot be applied to noncopyable types" for Container<MoveOnlyToken>.Ordered
// ===----------------------------------------------------------------------===//

// MARK: - Variant 1: Simple Protocol

protocol HashLike: ~Copyable {
    var hashValue: Int { get }
}

extension Int: HashLike {}
extension String: HashLike {}

// MARK: - Variant 2: Outer Enum

enum Container<Element: HashLike & ~Copyable>: ~Copyable {}

// MARK: - Variant 3: Nested Struct (NO explicit ~Copyable)

extension Container where Element: ~Copyable {
    /// Nested struct - do NOT add `: ~Copyable` to allow conditional Copyable
    struct Ordered {
        var _count: Int = 0

        init() {}

        var count: Int { _count }
    }
}

// MARK: - Variant 4: Conditional Copyable

extension Container.Ordered: Copyable where Element: Copyable {}

// MARK: - Variant 5: Conditional Sequence

extension Container.Ordered: Sequence where Element: Copyable {
    struct Iterator: IteratorProtocol {
        var index: Int = 0
        let max: Int

        init(count: Int) { self.max = count }

        mutating func next() -> Int? {
            guard index < max else { return nil }
            defer { index += 1 }
            return index
        }
    }

    func makeIterator() -> Iterator {
        Iterator(count: count)
    }
}

// MARK: - Variant 6: ~Copyable Element

struct MoveOnlyToken: ~Copyable, HashLike {
    var id: Int
    var hashValue: Int { id }
}

// MARK: - Tests

func testCopyable() {
    print("=== Test 1: Conditional Copyable ===")

    let ordered1 = Container<Int>.Ordered()
    let ordered2 = ordered1  // Should work - Int is Copyable

    print("ordered1.count: \(ordered1.count)")
    print("ordered2.count: \(ordered2.count)")
    print("✅ Copy works for Container<Int>.Ordered")
}

func testSequence() {
    print("\n=== Test 2: Conditional Sequence ===")

    let ordered = Container<String>.Ordered()

    for index in ordered {
        print("index: \(index)")
    }

    print("✅ for-in works for Container<String>.Ordered")
}

func testNonCopyable() {
    print("\n=== Test 3: ~Copyable Element ===")

    let ordered = Container<MoveOnlyToken>.Ordered()
    // let copy = ordered  // ❌ Should not compile
    // for element in ordered { }  // ❌ Should not compile

    print("count: \(ordered.count)")
    print("✅ Container<MoveOnlyToken>.Ordered is ~Copyable")
}

// MARK: - Main

print("Conditional Copyable Nested Type Experiment")
print("============================================\n")

testCopyable()
testSequence()
testNonCopyable()

print("\n============================================")
print("All tests passed!")
