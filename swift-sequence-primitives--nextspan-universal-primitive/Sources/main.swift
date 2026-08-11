// MARK: - nextSpan as Universal Iterator Primitive
// Purpose: Validate that nextSpan(maximumCount:) -> Span<Element> works as
//          a universal iteration primitive for ALL storage types, including
//          non-contiguous structures.
// Hypothesis: Single-element Span<Element> can be produced from any storage
//             where elements have stable addresses (heap nodes, slab slots,
//             arena slots, heap-allocated buffer), making nextSpan viable as
//             the sole iterator protocol requirement.
//
// Key pattern: Span(_unsafeStart:count:) tracks lifetime through the pointer
//              argument. The pointer MUST be a stored property lvalue access
//              (not a local variable) so the lifetime chains through `self`.
//              Production code (Buffer.Linear, Buffer.Ring) follows this pattern.
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-02-14-a
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 10 variants pass (7 storage types, 3 batch/borrow tests)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-02-26

// ============================================================================
// MARK: - Unified Iterator Protocol
// ============================================================================

/// Minimal reproduction of the proposed unified iterator protocol.
/// The protocol suppresses both ~Copyable and ~Escapable, allowing conformance
/// from any iterator type regardless of ownership semantics.
protocol UnifiedIteratorProtocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Element>
}

/// Derived next() for Copyable elements.
extension UnifiedIteratorProtocol where Self: ~Copyable & ~Escapable, Element: Copyable {
    mutating func next() -> Element? {
        let span = nextSpan(maximumCount: 1)
        return span.isEmpty ? nil : span[0]
    }
}

// ============================================================================
// MARK: - Variant 1: Contiguous Storage (Baseline)
// Hypothesis: nextSpan from contiguous pointer — known to work
// Pattern: base is a stored UnsafePointer, used directly in Span init
// ============================================================================

struct ContiguousIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    var base: UnsafePointer<Int>
    var remaining: Int

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        let take = min(maximumCount, remaining)
        guard take > 0 else {
            return unsafe Span(_unsafeStart: base, count: 0)
        }
        let span = unsafe Span(_unsafeStart: base, count: take)
        unsafe base = base + take
        remaining -= take
        return span
    }
}

func testContiguous() {
    let array = [10, 20, 30, 40, 50]
    array.withUnsafeBufferPointer { buffer in
        var iter = unsafe ContiguousIterator(
            base: buffer.baseAddress!,
            remaining: buffer.count
        )

        var results: [Int] = []
        while let elem = iter.next() {
            results.append(elem)
        }
        assert(results == [10, 20, 30, 40, 50], "Variant 1 FAILED: \(results)")
        print("Variant 1 (Contiguous): CONFIRMED — \(results)")
    }
}

func testContiguousBatch() {
    let array = [10, 20, 30, 40, 50]
    array.withUnsafeBufferPointer { buffer in
        var iter = unsafe ContiguousIterator(
            base: buffer.baseAddress!,
            remaining: buffer.count
        )

        // Each span borrows iter (@_lifetime(&self)), so scope them
        // to avoid overlapping accesses.
        do {
            let span1 = iter.nextSpan(maximumCount: 3)
            assert(span1.count == 3, "Variant 1b batch count FAILED")
            assert(span1[0] == 10 && span1[1] == 20 && span1[2] == 30)
        }
        do {
            let span2 = iter.nextSpan(maximumCount: 10) // request more than remaining
            assert(span2.count == 2, "Variant 1b remaining count FAILED")
            assert(span2[0] == 40 && span2[1] == 50)
        }
        do {
            let span3 = iter.nextSpan(maximumCount: 1)
            assert(span3.isEmpty, "Variant 1b exhaustion FAILED")
        }
        print("Variant 1b (Contiguous batch): CONFIRMED")
    }
}

// ============================================================================
// MARK: - Variant 2: Scattered Heap Elements (Non-Contiguous)
// Hypothesis: Can produce single-element Span from individually heap-allocated
//             elements at different, non-contiguous addresses.
// Pattern: Store current element pointer as a property; update before return.
// ============================================================================

/// Iterator over individually heap-allocated elements.
/// Each element is at a separate heap address — maximally non-contiguous.
struct ScatteredIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    /// Array of pointers to individually allocated elements.
    var ptrs: [UnsafePointer<Int>]
    var index: Int
    /// Stored element pointer — updated before each return.
    /// Span's lifetime chains through this lvalue access to self.
    var elementPtr: UnsafePointer<Int>

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard index < ptrs.count else {
            return unsafe Span(_unsafeStart: elementPtr, count: 0)
        }
        unsafe elementPtr = ptrs[index]
        index += 1
        return unsafe Span(_unsafeStart: elementPtr, count: 1)
    }
}

