// SUPERSEDED: See noncopyable-access-patterns
// MARK: - Experiment: Optional ~Copyable Unwrap Alternatives
// Purpose: Determine whether force unwrap (!) on Optional<~Copyable> can be
//          replaced with safe expressions per [IMPL-INTENT] and [IMPL-EXPR-001].
//          Buffer-primitives uses 102 force unwraps — all follow the pattern:
//
//              if _heapBuffer != nil {
//                  _heapBuffer!.mutatingOperation()
//              }
//
//          This is mechanism. The intent is "operate on the heap buffer if present."
//          Can we express that intent safely?
//
// Hypotheses:
// [H1] if-var / guard-let on Optional<~Copyable> consumes the value — cannot
//      partially reinitialize self to write it back                      → REFUTED (unusable)
// [H1] CONFIRMED — if-var / guard-let / switch .some(var) on
//      Optional<~Copyable> stored property: "cannot partially reinitialize self"
// [H2] CONFIRMED — ?. works in mutating func (void and value-returning).
//      Also consuming in non-mutating getters (same as !).
// [H3] REFUTED — ?. DOES work for value-returning methods via
//      `if let result = _heapBuffer?.method() { return result }`
//      The Optional wrapping is resolved by the if-let, not the call site.
// [H4] CONFIRMED — _read/_modify projection confines ! to 1 accessor pair.
//      Call sites use `heap.method()` — clean, intent-expressing.
// [H5] CONFIRMED — try! eliminable via non-throwing overloads.
// [H6] CONFIRMED — ALL access to Optional<~Copyable> (!, ?., if let, switch)
//      is consuming. Only _read coroutine yields borrow.
// [H7] CONFIRMED — switch .some(var) consumes, partial reinit rejected.
//
// Toolchain: Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — force unwraps eliminable via optional chaining (mutating)
//         and _read/_modify projection (non-mutating). See FINDINGS section.
// Date: 2026-02-12

// =============================================================================
// MARK: - Infrastructure: Minimal ~Copyable Buffer Simulation
// =============================================================================

/// Simulates the heap buffer in Buffer.Linear / Buffer.Ring / etc.
struct HeapBuffer: ~Copyable {
    var count: Int

    init(count: Int) {
        self.count = count
    }

    mutating func append() {
        count += 1
    }

    mutating func removeFirst() -> Int {
        precondition(count > 0)
        count -= 1
        return count
    }

    mutating func removeLast() -> Int {
        precondition(count > 0)
        count -= 1
        return count
    }

    mutating func removeAll() {
        count = 0
    }

    mutating func swap(at i: Int, with j: Int) {
        // no-op for this experiment, but mutating
    }
}

/// Simulates the inline buffer
struct InlineBuffer: ~Copyable {
    var count: Int
    let capacity: Int

    init(capacity: Int) {
        self.count = 0
        self.capacity = capacity
    }

    var isFull: Bool { count >= capacity }

    mutating func append() {
        count += 1
    }

    mutating func removeFirst() -> Int {
        count -= 1
        return count
    }

    mutating func removeLast() -> Int {
        count -= 1
        return count
    }

    mutating func removeAll() {
        count = 0
    }
}

// =============================================================================
// MARK: - Variant 1: Baseline (force unwrap)
// This is the existing pattern in buffer-primitives.
// Note: _heapBuffer! in non-mutating getters does NOT compile.
//       All real usage is in `mutating func` — which compiles fine.
// Result: (pending)
// =============================================================================

struct SmallBuffer_ForceUnwrap: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: HeapBuffer?

    init(inlineCapacity: Int) {
        _inlineBuffer = InlineBuffer(capacity: inlineCapacity)
        _heapBuffer = nil
    }

    mutating func _spillToHeap() {
        _heapBuffer = HeapBuffer(count: _inlineBuffer.count)
    }

    mutating func append() {
        if _heapBuffer != nil {
            _heapBuffer!.append()
        } else if !_inlineBuffer.isFull {
            _inlineBuffer.append()
        } else {
            _spillToHeap()
            _heapBuffer!.append()
        }
    }

    mutating func removeFirst() -> Int {
        if _heapBuffer != nil {
            return _heapBuffer!.removeFirst()
        } else {
            return _inlineBuffer.removeFirst()
        }
    }

    mutating func removeAll() {
        if _heapBuffer != nil {
            _heapBuffer!.removeAll()
            _heapBuffer = nil
            _inlineBuffer.removeAll()
        } else {
            _inlineBuffer.removeAll()
        }
    }

    // [H6] DISCOVERY: Both ! AND ?. in non-mutating getter fail:
    //   error: 'self' is borrowed and cannot be consumed
    //   ?. on Optional<~Copyable> is also consuming!
    // FIX: mutating get, or _read coroutine
    var totalCount: Int {
        mutating get {
            if _heapBuffer != nil {
                return _heapBuffer!.count
            }
            return _inlineBuffer.count
        }
    }
}

