// MARK: - Ring Buffer Architecture Validation
// Purpose: Validate the converged three-layer buffer architecture
//          (Header, Static Ops, Composed Type) by implementing
//          Ring.Header + static operations + Ring.Growable on
//          actual storage-primitives.
//
// Hypothesis: The three-layer architecture compiles and correctly
//             implements ring buffer push/pop sequences using
//             Storage.Heap, Index<Storage>, Cyclic_Primitives,
//             and Storage.Initialization tracking.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Status: SUPERSEDED 2026-04-30 — Storage namespace migrated to Storage<Element>; Header struct relied on non-generic Storage as phantom Index tag and would require generic refactor of Header
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED - All 6 variants pass. Three-layer architecture
//         (Header / Static Ops / Composed Type) compiles and works correctly
//         with Storage.Heap, Cyclic_Index_Primitives (Modular.*), and
//         Storage.Initialization tracking (.empty, .one, .two).
//
// Key Finding: Storage.Heap.create(minimumCapacity:) may allocate MORE
//              than requested (ManagedBuffer behavior). Ring capacity MUST
//              use storage.slotCapacity (actual), not the requested minimum.
//              The design already handles this correctly since Header is
//              initialized from storage.slotCapacity.
//
// Key Finding: Composed type deinit does not need explicit cleanup when
//              storage.initialization is kept in sync — Storage.Heap's own
//              deinit uses its .initialization to handle cleanup automatically.
//
// Output: See Outputs/run.txt
// Date: 2026-02-03

import Storage_Primitives
import Cyclic_Index_Primitives
import Memory_Primitives
import Sequence_Primitives

// ============================================================
// MARK: - Layer 1: Ring Buffer Header (Pure State)
// ============================================================

/// Namespace for ring buffer discipline.
/// In the real package this would be `Buffer.Ring`.
enum Ring {
    // Intentionally empty — namespace only
}

extension Ring {
    /// Pure cursor state for a dynamic-capacity ring buffer.
    /// Copyable and Sendable — this is just a few integers.
    struct Header: Copyable, Sendable, Hashable {
        /// Slot index of the first element.
        var head: Index<Storage>

        /// Number of initialized elements.
        var count: Index<Storage>.Count

        /// Total slot capacity.
        let capacity: Index<Storage>.Count

        init(capacity: Index<Storage>.Count) {
            self.head = .zero
            self.count = Index<Storage>.Count(Cardinal.zero)
            self.capacity = capacity
        }

        /// Whether the buffer has no elements.
        var isEmpty: Bool { count == Index<Storage>.Count(Cardinal.zero) }

        /// Whether the buffer is at capacity.
        var isFull: Bool { count == capacity }

        /// Compute the Storage.Initialization state from ring header.
        var initialization: Storage.Initialization {
            let countCardinal = count.rawValue
            if countCardinal == .zero {
                return .empty
            }

            let headOrdinal = head.position
            let capCardinal = capacity.rawValue

            // Compute tail position: where next element would go
            // If head + count <= capacity, we don't wrap
            let headPlusCount = Cardinal(headOrdinal.rawValue &+ countCardinal.rawValue)
            if headPlusCount.rawValue <= capCardinal.rawValue {
                // Non-wrapping: one contiguous range
                let end = try! Index<Storage>(Ordinal(headPlusCount.rawValue))
                return .one(head ..< end)
            } else {
                // Wrapping: two ranges
                let capIndex = try! Index<Storage>(Ordinal(capCardinal.rawValue))
                let overflowAmount = headPlusCount.rawValue &- capCardinal.rawValue
                let overflowEnd = try! Index<Storage>(Ordinal(overflowAmount))
                return .two(
                    first: head ..< capIndex,
                    second: Index<Storage>.zero ..< overflowEnd
                )
            }
        }
    }
}

// ============================================================
// MARK: - Layer 2: Static Operations (Expert-Only)
// ============================================================

extension Ring {
    // --- Push Back ---

