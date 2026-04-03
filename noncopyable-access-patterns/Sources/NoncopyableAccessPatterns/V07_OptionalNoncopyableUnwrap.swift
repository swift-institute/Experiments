// MARK: - Experiment: Optional ~Copyable Unwrap Alternatives
// Purpose: Determine whether force unwrap (!) on Optional<~Copyable> can be
//          replaced with safe expressions per [IMPL-INTENT] and [IMPL-EXPR-001].
//          Buffer-primitives uses 102 force unwraps -- all follow the pattern:
//
//              if _heapBuffer != nil {
//                  _heapBuffer!.mutatingOperation()
//              }
//
//          This is mechanism. The intent is "operate on the heap buffer if present."
//          Can we express that intent safely?
//
// Hypotheses:
// [H1] CONFIRMED - if-var / guard-let / switch .some(var) on
//      Optional<~Copyable> stored property: "cannot partially reinitialize self"
// [H2] CONFIRMED - ?. works in mutating func (void and value-returning)
// [H3] REFUTED - ?. DOES work for value-returning methods via
//      `if let result = _heapBuffer?.method() { return result }`
// [H4] CONFIRMED - _read/_modify projection confines ! to 1 accessor pair
// [H5] CONFIRMED - try! eliminable via non-throwing overloads
// [H6] CONFIRMED - ALL access to Optional<~Copyable> (!, ?., if let, switch)
//      is consuming. Only _read coroutine yields borrow.
// [H7] CONFIRMED - switch .some(var) consumes, partial reinit rejected.
//
// Toolchain: Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED - force unwraps eliminable via optional chaining (mutating)
//         and _read/_modify projection (non-mutating). See FINDINGS section.
//
// Status: CONFIRMED
// Revalidation: When partial reinit for Optional<~Copyable> is supported
// Origin: swift-primitives/Experiments/optional-noncopyable-unwrap

enum V07_OptionalNoncopyableUnwrap {

    // =========================================================================
    // MARK: - Infrastructure: Minimal ~Copyable Buffer Simulation
    // =========================================================================

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

    // =========================================================================
    // MARK: - Variant 1: Baseline (force unwrap)
    // =========================================================================

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

    // =========================================================================
    // MARK: - Variant 2: Optional Chaining Maximum
    // =========================================================================

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
        mutating func removeFirst() -> Int {
            if _heapBuffer != nil {
                return _heapBuffer!.removeFirst()
            } else {
                return _inlineBuffer.removeFirst()
            }
        }

        mutating func removeAll() {
            if _heapBuffer != nil {
                _heapBuffer?.removeAll()
                _heapBuffer = nil
                _inlineBuffer.removeAll()
            } else {
                _inlineBuffer.removeAll()
            }
        }

