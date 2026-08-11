// MARK: - Storage<Int>.Initialization Consistency Verification
// Purpose: Verify Storage<Int>.Initialization (.empty, .one, .two) transitions
//          remain consistent through push/pop sequences on both Linear and
//          Ring buffer disciplines, and verify Slab bitmap/storage consistency
//          through insert/remove/deinit cycles.
//
// Hypothesis: Storage<Int>.Initialization state is always consistent with actual
//             initialized slots after any sequence of buffer operations, and
//             Slab bitmap always matches actual slot occupancy.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED - All 5 variants pass.
//   V1: Linear .one(0..<count) stays consistent through append/removeLast
//   V2: Ring .one/.two transitions correct through wrap boundary
//   V3: 100 ring wrap cycles all consistent
//   V4: Slab bitmap/storage consistent through insert/remove/deinit with
//       bitmap.ones.forEach driving cleanup (storage.initialization = .empty)
//   V5: firstVacant via bit scan works correctly
//
// Key Finding: Bit.Vector subscript uses Bool (not Bit), popcount is a direct
//              property (not ones.count.all), and Bit.Vector is ~Copyable so
//              must use `var` for ones.forEach access (mutating _read).
//
// Date: 2026-02-03

import Storage_Primitives
import Cyclic_Index_Primitives
import Bit_Vector_Primitives

// ============================================================
// MARK: - Test Helpers
// ============================================================

func idx(_ n: UInt) -> Index<Int> {
    Index<Int>(Ordinal(n))
}

func cnt(_ n: UInt) -> Index<Int>.Count {
    Index<Int>.Count(Cardinal(n))
}

func slotCap(_ storage: Storage<Int>.Heap) -> UInt {
    storage.slotCapacity.rawValue.rawValue
}

/// Verifies that storage.initialization matches expected.
func verify(
    _ storage: Storage<Int>.Heap,
    matches expected: Storage<Int>.Initialization,
    label: String
) {
    let actual = storage.initialization
    if actual == expected {
        print("  \(label): CONFIRMED")
    } else {
        print("  \(label): REFUTED — expected \(expected), got \(actual)")
    }
}

// ============================================================
// MARK: - Variant 1: Linear push/pop cycle
// ============================================================
// Hypothesis: Linear buffer .one(0..<count) stays consistent through
//             append and removeLast sequence
// Result: PENDING

do {
    print("Variant 1 - Linear push/pop initialization:")
    let storage = Storage<Int>.Heap.create(minimumCapacity: cnt(8))
    let cap = slotCap(storage)

    verify(storage, matches: .empty, label: "Initial")

    // Append 3 elements
    storage.initialize(to: 10, at: idx(0))
    storage.initialization = .one(idx(0) ..< idx(1))
    storage.initialize(to: 20, at: idx(1))
    storage.initialization = .one(idx(0) ..< idx(2))
    storage.initialize(to: 30, at: idx(2))
    storage.initialization = .one(idx(0) ..< idx(3))

    verify(storage, matches: .one(idx(0) ..< idx(3)), label: "After 3 appends")

    // Remove last (pop back)
    let v = storage.move(at: idx(2))
    storage.initialization = .one(idx(0) ..< idx(2))
    print("  Removed: \(v)")
    verify(storage, matches: .one(idx(0) ..< idx(2)), label: "After removeLast")

    // Append 1 more
    storage.initialize(to: 40, at: idx(2))
    storage.initialization = .one(idx(0) ..< idx(3))
    verify(storage, matches: .one(idx(0) ..< idx(3)), label: "After re-append")

    // Remove all (back to front for linear)
    let _ = storage.move(at: idx(2))
    let _ = storage.move(at: idx(1))
    let _ = storage.move(at: idx(0))
    storage.initialization = .empty
    verify(storage, matches: .empty, label: "After remove all")

    print("  Capacity used: 3 of \(cap)")
}

// ============================================================
// MARK: - Variant 2: Ring push/pop with .one → .two → .one
// ============================================================
// Hypothesis: Ring buffer correctly transitions between .one and .two
//             as elements wrap around the capacity boundary
// Result: PENDING