    /// Writes element at the tail position (head + count) mod capacity.
    /// Precondition: header.count < header.capacity (not full).
    static func pushBack<Element: ~Copyable>(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage.Heap<Element>
    ) {
        // Use Modular.advanced to compute tail = (head + count) mod capacity
        let countOffset = Index<Storage>.Offset(
            fromZero: try! Index<Storage>(Ordinal(header.count.rawValue.rawValue))
        )
        let tail = Modular.advanced(header.head, by: countOffset, capacity: header.capacity)

        storage.initialize(to: consume element, at: tail)

        // Update header
        let newCount = Cardinal(header.count.rawValue.rawValue &+ 1)
        header.count = Index<Storage>.Count(newCount)

        // Update storage initialization tracking
        storage.initialization = header.initialization
    }

    // --- Pop Front ---

    /// Removes and returns the element at head.
    /// Precondition: header.count > 0 (not empty).
    static func popFront<Element: ~Copyable>(
        header: inout Header,
        storage: Storage.Heap<Element>
    ) -> Element {
        let element = storage.move(at: header.head)

        // Advance head using Modular.successor
        header.head = Modular.successor(of: header.head, capacity: header.capacity)

        // Decrement count
        let newCount = Cardinal(header.count.rawValue.rawValue &- 1)
        header.count = Index<Storage>.Count(newCount)

        // Update storage initialization tracking
        storage.initialization = header.initialization

        return element
    }

    // --- Push Front ---

    /// Writes element at (head - 1) mod capacity.
    /// Precondition: header.count < header.capacity (not full).
    static func pushFront<Element: ~Copyable>(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage.Heap<Element>
    ) {
        // Move head backward using Modular.predecessor
        header.head = Modular.predecessor(of: header.head, capacity: header.capacity)

        storage.initialize(to: consume element, at: header.head)

        // Increment count
        let newCount = Cardinal(header.count.rawValue.rawValue &+ 1)
        header.count = Index<Storage>.Count(newCount)

        // Update storage initialization tracking
        storage.initialization = header.initialization
    }

    // --- Pop Back ---

    /// Removes and returns the element at (head + count - 1) mod capacity.
    /// Precondition: header.count > 0 (not empty).
    static func popBack<Element: ~Copyable>(
        header: inout Header,
        storage: Storage.Heap<Element>
    ) -> Element {
        // Compute tail-1 position
        let newCount = Cardinal(header.count.rawValue.rawValue &- 1)
        let lastOffset = Index<Storage>.Offset(
            fromZero: try! Index<Storage>(Ordinal(newCount.rawValue))
        )
        let lastSlot = Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)

        let element = storage.move(at: lastSlot)

        header.count = Index<Storage>.Count(newCount)

        // Update storage initialization tracking
        storage.initialization = header.initialization

        return element
    }

    // --- Logical to Physical ---

    /// Maps logical index (0 = front of buffer) to physical storage slot.
    static func physicalSlot(
        forLogicalIndex logicalIndex: Index<Storage>,
        header: Header
    ) -> Index<Storage> {
        Modular.physical(
            forLogical: logicalIndex,
            head: header.head,
            capacity: header.capacity
        )
    }

    // --- Deinitialize All ---

    /// Deinitializes all elements tracked by the header.
    static func deinitializeAll<Element: ~Copyable>(
        header: inout Header,
        storage: Storage.Heap<Element>
    ) {
        switch header.initialization {
        case .empty:
            break
        case .one(let range):
            storage.deinitialize(range: range)
        case .two(let first, let second):
            storage.deinitialize(range: first)
            storage.deinitialize(range: second)
        }
        header.count = Index<Storage>.Count(Cardinal.zero)
        header.head = .zero
        storage.initialization = .empty
    }
}

// ============================================================
// MARK: - Layer 3: Composed Type (Ring.Growable)
// ============================================================

extension Ring {
    /// A growable ring buffer backed by heap storage.
    struct Growable<Element: ~Copyable>: ~Copyable {
        var header: Header
        var storage: Storage.Heap<Element>