func testScattered() {
    // Allocate each element separately on the heap
    let values = [1, 2, 3, 4]
    var allocations: [UnsafeMutablePointer<Int>] = []
    for v in values {
        let ptr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        unsafe ptr.initialize(to: v)
        allocations.append(ptr)
    }
    defer { for ptr in allocations { unsafe ptr.deallocate() } }

    let ptrs = unsafe allocations.map { UnsafePointer($0) }
    var iter = unsafe ScatteredIterator(
        ptrs: ptrs,
        index: 0,
        elementPtr: ptrs[0]
    )

    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [1, 2, 3, 4], "Variant 2 FAILED: \(results)")
    print("Variant 2 (Scattered heap): CONFIRMED — \(results)")
}

// ============================================================================
// MARK: - Variant 3: Linked List (Pointer-Following Traversal)
// Hypothesis: Can produce Span from heap-allocated nodes traversed by following
//             next pointers — the classic non-contiguous structure.
// Pattern: Store element pointer as property; compute from node, then return.
// ============================================================================

struct LinkedNode {
    var element: Int
    var next: UnsafeMutablePointer<LinkedNode>?
}

struct LinkedListIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    var current: UnsafeMutablePointer<LinkedNode>?
    /// Stored element pointer — updated from each node before return.
    var elementPtr: UnsafePointer<Int>

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard let node = unsafe current else {
            return unsafe Span(_unsafeStart: elementPtr, count: 0)
        }
        // Node's element is at offset 0 (first stored property).
        // Update stored pointer before passing to Span.
        unsafe elementPtr = UnsafeRawPointer(node).assumingMemoryBound(to: Int.self)
        unsafe current = node.pointee.next
        return unsafe Span(_unsafeStart: elementPtr, count: 1)
    }
}

/// Helper: allocate a linked list, return head and all nodes for cleanup.
func makeLinkedList(_ values: [Int]) -> (head: UnsafeMutablePointer<LinkedNode>, nodes: [UnsafeMutablePointer<LinkedNode>]) {
    var nodes: [UnsafeMutablePointer<LinkedNode>] = []
    for value in values {
        let node = UnsafeMutablePointer<LinkedNode>.allocate(capacity: 1)
        unsafe node.initialize(to: LinkedNode(element: value, next: nil))
        nodes.append(node)
    }
    for i in 0..<(nodes.count - 1) {
        unsafe nodes[i].pointee.next = nodes[i + 1]
    }
    return unsafe (head: nodes[0], nodes: nodes)
}

func testLinkedList() {
    let (head, nodes) = makeLinkedList([1, 2, 3, 4])
    defer { for node in nodes { unsafe node.deallocate() } }

    // elementPtr initialized to first node's address
    let firstElementPtr = unsafe UnsafeRawPointer(head).assumingMemoryBound(to: Int.self)
    var iter = unsafe LinkedListIterator(current: head, elementPtr: firstElementPtr)

    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [1, 2, 3, 4], "Variant 3 FAILED: \(results)")
    print("Variant 3 (Linked list): CONFIRMED — \(results)")
}

func testLinkedListBorrow() {
    let (head, nodes) = makeLinkedList([100, 200])
    defer { for node in nodes { unsafe node.deallocate() } }

    let firstElementPtr = unsafe UnsafeRawPointer(head).assumingMemoryBound(to: Int.self)
    var iter = unsafe LinkedListIterator(current: head, elementPtr: firstElementPtr)

    let span = iter.nextSpan(maximumCount: 1)
    assert(span.count == 1)
    assert(span[0] == 100, "Variant 3b borrow FAILED")
    print("Variant 3b (Linked list borrow): CONFIRMED — span[0] = \(span[0])")
}

// ============================================================================
// MARK: - Variant 4: Sparse Slab Storage (Bitmap-Gated Slots)
// Hypothesis: Can produce Span from occupied slots in sparse storage,
//             where elements are in contiguous memory but not all slots are used.
// Pattern: Store element pointer as property; compute offset, update, return.
// ============================================================================

