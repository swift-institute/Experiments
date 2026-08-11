// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// Alignment Spike
// Validates that @_alignment(128) propagates through:
// (a) a generic wrapper, (b) struct composition, (c) array stride.
// Also checks Stealing.Worker-equivalent instance size for false-sharing.

import Synchronization

// MARK: - V1: @_alignment(128) is NOT supported

func v1() {
    print("V1: @_alignment(128) — BLOCKED")
    print("    Swift error: '@_alignment' cannot increase alignment above maximum alignment of 16")
    print("    CacheLine.Padded<T> via @_alignment is not possible in current Swift.")
    print("    Alternative: manual padding bytes to fill a 128-byte stride.")
    print("V1: FAIL (compiler limitation, not a code bug)")
}

// MARK: - V2: Manual padding alternative

struct CacheLinePadded128<Value: ~Copyable>: ~Copyable {
    var value: Value
    // Pad to 128 bytes total stride. The actual padding needed depends on
    // sizeof(Value). For Atomic<UInt64> (8 bytes), we need 120 bytes.
    // Using a fixed 112-byte pad (128 - 16 for value + alignment slack).
    private var _pad: (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
                        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    init(_ value: consuming Value) { self.value = value }
}

func v2() {
    let align = MemoryLayout<CacheLinePadded128<Atomic<UInt64>>>.alignment
    let size = MemoryLayout<CacheLinePadded128<Atomic<UInt64>>>.size
    let stride = MemoryLayout<CacheLinePadded128<Atomic<UInt64>>>.stride
    print("V2: CacheLinePadded128<Atomic<UInt64>> (manual padding)")
    print("    alignment = \(align), size = \(size), stride = \(stride)")
    if stride >= 128 {
        print("V2: PASS — stride >= 128")
    } else {
        print("V2: FAIL — stride \(stride) < 128; need more padding")
    }
}

// MARK: - V3: posix_memalign alternative for heap-allocated padded values

func v3() {
    print("V3: posix_memalign for heap-allocated cache-line-aligned storage")
    var ptr: UnsafeMutableRawPointer?
    let result = posix_memalign(&ptr, 128, 128)
    precondition(result == 0, "V3: posix_memalign returned \(result)")
    let address = Int(bitPattern: ptr!)
    precondition(address % 128 == 0, "V3: address \(address) not 128-aligned")
    free(ptr)
    print("V3: PASS — posix_memalign(128) works; address is 128-aligned")
}

// MARK: - V4: Class instance size proxy for Worker false-sharing check
// Simulates the Stealing.Worker stored properties: a class with
// a deque (modeled as 2 Atomics + pointer), a condvar (modeled as
// pthread_mutex_t + pthread_cond_t), and a thread handle.

import Darwin

final class WorkerProxy {
    let top = Atomic<Int>(0)
    let bottom = Atomic<Int>(0)
    var storage: UnsafeMutableBufferPointer<Int> = .init(start: nil, count: 0)
    var mutex = pthread_mutex_t()
    var cond = pthread_cond_t()
    var threadHandle: pthread_t? = nil
}

func v4() {
    let size = MemoryLayout<WorkerProxy>.size   // class reference = pointer
    let proxy = WorkerProxy()
    let instanceSize = malloc_size(Unmanaged.passUnretained(proxy).toOpaque())
    print("V4: WorkerProxy (simulated Stealing.Worker)")
    print("    reference size = \(size) (always \(MemoryLayout<AnyObject>.size))")
    print("    instance size = \(instanceSize) bytes")
    if instanceSize < 128 {
        print("V4: WARNING — instance size \(instanceSize) < 128; two back-to-back allocations COULD share a 128-byte cache line on Apple Silicon")
    } else {
        print("V4: OK — instance size \(instanceSize) >= 128; allocator-provided separation likely sufficient")
    }
    // Not a pass/fail — informational
}

// MARK: - V5: Plain Atomic alignment (baseline)

func v5() {
    let align = MemoryLayout<Atomic<UInt64>>.alignment
    let size = MemoryLayout<Atomic<UInt64>>.size
    print("V5: Baseline Atomic<UInt64>")
    print("    alignment = \(align), size = \(size)")
}

// MARK: - Driver

v1()
v2()
v3()
v4()
v5()
print("Spike complete.")