        init(minimumCapacity: Index<Storage>.Count) {
            self.storage = Storage.Heap<Element>.create(minimumCapacity: minimumCapacity)
            self.header = Header(capacity: storage.slotCapacity)
        }

        var count: Index<Storage>.Count { header.count }
        var isEmpty: Bool { header.isEmpty }
        var capacity: Index<Storage>.Count { header.capacity }
        var isFull: Bool { header.isFull }

        /// Push element to back of ring.
        mutating func pushBack(_ element: consuming Element) {
            // Growth would go here in full implementation
            Ring.pushBack(consume element, header: &header, storage: storage)
        }

        /// Pop element from front of ring.
        mutating func popFront() -> Element {
            Ring.popFront(header: &header, storage: storage)
        }

        /// Push element to front of ring.
        mutating func pushFront(_ element: consuming Element) {
            Ring.pushFront(consume element, header: &header, storage: storage)
        }

        /// Pop element from back of ring.
        mutating func popBack() -> Element {
            Ring.popBack(header: &header, storage: storage)
        }

        deinit {
            // In deinit, self is immutable. Use the header's initialization
            // to know what to deinitialize, then let storage's own deinit handle
            // deallocation (storage.initialization was kept in sync).
            // Storage.Heap's deinit uses its own .initialization to deinitialize.
            // We already keep storage.initialization in sync with header state,
            // so storage's ARC deinit handles cleanup automatically.
        }
    }
}

// Make Growable conditionally Copyable/Sendable
extension Ring.Growable: @unchecked Sendable where Element: Sendable {}

// ============================================================
// MARK: - Variant 1: Basic push/pop cycle
// ============================================================
// Hypothesis: pushBack + popFront produces FIFO ordering
// Result: PENDING

do {
    let cap = try! Index<Storage>.Count(Cardinal(UInt(4)))
    var ring = Ring.Growable<Int>(minimumCapacity: cap)

    ring.pushBack(10)
    ring.pushBack(20)
    ring.pushBack(30)

    let a = ring.popFront()
    let b = ring.popFront()
    let c = ring.popFront()

    print("Variant 1 - FIFO ordering:")
    print("  Input:  [10, 20, 30]")
    print("  Output: [\(a), \(b), \(c)]")
    print("  FIFO:   \(a == 10 && b == 20 && c == 30 ? "CONFIRMED" : "REFUTED")")
    print("  Empty:  \(ring.isEmpty ? "CONFIRMED" : "REFUTED")")
}

// ============================================================
// MARK: - Variant 2: Wrap-around behavior
// ============================================================
// Hypothesis: Ring correctly wraps around capacity boundary
// Result: PENDING

do {
    let cap = try! Index<Storage>.Count(Cardinal(UInt(4)))
    var ring = Ring.Growable<Int>(minimumCapacity: cap)
    let actualCap = Int(bitPattern: ring.capacity)
    print("\nVariant 2 - Wrap-around:")
    print("  Requested capacity: 4, Actual capacity: \(actualCap)")

    // Fill to ACTUAL capacity to force wrapping
    for i in 0..<actualCap {
        ring.pushBack(i + 1)
    }

    // Pop two from front (advances head by 2)
    let _ = ring.popFront()
    let _ = ring.popFront()

    // Push two more (these MUST wrap around since we were at actual capacity)
    ring.pushBack(actualCap + 1)
    ring.pushBack(actualCap + 2)

    // Pop all — should be [3, 4, ..., actualCap, actualCap+1, actualCap+2] in FIFO order
    var results: [Int] = []
    for _ in 0..<actualCap {
        results.append(ring.popFront())
    }

    var expected: [Int] = []
    for i in 2..<actualCap {
        expected.append(i + 1)
    }
    expected.append(actualCap + 1)
    expected.append(actualCap + 2)

    print("  Expected: \(expected)")
    print("  Actual:   \(results)")
    print("  Wrap:     \(results == expected ? "CONFIRMED" : "REFUTED")")
    print("  Empty:    \(ring.isEmpty ? "CONFIRMED" : "REFUTED")")
}

