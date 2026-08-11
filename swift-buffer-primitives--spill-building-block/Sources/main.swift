// MARK: - Buffer.Spill Building Block Feasibility
// Purpose: Test whether a generic Spill<Inline, Heap> type can factor the
//          Small buffer pattern across Ring and Linear disciplines.
// Hypothesis: H1 — Generic Spill<Inline: ~Copyable, Heap: ~Copyable>: ~Copyable
//                   compiles with Optional._modify through the generic.
//             H2 — Shared query properties (count, capacity, isFull) can be
//                   factored via an internal protocol without losing type safety.
//             H3 — Discipline-specific extensions on Spill can express the
//                   dual-route mutation pattern without a protocol on disciplines.
//             H4 — Typealiases provide equivalent readability to explicit types.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED (mechanically feasible) with CAVEATS (net savings marginal)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// V1: CONFIRMED — Spill<Inline: ~Copyable, Heap: ~Copyable> compiles;
//     Optional._modify on ~Copyable Heap? works via `yield &_heapBuffer!`.
// V2: CONFIRMED — Internal protocol _SmallBufferComponent enables shared
//     count/capacity/isFull/isEmpty across disciplines on Spill.
// V3: CONFIRMED — Constrained extensions (where Inline == RingInline)
//     express the full dual-route mutation + spill pattern.
// V4: CONFIRMED — Top-level typealiases compile. Nested enum typealiases
//     also work (V5). But error messages show the expanded generic type.
// V5: CONFIRMED — Value generics (let N: Int) + nested enum typealiases
//     (MockBuffer.Linear.Small) compile and work.
// V6: CONFIRMED with LIMITATION — Extension `where Heap == HeapN` must
//     explicitly include `Inline: ~Copyable` or implicit Copyable constraint
//     blocks ~Copyable Inline types. Cannot write extensions generic over
//     the value generic parameter (e.g., "for all InlineN<N>") without a
//     protocol — each N must be fixed or use a protocol constraint.
//
// ASSESSMENT: The mechanism works, but the savings are marginal because:
// 1. Spill<Inline, Heap> shares only 3 things: the struct layout (2 fields),
//    isSpilled (1 line), and the heap accessor (4 lines). Total: ~10 lines.
// 2. Every discipline-specific operation (spill logic, mutations, queries)
//    must still be written in constrained extensions — NOT shared.
// 3. Extensions must be written per-discipline AND per-value-generic-parameter,
//    or require an internal protocol (which then becomes the real abstraction).
// 4. Error messages show Spill<RingInline, RingHeap> instead of Ring.Small<4>,
//    reducing role-expressiveness.
//
// Output: Build Succeeded, all 6 variants execute correctly.
// Date: 2026-02-12

// =============================================================================
// MARK: - Simplified Infrastructure (mirrors swift-primitives essentials)
// =============================================================================

/// Phantom-typed index (simplified from Index<Element>).
struct Idx {
    var rawValue: Int
    static var zero: Idx { Idx(rawValue: 0) }

    struct Count: Equatable {
        var rawValue: Int
        static var zero: Count { Count(rawValue: 0) }
    }
}

// =============================================================================
// MARK: - Mock Discipline Types
// =============================================================================

// --- Ring discipline (simplified) ---

struct RingHeader: Copyable, Sendable {
    var count: Idx.Count
    var capacity: Idx.Count
    var head: Int  // ring-specific: write cursor

    init(capacity: Idx.Count) {
        self.count = .zero
        self.capacity = capacity
        self.head = 0
    }
}

/// Simplified Ring.Inline<N> — ~Copyable value-type buffer.
struct RingInline: ~Copyable {
    var header: RingHeader
    let fixedCapacity: Int

    init(capacity: Int) {
        self.fixedCapacity = capacity
        self.header = RingHeader(capacity: Idx.Count(rawValue: capacity))
    }

    var count: Idx.Count { header.count }
    var capacity: Idx.Count { header.capacity }
    var isFull: Bool { header.count == header.capacity }
    var isEmpty: Bool { header.count == .zero }

    mutating func pushBack(_ value: Int) {
        header.count.rawValue += 1
        header.head = (header.head + 1) % fixedCapacity
    }

    mutating func popFront() -> Int {
        header.count.rawValue -= 1
        return 0  // simplified
    }

    mutating func removeAll() {
        header.count = .zero
        header.head = 0
    }
}

