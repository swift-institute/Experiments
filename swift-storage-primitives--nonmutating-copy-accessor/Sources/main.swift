// MARK: - Non-Mutating Copy Accessor for ~Copyable Storage
// Purpose: Can a ~Copyable type expose a non-mutating accessor for read-only (copy) operations?
//
// Hypothesis: Pointer-based Property.View requires mutating. But a Copyable wrapper yielded
//             from a non-mutating _read can provide callAsFunction syntax on `let` bindings.
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — Copyable wrapper from non-mutating _read enables `let` usage
// Date: 2026-02-06

// =============================================================================
// Minimal ~Copyable type (models Storage.Inline)
// =============================================================================

struct Box: ~Copyable {
    var a: Int
    var b: Int
    var count: Int

    init(_ a: Int, _ b: Int) {
        self.a = a
        self.b = b
        self.count = 2
    }
}

// =============================================================================
// MARK: - V1: Non-mutating func
// Hypothesis: Regular `func` works on `let` ~Copyable
// Result: see per-variant
// =============================================================================

extension Box {
    func v1Copy() -> [Int] {
        var result: [Int] = []
        if count > 0 { result.append(a) }
        if count > 1 { result.append(b) }
        return result
    }
}

// =============================================================================
// MARK: - V2: Non-mutating _read yielding Copyable wrapper with callAsFunction
// Hypothesis: _read can yield a Copyable struct from a ~Copyable type without mutating.
//             The wrapper captures values (not pointers), enabling callAsFunction on `let`.
// Result: see per-variant
// =============================================================================

struct CopyAccessor {
    let _a: Int
    let _b: Int
    let _count: Int

    func callAsFunction() -> [Int] {
        var result: [Int] = []
        if _count > 0 { result.append(_a) }
        if _count > 1 { result.append(_b) }
        return result
    }

    func callAsFunction(at index: Int) -> Int? {
        guard index < _count else { return nil }
        return index == 0 ? _a : _b
    }
}

extension Box {
    var copy: CopyAccessor {
        _read {
            yield CopyAccessor(_a: a, _b: b, _count: count)
        }
    }
}

// =============================================================================
// MARK: - V3: Can V2's wrapper also be used as a Property<Tag, ...> extension point?
// Hypothesis: If the wrapper is generic over a Tag, extensions can add methods per tag.
// Result: see per-variant
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// =============================================================================

struct TaggedAccessor<Tag> {
    let _a: Int
    let _b: Int
    let _count: Int
}

enum CopyTag {}

extension TaggedAccessor where Tag == CopyTag {
    func callAsFunction() -> [Int] {
        var result: [Int] = []
        if _count > 0 { result.append(_a) }
        if _count > 1 { result.append(_b) }
        return result
    }
}

extension Box {
    var taggedCopy: TaggedAccessor<CopyTag> {
        _read {
            yield TaggedAccessor(_a: a, _b: b, _count: count)
        }
    }
}

// =============================================================================
// MARK: - Tests
// =============================================================================

print("=== Non-Mutating Copy Accessor Experiment ===\n")

print("--- V1: Non-mutating func ---")
do {
    let box = Box(10, 20)   // `let` binding
    let result = box.v1Copy()
    print("  Result: \(result)")
    assert(result == [10, 20])
    print("  CONFIRMED — non-mutating func works on `let` ~Copyable\n")
}

print("--- V2: Non-mutating _read + Copyable wrapper + callAsFunction ---")
do {
    let box = Box(10, 20)   // `let` binding
    let all = box.copy()                // callAsFunction() -> [Int]
    let first = box.copy(at: 0)         // callAsFunction(at:) -> Int?
    let second = box.copy(at: 1)
    let oob = box.copy(at: 5)
    print("  copy()     = \(all)")
    print("  copy(at:0) = \(first as Any)")
    print("  copy(at:1) = \(second as Any)")
    print("  copy(at:5) = \(oob as Any)")
    assert(all == [10, 20])
    assert(first == 10)
    assert(second == 20)
    assert(oob == nil)
    print("  CONFIRMED — Copyable wrapper from _read works on `let` ~Copyable")
    print("  Call syntax: box.copy() / box.copy(at: 0) — identical to direct methods\n")
}

print("--- V3: Tagged wrapper for extensible namespace ---")
do {
    let box = Box(10, 20)   // `let` binding
    let result = box.taggedCopy()       // callAsFunction via Tag constraint
    print("  taggedCopy() = \(result)")
    assert(result == [10, 20])
    print("  CONFIRMED — Tag-constrained extensions work, enabling Property-like namespace\n")
}

// =============================================================================
// MARK: - Results Summary
//
// V1: CONFIRMED — non-mutating func works on `let` ~Copyable
// V2: CONFIRMED — _read + Copyable wrapper + callAsFunction works on `let`
// V3: CONFIRMED — Tagged wrapper enables extensible namespace
//
// CONCLUSION:
// A Copyable wrapper yielded from a non-mutating _read accessor provides:
// - `let` binding compatibility (no `var` required)
// - callAsFunction syntax (box.copy(), box.copy(range:to:))
// - Tag-based extensibility (like Property<Tag, Base>)
//
// TRADEOFF: The wrapper must capture values, not pointers. For Storage.Inline's
// copy operations, this means the wrapper would need to capture a pointer to the
// inline storage's element buffer — but that pointer can be obtained via
// withUnsafePointer(to: _storage) which is borrowing (non-mutating).
//
// The key insight: the wrapper is Copyable and ESCAPES the _read scope,
// so it must hold values or raw pointers (not lifetime-dependent references).
// For copy operations that immediately consume the pointer within callAsFunction,
// this is safe if the wrapper doesn't outlive the access.
// =============================================================================