// ============================================================
// MARK: - Variant 3: Storage.Initialization tracking
// ============================================================
// Hypothesis: Storage.Initialization correctly reflects .one/.two
//             states during wrap-around
// Result: PENDING

do {
    let cap = try! Index<Storage>.Count(Cardinal(UInt(4)))
    var ring = Ring.Growable<Int>(minimumCapacity: cap)
    let actualCap = Int(bitPattern: ring.capacity)

    // Empty state
    let init0 = ring.header.initialization
    print("\nVariant 3 - Storage.Initialization tracking:")
    print("  Actual capacity: \(actualCap)")
    print("  Empty:       \(init0) == .empty: \(init0 == .empty ? "CONFIRMED" : "REFUTED")")

    // Push 2 → should be .one(0..<2)
    ring.pushBack(10)
    ring.pushBack(20)
    let init1 = ring.header.initialization
    let expected1 = Storage.Initialization.one(
        Index<Storage>.zero ..< (try! Index<Storage>(Ordinal(UInt(2))))
    )
    print("  After push 2: \(init1) == .one(0..<2): \(init1 == expected1 ? "CONFIRMED" : "REFUTED")")

    // To trigger .two wrapping, we must fill to actual capacity, pop some, then push past boundary
    // First, fill to capacity
    for i in 2..<actualCap {
        ring.pushBack(i * 10)
    }
    // Pop all from front (advances head to actualCap, wraps to 0... actually head cycles)
    for _ in 0..<actualCap {
        let _ = ring.popFront()
    }
    // Now head is at actualCap % actualCap = 0... no wait. Let me think.
    // After filling actualCap and popping all actualCap, head = actualCap mod actualCap = 0.
    // That doesn't help. Need to pop SOME, not all.

    // Reset by making a new ring
    var ring2 = Ring.Growable<Int>(minimumCapacity: cap)
    let cap2 = Int(bitPattern: ring2.capacity)
    // Fill completely
    for i in 0..<cap2 {
        ring2.pushBack(i)
    }
    // Pop 2 from front → head advances to 2
    let _ = ring2.popFront()
    let _ = ring2.popFront()
    // Now count = cap2 - 2, head = 2. Push 2 more → fills to actual capacity again, wrapping.
    ring2.pushBack(100)
    ring2.pushBack(200)
    // Now: head=2, count=cap2, elements occupy [2..cap2) + [0..2) → must be .two
    let init2 = ring2.header.initialization
    print("  Wrapping (head=2, count=\(cap2)): \(init2)")
    let isTwo: Bool
    if case .two = init2 { isTwo = true } else { isTwo = false }
    print("  Is .two:     \(isTwo ? "CONFIRMED" : "REFUTED")")

    // Pop all to empty
    for _ in 0..<cap2 {
        let _ = ring2.popFront()
    }
    let init3 = ring2.header.initialization
    print("  Back empty:  \(init3) == .empty: \(init3 == .empty ? "CONFIRMED" : "REFUTED")")
}

// ============================================================
// MARK: - Variant 4: Push front / pop back (deque behavior)
// ============================================================
// Hypothesis: pushFront + popBack correctly implements
//             reverse-direction ring operations
// Result: PENDING

do {
    let cap = try! Index<Storage>.Count(Cardinal(UInt(4)))
    var ring = Ring.Growable<Int>(minimumCapacity: cap)

    ring.pushFront(10)
    ring.pushFront(20)
    ring.pushFront(30)

    // pushFront order: 30 is at front, 10 is at back
    let a = ring.popBack()  // should be 10
    let b = ring.popBack()  // should be 20
    let c = ring.popBack()  // should be 30

    print("\nVariant 4 - pushFront/popBack:")
    print("  pushFront [10, 20, 30], popBack order:")
    print("  Expected: [10, 20, 30]")
    print("  Actual:   [\(a), \(b), \(c)]")
    print("  Correct:  \(a == 10 && b == 20 && c == 30 ? "CONFIRMED" : "REFUTED")")
}

