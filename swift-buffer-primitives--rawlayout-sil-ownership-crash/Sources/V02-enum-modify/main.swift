// MARK: - V02: Enum _modify Language Limitation
// Purpose: Validate that Swift _modify coroutines cannot yield mutable references
//          into enum payloads for ~Copyable associated values, while Optional._modify
//          CAN yield &optional! for ~Copyable wrapped values.
// Hypothesis: Optional has special compiler support that arbitrary enums lack
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Optional._modify yields via unchecked_take_enum_data_addr
//         (non-destructive for single-payload enums). Multi-payload enums lack
//         this guarantee. Enum _modify fundamentally impossible.
//
//         V1: CONFIRMED — Optional _read/_modify with &optional! works
//         V2: CONFIRMED — Enum partial reinit REJECTED
//         V3: CONFIRMED — Enum full self reinit works (extra moves)
//         V4: CONFIRMED — guard case consumes in _read (unlike switch)
//         V5: CONFIRMED — Enum switch _read borrows correctly (SE-0432)
//         V6: CONFIRMED — Enum _modify with guard case: partial reinit REJECTED
//         V7: REFUTED  — Enum _modify with full reinit: self consumed across yield
//         V8: CONFIRMED — Optional switch _read + &optional! _modify (best of both)
//
// Date: 2026-03-21
//
// Consolidates: noncopyable-enum-modify (V1-V8)
// Supports: small-buffer-enum-compiler-workarounds.md Bug 2

// --- Setup ---

struct Resource: ~Copyable {
    var value: Int
    init(_ value: Int) { self.value = value }
    mutating func increment() { value += 1 }
}

enum Storage: ~Copyable {
    case inline(Resource)
    case heap(Resource)
}

// --- V1: Optional _read + _modify with &optional! (baseline) ---
// Result: CONFIRMED — compiles and runs

struct V1_OptionalHolder: ~Copyable {
    var _resource: Resource?

    var resource: Resource {
        _read { yield _resource! }
        _modify { yield &_resource! }
    }
}

func testV1() {
    var holder = V1_OptionalHolder(_resource: Resource(10))
    holder.resource.increment()
    print("V1 Optional _modify: \(holder.resource.value)")  // 11
}

// --- V3: Enum full self reinit (the only enum mutation that works) ---
// Result: CONFIRMED — compiles, but costs extra moves (not zero-cost)

struct V3_EnumFullReinit: ~Copyable {
    var _storage: Storage

    init(_storage: consuming Storage) {
        self._storage = _storage
    }

    mutating func incrementHeap() {
        switch _storage {
        case .heap(var res):
            res.increment()
            self = V3_EnumFullReinit(_storage: .heap(res))
        case .inline(var res):
            res.increment()
            self = V3_EnumFullReinit(_storage: .inline(res))
        }
    }
}

func testV3() {
    var holder = V3_EnumFullReinit(_storage: .heap(Resource(20)))
    holder.incrementHeap()
    switch holder._storage {
    case .heap(let res): print("V3 Enum full reinit: \(res.value)")  // 21
    case .inline(let res): print("V3 (inline): \(res.value)")
    }
}

// --- V5: Enum switch _read borrows correctly (SE-0432) ---
// Result: CONFIRMED

struct V5_EnumSwitchRead: ~Copyable {
    var _storage: Storage

    var heapValue: Int {
        switch _storage {
        case .heap(let res): return res.value
        case .inline(let res): return res.value
        }
    }
}

func testV5() {
    let holder = V5_EnumSwitchRead(_storage: .heap(Resource(30)))
    print("V5 Enum switch _read: \(holder.heapValue)")  // 30
}

// --- V8: Optional — best of both worlds ---
// Result: CONFIRMED — switch _read + &optional! _modify
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

struct V8_OptionalBestOfBoth: ~Copyable {
    var _resource: Resource?

    var resource: Resource {
        _read {
            switch _resource {
            case .some(let res): yield res
            case .none: fatalError("nil")
            }
        }
        _modify { yield &_resource! }
    }
}

func testV8() {
    var holder = V8_OptionalBestOfBoth(_resource: Resource(50))
    print("V8 Optional read: \(holder.resource.value)")  // 50
    holder.resource.increment()
    print("V8 After _modify: \(holder.resource.value)")  // 51
}

// --- Commented-out variants that don't compile (error messages documented) ---

// V2: Enum partial reinit — error: "cannot partially reinitialize 'self'"
// V4: guard case in _read — error: "'self' is borrowed and cannot be consumed"
// V6: guard case in _modify — errors: "consumed here" + "cannot partially reinitialize"
// V7: _modify with full reinit — error: "missing reinitialization of inout parameter
//     'self' after consume" — self consumed during yield suspension

// --- Execution ---

testV1()
testV3()
testV5()
testV8()

print("\nCONCLUSION: Optional has compiler support via unchecked_take_enum_data_addr")
print("  (lib/SILGen/SILGenLValue.cpp:966-987). Safe for single-payload enums.")
print("  Multi-payload enums: discriminant bits may overlap with payload data.")
print("  No general _modify into enum payloads exists.")