/// Simplified Ring (heap) — ~Copyable reference-semantic buffer.
struct RingHeap: ~Copyable {
    var header: RingHeader
    var data: [Int]

    init(capacity: Int) {
        self.header = RingHeader(capacity: Idx.Count(rawValue: capacity))
        self.data = []
    }

    var count: Idx.Count { header.count }
    var capacity: Idx.Count { header.capacity }
    var isFull: Bool { false }  // heap can grow
    var isEmpty: Bool { header.count == .zero }

    mutating func pushBack(_ value: Int) {
        data.append(value)
        header.count.rawValue += 1
    }

    mutating func popFront() -> Int {
        header.count.rawValue -= 1
        return data.removeFirst()
    }

    mutating func removeAll() {
        data.removeAll()
        header.count = .zero
    }
}

// --- Linear discipline (simplified) ---

struct LinearHeader: Copyable, Sendable {
    var count: Idx.Count
    var capacity: Idx.Count

    init(capacity: Idx.Count) {
        self.count = .zero
        self.capacity = capacity
    }
}

/// Simplified Linear.Inline — ~Copyable value-type buffer.
struct LinearInline: ~Copyable {
    var header: LinearHeader
    let fixedCapacity: Int

    init(capacity: Int) {
        self.fixedCapacity = capacity
        self.header = LinearHeader(capacity: Idx.Count(rawValue: capacity))
    }

    var count: Idx.Count { header.count }
    var capacity: Idx.Count { header.capacity }
    var isFull: Bool { header.count == header.capacity }
    var isEmpty: Bool { header.count == .zero }

    mutating func append(_ value: Int) {
        header.count.rawValue += 1
    }

    mutating func removeFirst() -> Int {
        header.count.rawValue -= 1
        return 0  // simplified
    }

    mutating func removeLast() -> Int {
        header.count.rawValue -= 1
        return 0  // simplified
    }

    mutating func removeAll() {
        header.count = .zero
    }
}

/// Simplified Linear (heap) — ~Copyable reference-semantic buffer.
struct LinearHeap: ~Copyable {
    var header: LinearHeader
    var data: [Int]

    init(capacity: Int) {
        self.header = LinearHeader(capacity: Idx.Count(rawValue: capacity))
        self.data = []
    }

    var count: Idx.Count { header.count }
    var capacity: Idx.Count { header.capacity }
    var isFull: Bool { false }
    var isEmpty: Bool { header.count == .zero }

    mutating func append(_ value: Int) {
        data.append(value)
        header.count.rawValue += 1
    }

    mutating func removeFirst() -> Int {
        header.count.rawValue -= 1
        return data.removeFirst()
    }

    mutating func removeLast() -> Int {
        header.count.rawValue -= 1
        return data.removeLast()
    }

    mutating func removeAll() {
        data.removeAll()
        header.count = .zero
    }
}

// =============================================================================
// MARK: - Variant 1: Pure Structural Wrapper (No Protocol)
// Hypothesis: Generic Spill<Inline: ~Copyable, Heap: ~Copyable>: ~Copyable
//             compiles, and Optional._modify works through the generic.
// =============================================================================

struct Spill<Inline: ~Copyable, Heap: ~Copyable>: ~Copyable {
    var _inlineBuffer: Inline
    var _heapBuffer: Heap?

    init(_inlineBuffer: consuming Inline) {
        self._inlineBuffer = consume _inlineBuffer
        self._heapBuffer = nil
    }

    /// Whether the buffer has spilled to heap storage.
    var isSpilled: Bool { _heapBuffer != nil }

    /// Projected access to the heap buffer.
    ///
    /// - Precondition: `isSpilled` — callers MUST guard `_heapBuffer != nil`.
    var heap: Heap {
        _read { yield _heapBuffer! }
        _modify { yield &_heapBuffer! }
    }
}

// V1 Result: CONFIRMED — Build Succeeded. Generic ~Copyable struct with
//     Optional._modify compiles and runs.

// =============================================================================
// MARK: - Variant 2: Internal Protocol for Shared Properties
// Hypothesis: A package-internal protocol _SmallBufferComponent with count,
//             capacity, isFull, isEmpty enables shared query properties on Spill.
// =============================================================================

protocol _SmallBufferComponent: ~Copyable {
    var count: Idx.Count { get }
    var capacity: Idx.Count { get }
    var isFull: Bool { get }
    var isEmpty: Bool { get }
}