// ============================================================
// MARK: - Variant 5: Modular.physical for logical indexing
// ============================================================
// Hypothesis: Modular.physical correctly maps logical indices
//             to physical storage slots across wrap boundary
// Result: PENDING

do {
    let cap = try! Index<Storage>.Count(Cardinal(UInt(4)))
    var ring = Ring.Growable<Int>(minimumCapacity: cap)
    let actualCap = Int(bitPattern: ring.capacity)

    // To test wrapping logical-to-physical mapping, fill to actual capacity, pop some, push more
    for i in 0..<actualCap {
        ring.pushBack(i)
    }
    // Pop 2 from front → head at slot 2
    let _ = ring.popFront()
    let _ = ring.popFront()
    // Push 2 more → wraps around
    ring.pushBack(100)
    ring.pushBack(200)

    // Now: head=2, count=actualCap (full, wrapping)
    // logical 0 → physical 2
    // logical (actualCap-3) → physical (actualCap-1)
    // logical (actualCap-2) → physical 0  (wrapped)
    // logical (actualCap-1) → physical 1  (wrapped)

    let slot0 = Ring.physicalSlot(
        forLogicalIndex: .zero,
        header: ring.header
    )
    let slotLast2 = Ring.physicalSlot(
        forLogicalIndex: try! Index<Storage>(Ordinal(UInt(actualCap - 2))),
        header: ring.header
    )
    let slotLast1 = Ring.physicalSlot(
        forLogicalIndex: try! Index<Storage>(Ordinal(UInt(actualCap - 1))),
        header: ring.header
    )

    print("\nVariant 5 - Logical-to-physical index mapping:")
    print("  head=2, count=\(actualCap), capacity=\(actualCap)")
    print("  logical 0 → physical \(slot0.position) (expected 2): \(slot0.position == Ordinal(UInt(2)) ? "CONFIRMED" : "REFUTED")")
    print("  logical \(actualCap-2) → physical \(slotLast2.position) (expected 0): \(slotLast2.position == Ordinal(UInt(0)) ? "CONFIRMED" : "REFUTED")")
    print("  logical \(actualCap-1) → physical \(slotLast1.position) (expected 1): \(slotLast1.position == Ordinal(UInt(1)) ? "CONFIRMED" : "REFUTED")")

    // Clean up
    for _ in 0..<actualCap {
        let _ = ring.popFront()
    }
}

// ============================================================
// MARK: - Variant 6: Header is Copyable and Sendable
// ============================================================
// Hypothesis: Ring.Header is Copyable and Sendable,
//             enabling snapshot and cross-isolation transfer
// Result: PENDING

do {
    let cap = try! Index<Storage>.Count(Cardinal(UInt(4)))
    var ring = Ring.Growable<Int>(minimumCapacity: cap)
    ring.pushBack(42)

    // Copy header (snapshot)
    let snapshot = ring.header
    ring.pushBack(99)

    print("\nVariant 6 - Header copyability:")
    print("  Snapshot count: \(snapshot.count.rawValue) (expected 1): \(snapshot.count.rawValue.rawValue == 1 ? "CONFIRMED" : "REFUTED")")
    print("  Current count:  \(ring.header.count.rawValue) (expected 2): \(ring.header.count.rawValue.rawValue == 2 ? "CONFIRMED" : "REFUTED")")

    // Sendable verification — would not compile if not Sendable
    let _: any Sendable = ring.header
    print("  Header is Sendable: CONFIRMED (compiles)")

    let _ = ring.popFront()
    let _ = ring.popFront()
}

// ============================================================
// MARK: - Results Summary
// ============================================================
print("\n=== Architecture Validation Complete ===")
print("Three-layer design (Header / Static Ops / Composed Type)")
print("Dependencies used: Storage_Primitives, Cyclic_Index_Primitives")
print("See individual variant results above.")