struct SlabIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    let base: UnsafePointer<Int>
    let bitmap: UInt8     // 8 slots, each bit = occupied
    var position: Int
    let slotCount: Int
    /// Stored element pointer — updated to point to each occupied slot.
    var elementPtr: UnsafePointer<Int>

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        while position < slotCount {
            let slot = position
            position += 1
            if bitmap & (1 << slot) != 0 {
                // Update stored pointer to this slot
                unsafe elementPtr = base + slot
                return unsafe Span(_unsafeStart: elementPtr, count: 1)
            }
        }
        // Exhausted — use stored pointer for empty span
        return unsafe Span(_unsafeStart: elementPtr, count: 0)
    }
}

func testSlab() {
    // 8 slots, bitmap: 0b00101011 = slots 0, 1, 3, 5 occupied
    let storage = UnsafeMutablePointer<Int>.allocate(capacity: 8)
    defer { unsafe storage.deallocate() }

    unsafe storage[0] = 10
    unsafe storage[1] = 20
    unsafe storage[2] = 0   // empty
    unsafe storage[3] = 30
    unsafe storage[4] = 0   // empty
    unsafe storage[5] = 40
    unsafe storage[6] = 0   // empty
    unsafe storage[7] = 0   // empty

    let bitmap: UInt8 = 0b00101011  // bits 0,1,3,5
    let base = unsafe UnsafePointer(storage)

    var iter = unsafe SlabIterator(
        base: base,
        bitmap: bitmap,
        position: 0,
        slotCount: 8,
        elementPtr: base
    )

    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [10, 20, 30, 40], "Variant 4 FAILED: \(results)")
    print("Variant 4 (Slab): CONFIRMED — \(results)")
}

// ============================================================================
// MARK: - Variant 5: Ring Buffer (Two-Region Wrap-Around)
// Hypothesis: Ring buffer iterator produces spans from two contiguous regions.
// Pattern: base is stored property, used directly (same as production code).
// ============================================================================

struct RingIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    var base: UnsafePointer<Int>
    var remaining: Int
    var secondBase: UnsafePointer<Int>?
    var secondCount: Int

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        if remaining > 0 {
            let take = min(maximumCount, remaining)
            let span = unsafe Span(_unsafeStart: base, count: take)
            unsafe base = base + take
            remaining -= take
            return span
        }

        if let second = unsafe secondBase, secondCount > 0 {
            unsafe base = second
            remaining = secondCount
            unsafe secondBase = nil
            secondCount = 0

            let take = min(maximumCount, remaining)
            let span = unsafe Span(_unsafeStart: base, count: take)
            unsafe base = base + take
            remaining -= take
            return span
        }

        return unsafe Span(_unsafeStart: base, count: 0)
    }
}

func testRing() {
    let region1 = UnsafeMutablePointer<Int>.allocate(capacity: 2)
    let region2 = UnsafeMutablePointer<Int>.allocate(capacity: 3)
    defer { unsafe region1.deallocate(); unsafe region2.deallocate() }

    unsafe region1[0] = 10
    unsafe region1[1] = 20
    unsafe region2[0] = 30
    unsafe region2[1] = 40
    unsafe region2[2] = 50

    var iter = unsafe RingIterator(
        base: UnsafePointer(region1),
        remaining: 2,
        secondBase: UnsafePointer(region2),
        secondCount: 3
    )

    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [10, 20, 30, 40, 50], "Variant 5 FAILED: \(results)")
    print("Variant 5 (Ring): CONFIRMED — \(results)")
}

func testRingBatch() {
    let region1 = UnsafeMutablePointer<Int>.allocate(capacity: 2)
    let region2 = UnsafeMutablePointer<Int>.allocate(capacity: 3)
    defer { unsafe region1.deallocate(); unsafe region2.deallocate() }

    unsafe region1[0] = 10
    unsafe region1[1] = 20
    unsafe region2[0] = 30
    unsafe region2[1] = 40
    unsafe region2[2] = 50

    var iter = unsafe RingIterator(
        base: UnsafePointer(region1),
        remaining: 2,
        secondBase: UnsafePointer(region2),
        secondCount: 3
    )

    // Scope each span to avoid overlapping borrows on iter
    do {
        let span1 = iter.nextSpan(maximumCount: 3)
        assert(span1.count == 2, "Variant 5b batch1 count FAILED: \(span1.count)")
    }
    do {
        let span2 = iter.nextSpan(maximumCount: 3)
        assert(span2.count == 3, "Variant 5b batch2 count FAILED: \(span2.count)")
    }
    print("Variant 5b (Ring batch): CONFIRMED")
}

// ============================================================================
// MARK: - Variant 6: Computed Elements (Heap-Allocated Buffer)
// Hypothesis: Sequences that compute elements without persistent storage can
//             use a heap-allocated single-element buffer to back the Span.
// Pattern: Store buffer as UnsafePointer property; write via mutable alias.
// ============================================================================