// Conform mock types
extension RingInline: _SmallBufferComponent {}
extension RingHeap: _SmallBufferComponent {}
extension LinearInline: _SmallBufferComponent {}
extension LinearHeap: _SmallBufferComponent {}

// Shared query properties via constrained extension
extension Spill where Inline: _SmallBufferComponent & ~Copyable,
                      Heap: _SmallBufferComponent & ~Copyable {

    var count: Idx.Count {
        switch _heapBuffer {
        case .some(let heap): return heap.count
        case .none: return _inlineBuffer.count
        }
    }

    var capacity: Idx.Count {
        switch _heapBuffer {
        case .some(let heap): return heap.capacity
        case .none: return _inlineBuffer.capacity
        }
    }

    var isFull: Bool {
        switch _heapBuffer {
        case .some(_): return false
        case .none: return _inlineBuffer.isFull
        }
    }

    var spilledIsEmpty: Bool {
        switch _heapBuffer {
        case .some(let heap): return heap.isEmpty
        case .none: return _inlineBuffer.isEmpty
        }
    }
}

// V2 Result: CONFIRMED — Protocol constraint on ~Copyable generics works.
//     Shared properties compile via constrained extension.

// =============================================================================
// MARK: - Variant 3: Discipline-Specific Extensions (Dual-Route Pattern)
// Hypothesis: Constrained extensions on Spill<RingInline, RingHeap> can
//             express the full dual-route mutation pattern.
// =============================================================================

// --- Ring discipline on Spill ---

extension Spill where Inline == RingInline, Heap == RingHeap {

    mutating func pushBack(_ value: Int) {
        if _heapBuffer != nil {
            heap.pushBack(value)
        } else if !_inlineBuffer.isFull {
            _inlineBuffer.pushBack(value)
        } else {
            _spillToHeapMoving()
            heap.pushBack(value)
        }
    }