// =============================================================================
// MARK: - Variant 2: Optional Chaining Maximum
// Uses ?. everywhere possible. Falls back to ! only where ?. changes semantics.
// Result: (pending)
// =============================================================================

struct SmallBuffer_OptionalChaining: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: HeapBuffer?

    init(inlineCapacity: Int) {
        _inlineBuffer = InlineBuffer(capacity: inlineCapacity)
        _heapBuffer = nil
    }

    mutating func _spillToHeap() {
        _heapBuffer = HeapBuffer(count: _inlineBuffer.count)
    }

    // SAFE: ?. on void-returning mutating func
    mutating func append() {
        if _heapBuffer != nil {
            _heapBuffer?.append()
        } else if !_inlineBuffer.isFull {
            _inlineBuffer.append()
        } else {
            _spillToHeap()
            _heapBuffer?.append()
        }
    }

    // PROBLEM: _heapBuffer?.removeFirst() returns Int? not Int
    // Must still use ! for value-returning methods
    mutating func removeFirst() -> Int {
        if _heapBuffer != nil {
            return _heapBuffer!.removeFirst()
        } else {
            return _inlineBuffer.removeFirst()
        }
    }

    // SAFE: ?. on void call, nil check still needed for branch logic
    mutating func removeAll() {
        if _heapBuffer != nil {
            _heapBuffer?.removeAll()
            _heapBuffer = nil
            _inlineBuffer.removeAll()
        } else {
            _inlineBuffer.removeAll()
        }
    }

    // ?. also consuming in non-mutating getter! Must use mutating get.
    var totalCount: Int {
        mutating get {
            if _heapBuffer != nil {
                return _heapBuffer!.count
            }
            return _inlineBuffer.count
        }
    }
}

// =============================================================================
// MARK: - Variant 3: if-var consume + write-back
// Result: REFUTED
//   error: cannot partially reinitialize 'self' after it has been consumed;
//          only full reinitialization is allowed
//
// `if var heap = _heapBuffer` consumes _heapBuffer. Writing back via
// `_heapBuffer = consume heap` is partial reinit — the compiler requires
// ALL of self to be reinitialized. This is a fundamental ~Copyable limitation.
// =============================================================================

// REFUTED — does not compile. Kept as documentation.
//
// struct SmallBuffer_IfVar: ~Copyable {
//     var _inlineBuffer: InlineBuffer
//     var _heapBuffer: HeapBuffer?
//
//     mutating func append() {
//         if var heap = _heapBuffer {   // ← consumes _heapBuffer
//             heap.append()
//             _heapBuffer = consume heap // ← error: partial reinit
//         }
//     }
// }

// =============================================================================
// MARK: - Variant 4: switch .some(var) pattern
// Result: REFUTED (same issue as Variant 3)
//   switch _heapBuffer { case .some(var heap): } consumes _heapBuffer.
//   Writing back is partial reinitialization.
// =============================================================================

// REFUTED — does not compile. Kept as documentation.
//
// struct SmallBuffer_Switch: ~Copyable {
//     var _inlineBuffer: InlineBuffer
//     var _heapBuffer: HeapBuffer?
//
//     mutating func withHeapBuffer<R>(_ body: (inout HeapBuffer) -> R) -> R? {
//         switch _heapBuffer {              // ← consumes _heapBuffer
//         case .some(var heap):
//             let result = body(&heap)
//             _heapBuffer = consume heap    // ← error: partial reinit
//             return result
//         case .none:
//             return nil
//         }
//     }
// }

// =============================================================================
// MARK: - Variant 5: _read/_modify projection accessor
// Hypothesis: Confine the ! to a single _read/_modify pair. Call sites use
// `heap.operation()` — reads as intent, no mechanism visible.
// The force unwrap becomes infrastructure per [IMPL-010].
// Result: (pending)
// =============================================================================