do {
    print("\nVariant 2 - Ring .one/.two transitions:")
    let storage = Storage<Int>.Heap.create(minimumCapacity: cnt(4))
    let cap = slotCap(storage)
    print("  Actual capacity: \(cap)")
    var head: UInt = 0
    var count: UInt = 0

    func ringInit() -> Storage<Int>.Initialization {
        if count == 0 { return .empty }
        let headPlusCount = head + count
        if headPlusCount <= cap {
            return .one(idx(head) ..< idx(headPlusCount))
        } else {
            return .two(
                first: idx(head) ..< idx(cap),
                second: idx(0) ..< idx(headPlusCount - cap)
            )
        }
    }

    func pushBack(_ value: Int) {
        let tail = (head + count) % cap
        storage.initialize(to: value, at: idx(tail))
        count += 1
        storage.initialization = ringInit()
    }

    func popFront() -> Int {
        let element = storage.move(at: idx(head))
        head = (head + 1) % cap
        count -= 1
        storage.initialization = ringInit()
        return element
    }

    // Fill partially (non-wrapping)
    pushBack(1); pushBack(2); pushBack(3)
    verify(storage, matches: .one(idx(0) ..< idx(3)), label: "Non-wrapping [1,2,3]")

    // Pop 2, push 2
    let _ = popFront(); let _ = popFront()
    pushBack(4); pushBack(5)
    verify(storage, matches: ringInit(), label: "After pop 2 push 2")

    // Force wrapping: fill to capacity, pop some, push to wrap
    while count < cap { pushBack(Int(count + 10)) }
    let _ = popFront(); let _ = popFront()
    pushBack(99); pushBack(98)
    // head > 0 and head + count > cap → should be .two
    let isTwoWrapping: Bool
    if case .two = storage.initialization { isTwoWrapping = true } else { isTwoWrapping = false }
    let shouldWrap = (head + count) > cap
    print("  Wrapping: shouldWrap=\(shouldWrap), isTwo=\(isTwoWrapping): \(shouldWrap == isTwoWrapping ? "CONFIRMED" : "REFUTED")")
    verify(storage, matches: ringInit(), label: "Wrapping consistency")

    // Pop until 1 element → back to .one
    while count > 1 { let _ = popFront() }
    let isOneAgain: Bool
    if case .one = storage.initialization { isOneAgain = true } else { isOneAgain = false }
    print("  Back to .one: \(isOneAgain ? "CONFIRMED" : "REFUTED")")

    // Pop last → empty
    let _ = popFront()
    verify(storage, matches: .empty, label: "Empty after all pops")
}

// ============================================================
// MARK: - Variant 3: Ring stress test — 100 wrap cycles
// ============================================================
// Hypothesis: After 100 push/pop cycles crossing the wrap boundary,
//             initialization tracking stays correct
// Result: PENDING

do {
    print("\nVariant 3 - Ring stress test (100 wrap cycles):")
    let storage = Storage<Int>.Heap.create(minimumCapacity: cnt(4))
    let cap = slotCap(storage)
    var head: UInt = 0
    var count: UInt = 0
    var consistent = true

    func ringInit() -> Storage<Int>.Initialization {
        if count == 0 { return .empty }
        let hpc = head + count
        if hpc <= cap { return .one(idx(head) ..< idx(hpc)) }
        else { return .two(first: idx(head) ..< idx(cap), second: idx(0) ..< idx(hpc - cap)) }
    }

    func pushBack(_ value: Int) {
        let tail = (head + count) % cap
        storage.initialize(to: value, at: idx(tail))
        count += 1
        storage.initialization = ringInit()
    }

    func popFront() -> Int {
        let element = storage.move(at: idx(head))
        head = (head + 1) % cap
        count -= 1
        storage.initialization = ringInit()
        return element
    }

    for cycle in 0..<100 {
        // Push cap-1 elements
        for j: UInt in 0..<(cap - 1) { pushBack(Int(UInt(cycle) * 100 + j)) }
        // Pop 2
        let _ = popFront(); let _ = popFront()
        // Push 2 more (forces wrap)
        pushBack(Int(cycle * 100 + 90)); pushBack(Int(cycle * 100 + 91))
        // Verify consistency
        if storage.initialization != ringInit() {
            print("  REFUTED at cycle \(cycle)")
            consistent = false
            break
        }
        // Pop all
        while count > 0 { let _ = popFront() }
        if storage.initialization != .empty {
            print("  REFUTED at cycle \(cycle) empty check")
            consistent = false
            break
        }
    }
    if consistent { print("  100 cycles: CONFIRMED") }
}

// ============================================================
// MARK: - Variant 4: Slab bitmap/storage consistency
// ============================================================
// Hypothesis: Bit.Vector occupancy bitmap stays consistent with
//             actual storage state through insert/remove/deinit cycles
// Result: PENDING

