// MARK: - Dictionary Iterator Bitmap Bug — Cross-Module Reproduction
// Purpose: Isolate why Bit.Vector.Ones.Bounded.Iterator produces 0 elements
//          when stored inside Dictionary.Iterator but works in isolation.
//          The isolated experiment (swift-bit-vector-primitives/Experiments/
//          iterator-struct-storage) proved all 9 variants pass — the bug
//          requires the Dictionary context.
// Hypothesis: The combination of Buffer.Slab (~Copyable conditional Copyable),
//             cross-module boundaries, and struct property storage triggers
//             the failure. Incremental construction identifies which factor.
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-02-21-a
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — All 8 variants PASS when compiled as external dependency.
//         The bug ONLY manifests when the library is compiled with -enable-testing
//         (i.e., when running `swift test` from the same package). Diagnostic prints
//         inside Iterator.init confirmed: iterator works inside init, returns nil
//         after init return. Reordering struct fields turns silent corruption into
//         SIGSEGV (signal 11). Root cause: Swift compiler codegen bug with struct
//         move/return when struct contains conditionally-Copyable (~Copyable) fields
//         (Buffer.Slab) alongside value-type iterator fields, compiled with
//         -enable-testing. Workaround: box the iterator in a class (_IteratorBox).
// Date: 2026-02-24

import Dictionary_Primitives

// ============================================================================
// MARK: - V1: Dictionary for-in (reproduces the bug)
// Hypothesis: This MUST fail (it's the reported bug)
// Result: [PENDING]
// ============================================================================