struct SmallBuffer_Projection: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: HeapBuffer?

    init(inlineCapacity: Int) {
        _inlineBuffer = InlineBuffer(capacity: inlineCapacity)
        _heapBuffer = nil
    }

    mutating func _spillToHeap() {
        _heapBuffer = HeapBuffer(count: _inlineBuffer.count)
    }

    /// Single point of force unwrap — infrastructure, not call site.
    /// Callers MUST guard with `if _heapBuffer != nil` before accessing.
    var heap: HeapBuffer {
        _read {
            yield _heapBuffer!
        }
        _modify {
            yield &_heapBuffer!
        }
    }

    // Call sites: no ! visible
    mutating func append() {
        if _heapBuffer != nil {
            heap.append()
        } else if !_inlineBuffer.isFull {
            _inlineBuffer.append()
        } else {
            _spillToHeap()
            heap.append()
        }
    }

    mutating func removeFirst() -> Int {
        if _heapBuffer != nil {
            return heap.removeFirst()
        } else {
            return _inlineBuffer.removeFirst()
        }
    }

    mutating func removeAll() {
        if _heapBuffer != nil {
            heap.removeAll()
            _heapBuffer = nil
            _inlineBuffer.removeAll()
        } else {
            _inlineBuffer.removeAll()
        }
    }

    // _read projection can access heap.count non-consumingly
    var totalCount: Int {
        if _heapBuffer != nil {
            return heap.count
        }
        return _inlineBuffer.count
    }
}

// =============================================================================
// MARK: - Variant 6: Optional chaining + if-let on return value
// Hypothesis: For value-returning methods, _heapBuffer?.method() returns
// Optional<Result>. Using `if let result = _heapBuffer?.method()` avoids !
// entirely — the optional propagation IS the nil check.
// Result: (pending)
// =============================================================================

struct SmallBuffer_FullChaining: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: HeapBuffer?

    init(inlineCapacity: Int) {
        _inlineBuffer = InlineBuffer(capacity: inlineCapacity)
        _heapBuffer = nil
    }

    mutating func _spillToHeap() {
        _heapBuffer = HeapBuffer(count: _inlineBuffer.count)
    }

    // Void: ?. directly
    mutating func append() {
        if _heapBuffer != nil {
            _heapBuffer?.append()
        } else if !_inlineBuffer.isFull {
            _inlineBuffer.append()
        } else {
            _spillToHeap()
            _heapBuffer?.append()
        }
    }

    // Value-returning: if-let on ?. result — zero force unwraps
    mutating func removeFirst() -> Int {
        if let result = _heapBuffer?.removeFirst() {
            return result
        }
        return _inlineBuffer.removeFirst()
    }

    mutating func removeLast() -> Int {
        if let result = _heapBuffer?.removeLast() {
            return result
        }
        return _inlineBuffer.removeLast()
    }

    // Void with branch logic: ?. + check
    mutating func removeAll() {
        if _heapBuffer != nil {
            _heapBuffer?.removeAll()
            _heapBuffer = nil
            _inlineBuffer.removeAll()
        } else {
            _inlineBuffer.removeAll()
        }
    }

    // ?. also consuming — must use mutating get for non-projection read
    var totalCount: Int {
        mutating get {
            if let result = _heapBuffer?.count {
                return result
            }
            return _inlineBuffer.count
        }
    }
}

// =============================================================================
// MARK: - Variant 7: Projection + Full Chaining Combined
// Hypothesis: Use _read/_modify projection for complex operations,
// optional chaining for simple reads — best of both worlds.
// Result: (pending)
// =============================================================================

struct SmallBuffer_Combined: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: HeapBuffer?

    init(inlineCapacity: Int) {
        _inlineBuffer = InlineBuffer(capacity: inlineCapacity)
        _heapBuffer = nil
    }

    mutating func _spillToHeap() {
        _heapBuffer = HeapBuffer(count: _inlineBuffer.count)
    }

    /// Projection for mutating access — single ! location.
    var heap: HeapBuffer {
        _read {
            yield _heapBuffer!
        }
        _modify {
            yield &_heapBuffer!
        }
    }

    // Void mutating: ?. (no projection needed)
    mutating func append() {
        if _heapBuffer != nil {
            _heapBuffer?.append()
        } else if !_inlineBuffer.isFull {
            _inlineBuffer.append()
        } else {
            _spillToHeap()
            _heapBuffer?.append()
        }
    }

    // Value-returning: if-let on ?. (no ! at all)
    mutating func removeFirst() -> Int {
        if let result = _heapBuffer?.removeFirst() {
            return result
        }
        return _inlineBuffer.removeFirst()
    }

    // Complex mutating (removeAll with nil-out): projection
    mutating func removeAll() {
        if _heapBuffer != nil {
            heap.removeAll()
            _heapBuffer = nil
            _inlineBuffer.removeAll()
        } else {
            _inlineBuffer.removeAll()
        }
    }

    // Use _read projection for non-consuming access
    var totalCount: Int {
        if _heapBuffer != nil {
            return heap.count
        }
        return _inlineBuffer.count
    }
}