        var totalCount: Int {
            mutating get {
                if _heapBuffer != nil {
                    return _heapBuffer!.count
                }
                return _inlineBuffer.count
            }
        }
    }

    // =========================================================================
    // MARK: - Variant 3: if-var consume + write-back
    // =========================================================================
    // Result: REFUTED
    //   error: cannot partially reinitialize 'self' after it has been consumed
    //
    // COMPILE ERROR (expected):
    // struct SmallBuffer_IfVar: ~Copyable {
    //     var _inlineBuffer: InlineBuffer
    //     var _heapBuffer: HeapBuffer?
    //
    //     mutating func append() {
    //         if var heap = _heapBuffer {   // <- consumes _heapBuffer
    //             heap.append()
    //             _heapBuffer = consume heap // <- error: partial reinit
    //         }
    //     }
    // }

    // =========================================================================
    // MARK: - Variant 4: switch .some(var) pattern
    // =========================================================================
    // Result: REFUTED (same issue as Variant 3)
    //
    // COMPILE ERROR (expected):
    // struct SmallBuffer_Switch: ~Copyable {
    //     var _inlineBuffer: InlineBuffer
    //     var _heapBuffer: HeapBuffer?
    //
    //     mutating func withHeapBuffer<R>(_ body: (inout HeapBuffer) -> R) -> R? {
    //         switch _heapBuffer {              // <- consumes _heapBuffer
    //         case .some(var heap):
    //             let result = body(&heap)
    //             _heapBuffer = consume heap    // <- error: partial reinit
    //             return result
    //         case .none:
    //             return nil
    //         }
    //     }
    // }

    // =========================================================================
    // MARK: - Variant 5: _read/_modify projection accessor
    // =========================================================================

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

        /// Single point of force unwrap - infrastructure, not call site.
        var heap: HeapBuffer {
            _read {
                yield _heapBuffer!
            }
            _modify {
                yield &_heapBuffer!
            }
        }

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

        var totalCount: Int {
            if _heapBuffer != nil {
                return heap.count
            }
            return _inlineBuffer.count
        }
    }

    // =========================================================================
    // MARK: - Variant 6: Optional chaining + if-let on return value
    // =========================================================================

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

        mutating func removeAll() {
            if _heapBuffer != nil {
                _heapBuffer?.removeAll()
                _heapBuffer = nil
                _inlineBuffer.removeAll()
            } else {
                _inlineBuffer.removeAll()
            }
        }

        var totalCount: Int {
            mutating get {
                if let result = _heapBuffer?.count {
                    return result
                }
                return _inlineBuffer.count
            }
        }
    }

    // =========================================================================
    // MARK: - Variant 7: Projection + Full Chaining Combined
    // =========================================================================

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

        var heap: HeapBuffer {
            _read {
                yield _heapBuffer!
            }
            _modify {
                yield &_heapBuffer!
            }
        }

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

        mutating func removeFirst() -> Int {
            if let result = _heapBuffer?.removeFirst() {
                return result
            }
            return _inlineBuffer.removeFirst()
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

        var totalCount: Int {
            if _heapBuffer != nil {
                return heap.count
            }
            return _inlineBuffer.count
        }
    }

    // =========================================================================
    // MARK: - Variant 8: try! Elimination - Typed Throws Propagation
    // =========================================================================

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

        mutating func insert(_ element: Int) throws(BufferError) {
            guard count < capacity else { throw .capacityExceeded }
            count += 1
        }

        mutating func insertUnchecked(_ element: Int) {
            count += 1
        }

        mutating func insertReserving(_ element: Int) {
            count += 1
        }
    }

    struct SmallBuffer_TypedThrows: ~Copyable {
        var _heapBuffer: ThrowingHeapBuffer?

        init() {
            _heapBuffer = nil
        }

        mutating func insert_propagating(_ element: Int) throws(BufferError) {
            if _heapBuffer != nil {
                try _heapBuffer!.insert(element)
            }
        }

        mutating func insert_prereserved(_ element: Int) {
            _heapBuffer?.insertReserving(element)
        }
    }

    // =========================================================================
    // MARK: - FINDINGS
    // =========================================================================
    //
    // Compiler Constraints (Swift 6.2.3):
    //   1. ALL access to Optional<~Copyable> is consuming: !, ?., if let, switch
    //      In non-mutating context -> error: 'self' is borrowed and cannot be consumed
    //   2. if var / switch .some(var) on stored property -> partial reinit rejected
    //   3. ! and ?. work in mutating func (exclusive mutable access allows consume)
    //   4. _read { yield _heapBuffer! } is the ONLY non-consuming unwrap path
    //      Coroutine yields a borrow - does not consume the optional
    //
    // Safe Expression Inventory:
    //
    //   | Pattern                                     | ! | mutating? | Non-mut? |
    //   |---------------------------------------------|---|-----------|----------|
    //   | _heapBuffer?.voidMethod()                   | 0 |    YES    |    NO    |
    //   | if let r = _heapBuffer?.valueMethod() { r } | 0 |    YES    |    NO    |
    //   | heap.method() via _read/_modify projection  | 1*|    YES    |   YES    |
    //   | if != nil { _heapBuffer!.method() }         | N |    YES    |    NO    |
    //   |  * = confined to infrastructure accessor                               |
    //
    // RECOMMENDATION:
    //   Use Variant 5 (_read/_modify projection) as the primary pattern.
    //   Supplement with ?. in mutating methods where simpler.
    //   This reduces 102 force unwraps to ~4 (one _read/_modify pair per type).

    // MARK: - Run

    static func run() {
        print()
        print(String(repeating: "=", count: 70))
        print("EXPERIMENT: Optional ~Copyable Unwrap Alternatives")
        print(String(repeating: "=", count: 70))
        print()

        // Variant 1: Force Unwrap (baseline)
        print("--- Variant 1: Force Unwrap (baseline) ---")
        do {
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
        }
        print()

        // Variant 2: Optional Chaining (partial)
        print("--- Variant 2: Optional Chaining (partial) ---")
        do {
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
        }
        print()

        // Variant 3 & 4: Documented as REFUTED
        print("--- Variant 3: if-var consume + write-back ---")
        print("  REFUTED: 'cannot partially reinitialize self after it has been consumed'")
        print()
        print("--- Variant 4: switch .some(var) ---")
        print("  REFUTED: Same as Variant 3. switch consumes, write-back is partial reinit.")
        print()

        // Variant 5: Projection
        print("--- Variant 5: _modify Projection ---")
        do {
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
        }
        print()

        // Variant 6: Full Optional Chaining
        print("--- Variant 6: Full Optional Chaining ---")
        do {
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
        }
        print()

        // Variant 7: Combined
        print("--- Variant 7: Projection + Chaining Combined ---")
        do {
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
        }
        print()

        // Variant 8: Typed Throws
        print("--- Variant 8: try! Elimination ---")
        do {
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
        }
        print()
    }
}
