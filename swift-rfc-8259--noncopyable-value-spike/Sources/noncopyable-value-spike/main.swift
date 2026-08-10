// MARK: - noncopyable-value-spike
//
// Purpose: feasibility validation for ~Copyable RFC_8259.Value cascade
// (Path B of the canada-perf next-arc decision space).
//
// Hypothesis: a parallel `~Copyable Value` enum (Null/Bool/Number/String/Array/Object)
// can be constructed, inspected (via consuming switch / borrowing methods),
// and decomposed without compiler defects under Swift 6.3+. If yes, the
// architectural path through to swift-rfc-8259 cascade is structurally viable.
//
// Structural questions answered by this spike:
//   Q1. Can a 6-case ~Copyable enum with two ~Copyable payload cases (Array, Object)
//       be declared and constructed under Swift 6.3+ with strictMemorySafety?
//   Q2. Can it be inspected via `consuming switch` and `borrowing` accessors
//       (matching what production hot paths need)?
//   Q3. Can the array storage shape — Swift `Array<Val>` — work? CRITICAL: this
//       is the central failure mode discovered by this spike. See §RESULT.
//   Q4. Sanity probe: Memory.Arena (also ~Copyable) compose with ~Copyable Val
//       at the type level (does not exercise arena-allocated slot install).
//
// Status: 2026-05-20 spike (Path B feasibility).
// Toolchain: Swift 6.3+ (whatever's selected at `swift build`).
// Platform: macOS 26 arm64.
// Scope: SANDBOX. Does NOT touch production swift-rfc-8259 source.
//
// RESULT: Q1+Q2 GREEN — ~Copyable enum + borrowing/consuming inspection
//         compiles cleanly. Q3 RED — stdlib `Array<Val>` (and tuples with
//         ~Copyable element) is NOT supported by the current toolchain.
//         The cascade therefore CANNOT use stdlib `Array<Val>` for
//         RFC_8259.Array._storage or `[(key, Val)]` for RFC_8259.Object._storage;
//         must use `Buffer<Val>.Linear` (institute ~Copyable buffer from
//         swift-buffer-primitives) or roll a custom slot allocator. This
//         materially raises the migration cost (production storage swap +
//         dep-graph addition + ownership-aware iteration redesign).

import Memory_Arena_Primitives

// ============================================================================
// MARK: - Minimal ~Copyable Value (no-array variant, sufficient for Q1+Q2)
// ============================================================================
//
// The Q3 failure forces a no-stdlib-Array shape. To preserve the cascade
// surface, we model the recursive payload as a HEAP-BOXED ~Copyable indirect
// pointer (single-element box) so depth>0 trees can be constructed without
// stdlib Array. This is sufficient for Q1+Q2 structural validation; production
// will need Buffer<Val>.Linear for arrays/objects.

/// Minimal `Number` payload — Copyable scalar (analogous to RFC_8259.Number;
/// production carries Parsed + Original lossless representation).
struct Num: ~Copyable {
    var value: Double
    init(_ v: Double) { self.value = v }
}

/// Single-element heap box for recursion. Carries one ~Copyable child.
/// Used as a stand-in for what production Buffer<Val>.Linear would supply.
final class IndirectBox: @unchecked Sendable {
    var child: Val
    init(_ v: consuming Val) { self.child = v }
}

/// The ~Copyable Value enum — the heart of Path B.
///
/// Six cases. The two compound cases (.array, .object) carry an `IndirectBox`
/// stand-in for what production would model as `Buffer<Val>.Linear` (array)
/// and a paired-buffer dictionary-ordered shape (object). The single-box
/// stand-in is sufficient for the spike's structural questions; it does NOT
/// model the multi-element storage cost the v1.1.0 disposition cited.
enum Val: ~Copyable {
    case null
    case bool(Bool)
    case number(Num)
    case string(String)
    case array(IndirectBox)          // stand-in for Buffer<Val>.Linear
    case object(String, IndirectBox) // stand-in: one (key, value) pair
}

// ============================================================================
// MARK: - Q1+Q2: Construction + consuming switch / borrowing accessors
// ============================================================================

extension Val {
    /// Borrowing depth — does NOT consume self, does NOT extract payload by value.
    /// This is the shape production hot paths (encoder, oracle) need.
    borrowing func depth() -> Int {
        switch self {
        case .null:    return 0
        case .bool:    return 0
        case .number:  return 0
        case .string:  return 0
        case .array(let box):
            // box is a class reference — Copyable. The child Val it owns
            // is ~Copyable. We recursively borrow into it.
            return 1 + box.child.depth()
        case .object(_, let box):
            return 1 + box.child.depth()
        }
    }
}

// ============================================================================
// MARK: - Q4: Memory.Arena compose sanity probe
// ============================================================================
//
// Sanity probe: build a `Memory.Arena`, allocate a single slot, drop the arena.
// Does NOT install ~Copyable Val into arena memory — that requires significant
// additional machinery (Storage.Arena or hand-rolled slot allocator). The
// claim here is much narrower: Memory.Arena IS ~Copyable, and consuming an
// arena (which deinit-deallocates) composes structurally with ~Copyable Val
// at the type level.

func arenaComposeSanity() {
    // Memory.Address.Count uses typed-arithmetic primitives. Construct via
    // its default literal-conformant init (Int → Count).
    let capacity: Memory.Address.Count = 4096
    var arena = Memory.Arena(capacity: capacity)

    // Probe a single allocation.
    let slot = arena.allocate(count: 8, alignment: .`8`)
    precondition(slot != nil, "arena allocate failed")

    // Reset is the canonical batch-deallocate.
    arena.reset()

    // Drop scope — Memory.Arena's deinit fires; capacity returns to system.
    _ = consume arena
}

// ============================================================================
// MARK: - Drive
// ============================================================================

func drive() {
    // Build: { "outer": [42.0] }  — exercises both compound cases.
    let leaf  = Val.number(Num(42.0))
    let arr   = Val.array(IndirectBox(consume leaf))
    let outer = Val.object("outer", IndirectBox(consume arr))

    let d = outer.depth()
    print("noncopyable-value-spike — Q1+Q2 GREEN (tree depth: \(d))")

    arenaComposeSanity()
    print("noncopyable-value-spike — Q4 sanity GREEN (Memory.Arena compose)")

    // Final consuming switch (decompose root).
    switch consume outer {
    case .null:   print("decomposed: null")
    case .bool:   print("decomposed: bool")
    case .number: print("decomposed: number")
    case .string: print("decomposed: string")
    case .array:  print("decomposed: array")
    case .object: print("decomposed: object")
    }
}

drive()

print("noncopyable-value-spike — END")
print("noncopyable-value-spike — Q3 RED (stdlib Array<Val> not supported; see file header)")