// =============================================================================
// MARK: - Variant 8: try! Elimination — Typed Throws Propagation
// Hypothesis: try! can be replaced by either:
//   (A) Propagating typed throws to the caller
//   (B) Non-throwing variant when capacity is pre-validated
// Result: (pending)
// =============================================================================

enum BufferError: Error, Hashable, Sendable {
    case capacityExceeded
    case empty
}

struct ThrowingHeapBuffer: ~Copyable {
    var count: Int
    let capacity: Int

    init(capacity: Int) {
        self.count = 0
        self.capacity = capacity
    }

    // Throwing: capacity may be exceeded
    mutating func insert(_ element: Int) throws(BufferError) {
        guard count < capacity else { throw .capacityExceeded }
        count += 1
    }

    // Non-throwing: capacity pre-validated by caller
    mutating func insertUnchecked(_ element: Int) {
        count += 1
    }

    // Pattern matching real Linked buffer: reserve + insert as one operation
    mutating func insertReserving(_ element: Int) {
        // internal: capacity is guaranteed by spill logic
        count += 1
    }
}

struct SmallBuffer_TypedThrows: ~Copyable {
    var _heapBuffer: ThrowingHeapBuffer?

    init() {
        _heapBuffer = nil
    }

    // Option A: Propagate typed throw
    mutating func insert_propagating(_ element: Int) throws(BufferError) {
        if _heapBuffer != nil {
            try _heapBuffer!.insert(element)
        }
    }

    // Option B: Non-throwing variant (capacity pre-reserved by spill)
    mutating func insert_prereserved(_ element: Int) {
        _heapBuffer?.insertReserving(element)
    }
}

// =============================================================================
// MARK: - Execution
// =============================================================================

func runVariant1() {
    print("--- Variant 1: Force Unwrap (baseline) ---")
    var buf = SmallBuffer_ForceUnwrap(inlineCapacity: 2)
    buf.append()
    buf.append()
    print("  After 2 appends (inline): count = \(buf.totalCount)")
    buf.append()
    print("  After 3rd append (spill): count = \(buf.totalCount)")
    let removed = buf.removeFirst()
    print("  After removeFirst: count = \(buf.totalCount), removed = \(removed)")
    buf.removeAll()
    print("  After removeAll: count = \(buf.totalCount)")
    print("  Assessment: 4 force unwraps in mutating methods")
    print()
}

func runVariant2() {
    print("--- Variant 2: Optional Chaining (partial) ---")
    var buf = SmallBuffer_OptionalChaining(inlineCapacity: 2)
    buf.append()
    buf.append()
    buf.append()
    print("  After 3 appends: count = \(buf.totalCount)")
    let removed = buf.removeFirst()
    print("  After removeFirst: count = \(buf.totalCount), removed = \(removed)")
    buf.removeAll()
    print("  After removeAll: count = \(buf.totalCount)")
    print("  Assessment: 1 force unwrap remains (value-returning method)")
    print()
}

func runVariant5() {
    print("--- Variant 5: _modify Projection ---")
    var buf = SmallBuffer_Projection(inlineCapacity: 2)
    buf.append()
    buf.append()
    buf.append()
    print("  After 3 appends: count = \(buf.totalCount)")
    let removed = buf.removeFirst()
    print("  After removeFirst: count = \(buf.totalCount), removed = \(removed)")
    buf.removeAll()
    print("  After removeAll: count = \(buf.totalCount)")
    print("  Assessment: 1 force unwrap (in _read/_modify pair), 0 at call sites")
    print()
}

func runVariant6() {
    print("--- Variant 6: Full Optional Chaining ---")
    var buf = SmallBuffer_FullChaining(inlineCapacity: 2)
    buf.append()
    buf.append()
    buf.append()
    print("  After 3 appends: count = \(buf.totalCount)")
    let removed = buf.removeFirst()
    print("  After removeFirst: count = \(buf.totalCount), removed = \(removed)")
    buf.removeAll()
    print("  After removeAll: count = \(buf.totalCount)")
    print("  Assessment: ZERO force unwraps anywhere")
    print()
}