struct ComputedIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    var current: Int
    let end: Int
    /// Heap-allocated single-element buffer. Mutable pointer for writing.
    let mutableBuffer: UnsafeMutablePointer<Int>
    /// Same address as mutableBuffer, typed as UnsafePointer for Span.
    /// Stored property so Span's lifetime chains through self.
    var bufferPtr: UnsafePointer<Int>

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard current < end else {
            return unsafe Span(_unsafeStart: bufferPtr, count: 0)
        }
        // Compute the element and store in heap buffer
        unsafe mutableBuffer.pointee = current * current  // squares: 0, 1, 4, 9, 16
        current += 1
        // Return span pointing to the heap buffer via stored property
        return unsafe Span(_unsafeStart: bufferPtr, count: 1)
    }
}

func testComputed() {
    let buffer = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    defer { unsafe buffer.deallocate() }
    unsafe buffer.initialize(to: 0)

    var iter = unsafe ComputedIterator(
        current: 0,
        end: 5,
        mutableBuffer: buffer,
        bufferPtr: UnsafePointer(buffer)
    )

    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [0, 1, 4, 9, 16], "Variant 6 FAILED: \(results)")
    print("Variant 6 (Computed): CONFIRMED — \(results)")
}

// ============================================================================
// MARK: - Variant 7: Tree Node (Class-Backed, Heap-Allocated)
// Hypothesis: Class instances have stable heap addresses.
//             Single-element Span can point to the element field.
// Pattern: Extract pointer from class field, store in property, return.
// ============================================================================

final class TreeNode {
    var element: Int
    var children: [TreeNode]

    init(element: Int, children: [TreeNode] = []) {
        self.element = element
        self.children = children
    }
}

/// Pre-order tree iterator using nextSpan.
struct TreePreOrderIterator: ~Copyable, UnifiedIteratorProtocol {
    typealias Element = Int

    var pending: [TreeNode]  // stack
    /// Stored element pointer — updated from each class node's field.
    var elementPtr: UnsafePointer<Int>

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        guard !pending.isEmpty else {
            return unsafe Span(_unsafeStart: elementPtr, count: 0)
        }

        let node = pending.removeLast()
        // Push children in reverse order for pre-order
        for child in node.children.reversed() {
            pending.append(child)
        }

        // Class instance is heap-allocated — &node.element has stable address.
        // Extract pointer (UnsafePointer<Int> is Escapable, can leave closure),
        // store in property so Span lifetime chains through self.
        elementPtr = withUnsafePointer(to: &node.element) { $0 }
        return unsafe Span(_unsafeStart: elementPtr, count: 1)
    }
}

func testTree() {
    //       1
    //      / \
    //     2   3
    //    / \
    //   4   5
    let node4 = TreeNode(element: 4)
    let node5 = TreeNode(element: 5)
    let node2 = TreeNode(element: 2, children: [node4, node5])
    let node3 = TreeNode(element: 3)
    let root = TreeNode(element: 1, children: [node2, node3])

    // Get initial element pointer from root
    let rootPtr: UnsafePointer<Int> = withUnsafePointer(to: &root.element) { $0 }
    var iter = unsafe TreePreOrderIterator(pending: [root], elementPtr: rootPtr)

    var results: [Int] = []
    while let elem = iter.next() {
        results.append(elem)
    }
    assert(results == [1, 2, 4, 5, 3], "Variant 7 FAILED: \(results)")
    print("Variant 7 (Tree pre-order): CONFIRMED — \(results)")
}

// ============================================================================
// MARK: - Run All Tests
// ============================================================================

print("=== nextSpan Universal Primitive Validation ===\n")

testContiguous()
testContiguousBatch()
testScattered()
testLinkedList()
testLinkedListBorrow()
testSlab()
testRing()
testRingBatch()
testComputed()
testTree()

print("\n=== Results Summary ===")
print("V1  Contiguous:         CONFIRMED")
print("V1b Contiguous batch:   CONFIRMED")
print("V2  Scattered heap:     CONFIRMED")
print("V3  Linked list:        CONFIRMED")
print("V3b Linked list borrow: CONFIRMED")
print("V4  Slab:               CONFIRMED")
print("V5  Ring:               CONFIRMED")
print("V5b Ring batch:         CONFIRMED")
print("V6  Computed:           CONFIRMED")
print("V7  Tree pre-order:     CONFIRMED")