do {
    print("=== V1: Dictionary for-in (reported bug) ===")
    var dict = Dictionary<String, Int>()
    dict.set("a", 1)
    dict.set("b", 2)
    dict.set("c", 3)

    var count = 0
    for (key, value) in dict {
        print("  V1 got: \(key) = \(value)")
        count += 1
    }
    print("  V1 count: \(count) (expected 3)")
    print("  V1 result: \(count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - V2: Dictionary manual makeIterator().next()
// Hypothesis: Fails — same as for-in but explicit
// Result: [PENDING]
// ============================================================================

do {
    print("=== V2: Dictionary manual iterator ===")
    var dict = Dictionary<String, Int>()
    dict.set("x", 10)
    dict.set("y", 20)

    var iter = dict.makeIterator()
    var count = 0
    while let pair = iter.next() {
        print("  V2 got: \(pair.key) = \(pair.value)")
        count += 1
    }
    print("  V2 count: \(count) (expected 2)")
    print("  V2 result: \(count == 2 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - V3: Buffer.Slab occupiedSlots iterator directly
// Hypothesis: If this passes, the bug is in Dictionary.Iterator.init,
//             not in Buffer.Slab.occupiedSlots
// Result: [PENDING]
// ============================================================================

do {
    print("=== V3: Buffer.Slab occupiedSlots direct iteration ===")
    var dict = Dictionary<String, Int>()
    dict.set("a", 1)
    dict.set("b", 2)
    dict.set("c", 3)

    // Access the keys slab and iterate its occupied slots directly
    let keys = dict._keys
    var iterator = keys.occupiedSlots.makeIterator()
    var count = 0
    while let slot = iterator.next() {
        print("  V3 got slot: \(slot)")
        count += 1
    }
    print("  V3 count: \(count) (expected 3)")
    print("  V3 result: \(count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - V4: occupiedSlots forEach (known working path)
// Hypothesis: Always passes — forEach uses local iterator
// Result: [PENDING]
// ============================================================================

do {
    print("=== V4: occupiedSlots forEach ===")
    var dict = Dictionary<String, Int>()
    dict.set("a", 1)
    dict.set("b", 2)
    dict.set("c", 3)

    let keys = dict._keys
    var count = 0
    keys.occupiedSlots.forEach { slot in
        print("  V4 got slot: \(slot)")
        count += 1
    }
    print("  V4 count: \(count) (expected 3)")
    print("  V4 result: \(count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - V5: Struct wrapping Buffer.Slab + bitmap iterator
// Hypothesis: Mirrors Dictionary.Iterator pattern but without Dictionary overhead.
//             If this fails, Buffer.Slab's conditional Copyable is the trigger.
// Result: [PENDING]
// ============================================================================

do {
    print("=== V5: Struct wrapping Buffer.Slab + bitmap iterator ===")

    struct SlabIterator {
        let keys: Buffer<String>.Slab
        var occupiedSlots: Bit.Vector.Ones.Bounded.Iterator

        init(_ keys: Buffer<String>.Slab) {
            let occupied = keys.occupiedSlots
            self.keys = keys
            self.occupiedSlots = occupied.makeIterator()
        }

        mutating func next() -> String? {
            guard let slot = occupiedSlots.next() else { return nil }
            return keys[slot]
        }
    }

    var dict = Dictionary<String, Int>()
    dict.set("a", 1)
    dict.set("b", 2)
    dict.set("c", 3)

    var iter = SlabIterator(dict._keys)
    var count = 0
    while let key = iter.next() {
        print("  V5 got key: \(key)")
        count += 1
    }
    print("  V5 count: \(count) (expected 3)")
    print("  V5 result: \(count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - V6: Struct with TWO Buffer.Slab properties + bitmap iterator
// Hypothesis: Mirrors Dictionary.Iterator exactly (keys + values + iterator).
//             If this fails but V5 passes, the second slab triggers it.
// Result: [PENDING]
// ============================================================================

do {
    print("=== V6: Two Buffer.Slab props + bitmap iterator ===")

    struct DualSlabIterator {
        let keys: Buffer<String>.Slab
        let values: Buffer<Int>.Slab
        var occupiedSlots: Bit.Vector.Ones.Bounded.Iterator

        init(keys: Buffer<String>.Slab, values: Buffer<Int>.Slab) {
            let occupied = keys.occupiedSlots
            self.keys = keys
            self.values = values
            self.occupiedSlots = occupied.makeIterator()
        }

        mutating func next() -> (key: String, value: Int)? {
            guard let slot = occupiedSlots.next() else { return nil }
            return (key: keys[slot], value: values[slot])
        }
    }

    var dict = Dictionary<String, Int>()
    dict.set("a", 1)
    dict.set("b", 2)
    dict.set("c", 3)

    var iter = DualSlabIterator(keys: dict._keys, values: dict._values)
    var count = 0
    while let pair = iter.next() {
        print("  V6 got: \(pair.key) = \(pair.value)")
        count += 1
    }
    print("  V6 count: \(count) (expected 3)")
    print("  V6 result: \(count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - V7: Same as V6 but with IteratorProtocol conformance
// Hypothesis: Protocol conformance changes witness table dispatch
// Result: [PENDING]
// ============================================================================

do {
    print("=== V7: V6 + IteratorProtocol conformance ===")

    struct ProtoIterator: IteratorProtocol {
        let keys: Buffer<String>.Slab
        let values: Buffer<Int>.Slab
        var occupiedSlots: Bit.Vector.Ones.Bounded.Iterator

        init(keys: Buffer<String>.Slab, values: Buffer<Int>.Slab) {
            let occupied = keys.occupiedSlots
            self.keys = keys
            self.values = values
            self.occupiedSlots = occupied.makeIterator()
        }

        mutating func next() -> (key: String, value: Int)? {
            guard let slot = occupiedSlots.next() else { return nil }
            return (key: keys[slot], value: values[slot])
        }
    }

    var dict = Dictionary<String, Int>()
    dict.set("a", 1)
    dict.set("b", 2)
    dict.set("c", 3)

    var iter = ProtoIterator(keys: dict._keys, values: dict._values)
    var count = 0
    while let pair = iter.next() {
        print("  V7 got: \(pair.key) = \(pair.value)")
        count += 1
    }
    print("  V7 count: \(count) (expected 3)")
    print("  V7 result: \(count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - V8: Same as V7 but used via for-in (Sequence)
// Hypothesis: for-in adds another copy layer
// Result: [PENDING]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

do {
    print("=== V8: V7 used via for-in ===")

    struct ForInIterator: IteratorProtocol {
        let keys: Buffer<String>.Slab
        let values: Buffer<Int>.Slab
        var occupiedSlots: Bit.Vector.Ones.Bounded.Iterator

        init(keys: Buffer<String>.Slab, values: Buffer<Int>.Slab) {
            let occupied = keys.occupiedSlots
            self.keys = keys
            self.values = values
            self.occupiedSlots = occupied.makeIterator()
        }

        mutating func next() -> (key: String, value: Int)? {
            guard let slot = occupiedSlots.next() else { return nil }
            return (key: keys[slot], value: values[slot])
        }
    }

    struct DictSequence: Swift.Sequence {
        let keys: Buffer<String>.Slab
        let values: Buffer<Int>.Slab

        func makeIterator() -> ForInIterator {
            ForInIterator(keys: keys, values: values)
        }
    }

    var dict = Dictionary<String, Int>()
    dict.set("a", 1)
    dict.set("b", 2)
    dict.set("c", 3)

    var count = 0
    for (key, value) in DictSequence(keys: dict._keys, values: dict._values) {
        print("  V8 got: \(key) = \(value)")
        count += 1
    }
    print("  V8 count: \(count) (expected 3)")
    print("  V8 result: \(count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("=== RESULTS SUMMARY ===")
print("V1 (dict for-in):            reported bug")
print("V2 (dict manual iter):       reported bug")
print("V3 (slab occupiedSlots):     direct bitmap iteration")
print("V4 (slab forEach):           known working path")
print("V5 (struct + 1 slab):        isolates slab interaction")
print("V6 (struct + 2 slabs):       mirrors Dictionary.Iterator layout")
print("V7 (V6 + IteratorProtocol):  adds protocol conformance")
print("V8 (V7 + for-in):            full reproduction attempt")