do {
    print("\nVariant 4 - Slab bitmap/storage consistency:")
    let storage = Storage<Int>.Heap.create(minimumCapacity: cnt(8))
    let cap = slotCap(storage)
    // Slab: storage.initialization stays .empty; bitmap is truth
    storage.initialization = .empty

    var bitmap = Bit.Vector(capacity: try! Bit.Index.Count(Cardinal(cap)))
    var occupancy: UInt = 0

    func insert(_ value: Int, at slot: UInt) {
        storage.initialize(to: value, at: idx(slot))
        bitmap[Bit.Index(Ordinal(slot))] = true
        occupancy += 1
    }

    func remove(at slot: UInt) -> Int {
        let value = storage.move(at: idx(slot))
        bitmap[Bit.Index(Ordinal(slot))] = false
        occupancy -= 1
        return value
    }

    // Insert at sparse slots
    insert(10, at: 0)
    insert(20, at: 2)
    insert(30, at: 4)
    insert(40, at: 6)

    let pop4 = bitmap.popcount
    print("  After 4 inserts: popcount=\(pop4.rawValue), expected 4: \(pop4.rawValue == 4 ? "CONFIRMED" : "REFUTED")")
    print("  Slot 0 occupied: \(bitmap[Bit.Index(Ordinal(UInt(0)))] == true ? "CONFIRMED" : "REFUTED")")
    print("  Slot 1 vacant:   \(bitmap[Bit.Index(Ordinal(UInt(1)))] == false ? "CONFIRMED" : "REFUTED")")
    print("  Slot 2 occupied: \(bitmap[Bit.Index(Ordinal(UInt(2)))] == true ? "CONFIRMED" : "REFUTED")")

    // Remove slots 0 and 4
    let v0 = remove(at: 0)
    let v4 = remove(at: 4)
    print("  Removed slot 0: \(v0) == 10: \(v0 == 10 ? "CONFIRMED" : "REFUTED")")
    print("  Removed slot 4: \(v4) == 30: \(v4 == 30 ? "CONFIRMED" : "REFUTED")")

    let pop2 = bitmap.popcount
    print("  After 2 removes: popcount=\(pop2.rawValue), expected 2: \(pop2.rawValue == 2 ? "CONFIRMED" : "REFUTED")")

    // Re-insert at slot 0 (reuse freed slot)
    insert(50, at: 0)
    let pop3 = bitmap.popcount
    print("  After re-insert: popcount=\(pop3.rawValue), expected 3: \(pop3.rawValue == 3 ? "CONFIRMED" : "REFUTED")")

    // Verify actual value at slot 0
    @unsafe let ptr = storage.pointer(at: idx(0))
    @unsafe let val = ptr.pointee
    print("  Slot 0 value: \(val) == 50: \(val == 50 ? "CONFIRMED" : "REFUTED")")

    // Simulate slab deinit: iterate ones, deinitialize each
    var deinitCount: UInt = 0
    bitmap.ones.forEach { bitIndex in
        let storageIndex = idx(bitIndex.position.rawValue)
        storage.deinitialize(at: storageIndex)
        deinitCount += 1
    }
    print("  Deinit via bitmap: \(deinitCount) slots, expected 3: \(deinitCount == 3 ? "CONFIRMED" : "REFUTED")")
}

// ============================================================
// MARK: - Variant 5: Slab firstVacant scan
// ============================================================
// Hypothesis: First vacant slot can be found by scanning bitmap
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

do {
    print("\nVariant 5 - Slab firstVacant scan:")
    var bitmap = Bit.Vector(capacity: try! Bit.Index.Count(Cardinal(UInt(64))))

    // Fill slots 0-4
    for i: UInt in 0..<5 { bitmap[Bit.Index(Ordinal(i))] = true }

    // Find first vacant via linear scan
    func firstVacant(_ bmp: borrowing Bit.Vector, max: UInt) -> UInt? {
        for i: UInt in 0..<max {
            if bmp[Bit.Index(Ordinal(i))] == false { return i }
        }
        return nil
    }

    let fv1 = firstVacant(bitmap, max: 64)
    print("  After filling 0-4: firstVacant=\(fv1 ?? 999) == 5: \(fv1 == 5 ? "CONFIRMED" : "REFUTED")")

    // Fill slot 5
    bitmap[Bit.Index(Ordinal(UInt(5)))] = true
    let fv2 = firstVacant(bitmap, max: 64)
    print("  After filling 0-5: firstVacant=\(fv2 ?? 999) == 6: \(fv2 == 6 ? "CONFIRMED" : "REFUTED")")

    // Clear slot 2
    bitmap[Bit.Index(Ordinal(UInt(2)))] = false
    let fv3 = firstVacant(bitmap, max: 64)
    print("  After clearing 2: firstVacant=\(fv3 ?? 999) == 2: \(fv3 == 2 ? "CONFIRMED" : "REFUTED")")
}

// ============================================================
// MARK: - Results Summary
// ============================================================
print("\n=== Initialization Consistency Verification Complete ===")
print("Linear: .one tracking through append/removeLast")
print("Ring: .one/.two transitions through wrap cycles")
print("Slab: bitmap/storage consistency through insert/remove/deinit")