func runVariant7() {
    print("--- Variant 7: Projection + Chaining Combined ---")
    var buf = SmallBuffer_Combined(inlineCapacity: 2)
    buf.append()
    buf.append()
    buf.append()
    print("  After 3 appends: count = \(buf.totalCount)")
    let removed = buf.removeFirst()
    print("  After removeFirst: count = \(buf.totalCount), removed = \(removed)")
    buf.removeAll()
    print("  After removeAll: count = \(buf.totalCount)")
    print("  Assessment: 1 force unwrap (in projection), most call sites use ?.")
    print()
}

func runVariant8() {
    print("--- Variant 8: try! Elimination ---")
    var buf = SmallBuffer_TypedThrows()
    buf._heapBuffer = ThrowingHeapBuffer(capacity: 10)
    do {
        try buf.insert_propagating(42)
        print("  Option A (propagate): count = \(buf._heapBuffer?.count ?? -1)")
    } catch {
        print("  Option A failed: \(error)")
    }
    buf.insert_prereserved(43)
    print("  Option B (pre-reserve): count = \(buf._heapBuffer?.count ?? -1)")
    print("  Assessment: Both approaches eliminate try!")
    print()
}

print(String(repeating: "=", count: 70))
print("EXPERIMENT: Optional ~Copyable Unwrap Alternatives")
print(String(repeating: "=", count: 70))
print()

runVariant1()
runVariant2()
print("--- Variant 3: if-var consume + write-back ---")
print("  REFUTED: 'cannot partially reinitialize self after it has been consumed'")
print("  if var heap = _heapBuffer consumes the optional.")
print("  _heapBuffer = consume heap is partial reinit — compiler rejects.")
print()
print("--- Variant 4: switch .some(var) ---")
print("  REFUTED: Same as Variant 3. switch consumes, write-back is partial reinit.")
print()
runVariant5()
runVariant6()
runVariant7()
runVariant8()

print(String(repeating: "=", count: 70))
print("FINDINGS")
print(String(repeating: "=", count: 70))
print()
print("Compiler Constraints (Swift 6.2.3):")
print("  1. ALL access to Optional<~Copyable> is consuming: !, ?., if let, switch")
print("     In non-mutating context → error: 'self' is borrowed and cannot be consumed")
print("  2. if var / switch .some(var) on stored property → partial reinit rejected")
print("  3. ! and ?. work in mutating func (exclusive mutable access allows consume)")
print("  4. _read { yield _heapBuffer! } is the ONLY non-consuming unwrap path")
print("     Coroutine yields a borrow — does not consume the optional")
print()
print("Safe Expression Inventory:")
print()
print("  | Pattern                                     | ! | mutating? | Non-mut? |")
print("  |---------------------------------------------|---|-----------|----------|")
print("  | _heapBuffer?.voidMethod()                   | 0 |    YES    |    NO    |")
print("  | if let r = _heapBuffer?.valueMethod() { r } | 0 |    YES    |    NO    |")
print("  | heap.method() via _read/_modify projection  | 1*|    YES    |   YES    |")
print("  | if != nil { _heapBuffer!.method() }         | N |    YES    |    NO    |")
print("  |  * = confined to infrastructure accessor                               |")
print()
print("RECOMMENDATION:")
print()
print("  [!] Use Variant 5 (_read/_modify projection) as the primary pattern.")
print()
print("      Rationale:")
print("      - ONLY pattern that works in non-mutating context")
print("      - Confines ! to ONE accessor pair per Small type [IMPL-010]")
print("      - Call sites read as intent: heap.append(), heap.removeFirst()")
print("      - No 'mutating get' infection — properties stay genuinely non-mutating")
print()
print("      Supplement with ?. in mutating methods where it's simpler:")
print("      - Void calls: _heapBuffer?.append() (avoids guard + projection)")
print("      - Value calls: if let r = _heapBuffer?.removeFirst() { return r }")
print()
print("      This reduces 102 force unwraps to ~4 (one _read/_modify pair per")
print("      Small buffer type: Linear, Ring, Linked, Arena).")
print()
print("  [try!] Provide non-throwing overloads where capacity is pre-validated.")
print("         Linked buffer's try! on reserveAdditionalCapacity + insertFront")
print("         should become a single non-throwing insertReserving that handles")
print("         capacity internally. The Small wrapper never sees a throwing API.")
print()
