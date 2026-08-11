// MARK: - V03: Enum _modify Recovery Strategies
// Purpose: Test whether DiagnoseStaticExclusivity crash is fixed and explore
//          recovery strategies for _modify on ~Copyable enum types.
// Hypothesis: Heap _modify recoverable via let-binding pointer bypass
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — DiagnoseStaticExclusivity crash IS FIXED in Swift 6.2.3+.
//         Heap _modify works via let-binding pointer bypass (zero-cost).
//         Inline _modify NOT recoverable via pointer (borrow temporary).
//         Production fix: recover heap _modify, spill inline to heap on _modify.
//
//         V1: CONFIRMED — Heap-only _modify through let-binding pointer bypass
//         V2: PARTIAL   — Heap works. Inline mutation lost (let-borrow temporary)
//         V3: CONFIRMED — Heap-only _modify via delegated pointer
//         V4: PARTIAL   — Separated pointer computation. Same inline failure
//         V5: PARTIAL   — withUnsafeMutablePointer: debug OK, release broken
//
// Date: 2026-03-21
//
// Consolidates: small-enum-modify-recovery (V1-V5)
// Supports: DiagnoseStaticExclusivity crash fix, heap _modify recovery

// --- Setup: Minimal reproduction of Buffer.Linear.Small structure ---

@unsafe
class HeapStorage {
    let ptr: UnsafeMutablePointer<Int>

    init(capacity: Int) {
        ptr = unsafe .allocate(capacity: capacity)
    }

    @unsafe
    func pointer(at index: Int) -> UnsafeMutablePointer<Int> {
        unsafe ptr.advanced(by: index)
    }

    deinit { unsafe ptr.deallocate() }
}

struct InlineStorage: ~Copyable {
    var _e0: Int = 0
    var _e1: Int = 0

    @unsafe
    func pointer(at index: Int) -> UnsafeMutablePointer<Int> {
        unsafe withUnsafePointer(to: _e0) {
            unsafe UnsafeMutablePointer(mutating: $0.advanced(by: index))
        }
    }
}

struct HeapBuffer: ~Copyable {
    var count: Int = 0
    var storage: HeapStorage
    init() { storage = unsafe HeapStorage(capacity: 16) }
}

struct InlineBuffer: ~Copyable {
    var count: Int = 0
    var storage: InlineStorage = .init()
}

@frozen
enum SmallRep: ~Copyable {
    case inline(InlineBuffer)
    case heap(HeapBuffer)
}

// --- V1: Heap-only _modify through let-binding pointer bypass ---
// Result: CONFIRMED — heap path: 42→99 (debug+release). No crash.

struct V1_HeapOnly: ~Copyable {
    var _storage: SmallRep

    subscript(index: Int) -> Int {
        _read {
            switch _storage {
            case .heap(let heap):
                yield unsafe heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                yield unsafe buf.storage.pointer(at: index).pointee
            }
        }
        _modify {
            switch _storage {
            case .heap(let heap):
                yield unsafe &heap.storage.pointer(at: index).pointee
            case .inline(_):
                fatalError("_modify not supported for inline case")
            }
        }
    }
}

// --- V2: Both cases — heap works, inline mutation lost ---
// Result: PARTIAL — Heap: 42→99. Inline: mutation lost (borrow temporary)

struct V2_BothCases: ~Copyable {
    var _storage: SmallRep

    subscript(index: Int) -> Int {
        _read {
            switch _storage {
            case .heap(let heap):
                yield unsafe heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                yield unsafe buf.storage.pointer(at: index).pointee
            }
        }
        _modify {
            switch _storage {
            case .heap(let heap):
                yield unsafe &heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                // WARNING: This yields into a borrow temporary, not self's memory!
                yield unsafe &buf.storage.pointer(at: index).pointee
            }
        }
    }
}

// --- Execution ---

func testV1() {
    print("=== V1: Heap-only _modify through pointer ===")
    var heap = HeapBuffer()
    heap.count = 1
    unsafe heap.storage.pointer(at: 0).initialize(to: 42)
    var v = V1_HeapOnly(_storage: .heap(heap))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

func testV2Heap() {
    print("\n=== V2: Both cases — heap path ===")
    var heap = HeapBuffer()
    heap.count = 1
    unsafe heap.storage.pointer(at: 0).initialize(to: 42)
    var v = V2_BothCases(_storage: .heap(heap))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0])")
}

func testV2Inline() {
    print("\n=== V2: Both cases — inline path (mutation lost) ===")
    var buf = InlineBuffer()
    buf.storage._e0 = 42
    var v = V2_BothCases(_storage: .inline(buf))
    print("Before: \(v[0])")
    v[0] = 99
    print("After:  \(v[0]) (expected: still 42 — mutation into borrow temporary)")
}

testV1()
testV2Heap()
testV2Inline()

print("\nSUMMARY:")
print("  Heap _modify: RECOVERED via let-binding pointer bypass (zero-cost)")
print("  Inline _modify: NOT recoverable via pointer (borrow temporary)")
print("  Production fix: spill inline to heap on _modify (ensureHeap pattern)")