    mutating func popFront() -> Int {
        if _heapBuffer != nil {
            return heap.popFront()
        } else {
            return _inlineBuffer.popFront()
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

    mutating func _spillToHeapMoving() {
        let currentCount = _inlineBuffer.count
        let newCapacity = _inlineBuffer.fixedCapacity * 2

        var newHeap = RingHeap(capacity: newCapacity)
        // Simplified: in production this moves elements in FIFO order
        for _ in 0..<currentCount.rawValue {
            newHeap.pushBack(_inlineBuffer.popFront())
        }

        _inlineBuffer.removeAll()
        _heapBuffer = consume newHeap
    }
}

// --- Linear discipline on Spill ---

extension Spill where Inline == LinearInline, Heap == LinearHeap {

    mutating func append(_ value: Int) {
        if _heapBuffer != nil {
            heap.append(value)
        } else if !_inlineBuffer.isFull {
            _inlineBuffer.append(value)
        } else {
            _spillToHeapMoving()
            heap.append(value)
        }
    }

    mutating func removeFirst() -> Int {
        if _heapBuffer != nil {
            return heap.removeFirst()
        } else {
            return _inlineBuffer.removeFirst()
        }
    }

    mutating func removeLast() -> Int {
        if _heapBuffer != nil {
            return heap.removeLast()
        } else {
            return _inlineBuffer.removeLast()
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

    mutating func _spillToHeapMoving() {
        let currentCount = _inlineBuffer.count
        let newCapacity = _inlineBuffer.fixedCapacity * 2

        var newHeap = LinearHeap(capacity: newCapacity)
        // Simplified: in production this moves elements sequentially
        for _ in 0..<currentCount.rawValue {
            newHeap.append(_inlineBuffer.removeFirst())
        }

        _inlineBuffer.removeAll()
        _heapBuffer = consume newHeap
    }
}

// V3 Result: CONFIRMED — Full dual-route pattern works in constrained extensions.
//     Both Ring and Linear spill logic compiles and runs correctly.

// =============================================================================
// MARK: - Variant 4: Typealias Readability
// Hypothesis: Typealiases provide equivalent role-expressiveness.
// =============================================================================

typealias RingSmall = Spill<RingInline, RingHeap>
typealias LinearSmall = Spill<LinearInline, LinearHeap>

// V4 Result: CONFIRMED — Typealiases compile. But compiler diagnostics expose
//     the expanded form Spill<RingInline, RingHeap>, not the alias.

// =============================================================================
// MARK: - Variant 5: Value Generic + Nested Typealias
// Hypothesis: Spill works with value generics (let N: Int) matching production
//             pattern, and nested typealiases in enum context compile.
// =============================================================================

struct InlineN<let N: Int>: ~Copyable, _SmallBufferComponent {
    var _count: Int = 0

    var count: Idx.Count { Idx.Count(rawValue: _count) }
    var capacity: Idx.Count { Idx.Count(rawValue: N) }
    var isFull: Bool { _count == N }
    var isEmpty: Bool { _count == 0 }

    mutating func append(_ value: Int) { _count += 1 }
    mutating func removeFirst() -> Int { _count -= 1; return 0 }
    mutating func removeAll() { _count = 0 }
}

struct HeapN: ~Copyable, _SmallBufferComponent {
    var _count: Int = 0
    var _capacity: Int

    init(capacity: Int) {
        self._capacity = capacity
        self._count = 0
    }

    var count: Idx.Count { Idx.Count(rawValue: _count) }
    var capacity: Idx.Count { Idx.Count(rawValue: _capacity) }
    var isFull: Bool { false }
    var isEmpty: Bool { _count == 0 }

    mutating func append(_ value: Int) { _count += 1 }
    mutating func removeFirst() -> Int { _count -= 1; return 0 }
    mutating func removeAll() { _count = 0 }
}

// Constrained extension using value generic
extension Spill where Inline == InlineN<4>, Heap == HeapN {
    mutating func append(_ value: Int) {
        if _heapBuffer != nil {
            heap.append(value)
        } else if !_inlineBuffer.isFull {
            _inlineBuffer.append(value)
        } else {
            var newHeap = HeapN(capacity: 8)
            for _ in 0..<_inlineBuffer._count {
                newHeap.append(_inlineBuffer.removeFirst())
            }
            _inlineBuffer.removeAll()
            _heapBuffer = consume newHeap
            heap.append(value)
        }
    }
}

// Nested typealias test: can an enum namespace contain a typealias to Spill?
enum MockBuffer {
    enum Linear {
        typealias Small = Spill<InlineN<4>, HeapN>
    }
}

// V5 Result: CONFIRMED — Value generics (let N: Int) and nested enum typealiases
//     both compile. Output: count=5, isSpilled=true after spill.

// =============================================================================
// MARK: - Variant 6: Constrained Extension with Value Generic Parameter
// Hypothesis: Extension `where Inline == InlineN<N>` for arbitrary N is
//             expressible (generic over the value generic parameter).
// =============================================================================

// Test: can we write an extension that is generic over the value parameter?
// In production this would be: extension Spill where Inline == Ring.Inline<N>
// for ALL values of N.

// Attempt: constrain on InlineN without fixing N
// NOTE: Must include `Inline: ~Copyable` or the extension implicitly adds
// `where Inline: Copyable`, making it inaccessible for ~Copyable Inline types.
extension Spill where Inline: ~Copyable, Heap == HeapN {
    // If Inline happens to conform to _SmallBufferComponent, we get shared
    // properties from V2. But can we add discipline logic for ALL InlineN<N>?
    // This requires matching `Inline == InlineN<some N>` — not expressible
    // without a protocol. Testing what IS possible:

    var v6SharedCapacity: Idx.Count {
        // This works if both conform to _SmallBufferComponent (from V2)
        switch _heapBuffer {
        case .some(let heap): return heap.capacity
        case .none: return Idx.Count(rawValue: -1)  // cannot access N here
        }
    }
}

// V6 Result: CONFIRMED with LIMITATION — Extension compiles with explicit
//     `Inline: ~Copyable`. But cannot match "InlineN<any N>" without a protocol;
//     must fix N or use protocol constraint. Implicit Copyable trap documented.

// =============================================================================
// MARK: - Execution
// =============================================================================

func testRingSmall() {
    print("=== Ring.Small via Spill ===")
    var ring = RingSmall(_inlineBuffer: RingInline(capacity: 4))
    print("Initial: count=\(ring.count.rawValue), isSpilled=\(ring.isSpilled)")

    // Fill inline
    ring.pushBack(1)
    ring.pushBack(2)
    ring.pushBack(3)
    ring.pushBack(4)
    print("After 4 pushBack: count=\(ring.count.rawValue), isSpilled=\(ring.isSpilled)")

    // This triggers spill
    ring.pushBack(5)
    print("After 5th pushBack (spill): count=\(ring.count.rawValue), isSpilled=\(ring.isSpilled)")
    print("  capacity=\(ring.capacity.rawValue), isFull=\(ring.isFull)")

    // Pop from heap
    let v = ring.popFront()
    print("popFront: \(v), count=\(ring.count.rawValue)")

    // RemoveAll resets to inline
    ring.removeAll()
    print("After removeAll: count=\(ring.count.rawValue), isSpilled=\(ring.isSpilled)")
}

func testLinearSmall() {
    print("\n=== Linear.Small via Spill ===")
    var linear = LinearSmall(_inlineBuffer: LinearInline(capacity: 3))
    print("Initial: count=\(linear.count.rawValue), isSpilled=\(linear.isSpilled)")

    // Fill inline
    linear.append(10)
    linear.append(20)
    linear.append(30)
    print("After 3 appends: count=\(linear.count.rawValue), isSpilled=\(linear.isSpilled)")

    // This triggers spill
    linear.append(40)
    print("After 4th append (spill): count=\(linear.count.rawValue), isSpilled=\(linear.isSpilled)")
    print("  capacity=\(linear.capacity.rawValue)")

    // Remove from heap
    let v = linear.removeFirst()
    print("removeFirst: \(v), count=\(linear.count.rawValue)")

    // RemoveAll resets to inline
    linear.removeAll()
    print("After removeAll: count=\(linear.count.rawValue), isSpilled=\(linear.isSpilled)")
}

func testSharedProperties() {
    print("\n=== Shared Properties via Protocol ===")
    var ring = RingSmall(_inlineBuffer: RingInline(capacity: 4))
    print("Ring spilledIsEmpty: \(ring.spilledIsEmpty)")  // true
    ring.pushBack(1)
    print("Ring count: \(ring.count.rawValue), isFull: \(ring.isFull)")
    print("Ring spilledIsEmpty: \(ring.spilledIsEmpty)")  // false

    var linear = LinearSmall(_inlineBuffer: LinearInline(capacity: 3))
    print("Linear spilledIsEmpty: \(linear.spilledIsEmpty)")  // true
    linear.append(1)
    print("Linear count: \(linear.count.rawValue), isFull: \(linear.isFull)")
}

func testReadability() {
    print("\n=== Readability Comparison ===")
    // With typealias:
    let _: RingSmall     // reads as "RingSmall"
    let _: LinearSmall   // reads as "LinearSmall"

    // Without typealias (what users see in diagnostics):
    let _: Spill<RingInline, RingHeap>       // verbose
    let _: Spill<LinearInline, LinearHeap>   // verbose

    // In production it would be:
    // typealias Ring.Small<N> = Buffer.Spill<Ring.Inline<N>, Ring>
    // But: nested typealiases in generic context may not work.
    // Testing that separately below.
    print("Typealias declarations compile: CONFIRMED")
}

func testValueGeneric() {
    print("\n=== Value Generic + Nested Typealias ===")

    // Using the nested typealias
    var buf = MockBuffer.Linear.Small(_inlineBuffer: InlineN<4>())
    print("Initial: count=\(buf.count.rawValue), isSpilled=\(buf.isSpilled)")

    buf.append(1)
    buf.append(2)
    buf.append(3)
    buf.append(4)
    print("After 4 appends: count=\(buf.count.rawValue), isSpilled=\(buf.isSpilled)")

    // Triggers spill
    buf.append(5)
    print("After 5th append (spill): count=\(buf.count.rawValue), isSpilled=\(buf.isSpilled)")

    // Shared properties from V2 protocol extension still work
    print("  capacity=\(buf.capacity.rawValue), isFull=\(buf.isFull)")

    print("Nested typealias MockBuffer.Linear.Small compiles: CONFIRMED")
}

func testExtensionLimitation() {
    print("\n=== Value Generic Extension Limitation ===")
    // V6 tests whether we can write extensions generic over value parameters.
    // The extension `where Heap == HeapN` compiles but cannot access InlineN's
    // value generic N without fixing it or using a protocol.
    let buf = Spill<InlineN<4>, HeapN>(_inlineBuffer: InlineN<4>())
    print("v6SharedCapacity (inline, no N access): \(buf.v6SharedCapacity.rawValue)")
    // -1 because the extension cannot determine InlineN's capacity without a protocol
    print("Extension without fixed value generic: CONFIRMED (but limited)")
}

testRingSmall()
testLinearSmall()
testSharedProperties()
testReadability()
testValueGeneric()
testExtensionLimitation()

print("\nAll variants executed successfully.")
