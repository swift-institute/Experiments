// MARK: - Storage.Protocol Heap Specialization Gate — Concrete Call Site
//
// See StorageHeapProtocolGeneric.swift for the hypothesis/result header.
//
// This SECOND module invokes the generic `probe` with the concrete value-type-
// façade conformer Storage<Int>.Heap. The cross-module boundary + -c release is
// what [EXP-017] requires for an adoption-grade specialization claim.
//
// Toolchain: Apple Swift 6.3.2
// Platform: macOS 26 (arm64)
// Status: CONFIRMED — see Outputs/sil-grep.txt

import StorageHeapProtocolGeneric

import Storage_Heap_Primitives
import Storage_Initialization_Primitives
import Index_Primitives

// MARK: - Value-type-façade conformer: Storage.Heap

/// Calls the generic `probe` with a concrete `Storage<Int>.Heap`.
/// `@inline(never)` keeps the specialized call body intact for the SIL dump.
@inline(never)
func callHeap() -> Int {
    var storage = Storage<Int>.Heap.create(minimumCapacity: Index<Int>.Count(8))
    let slot = Index<Int>(3)
    // Initialize exactly slot 3; record that single slot as initialized so the
    // backing-buffer deinit cleans up precisely what was initialized.
    unsafe storage.pointer(at: slot).initialize(to: 42)
    storage.initialization = .one(slot..<Index<Int>(4))
    let result = probe(storage, at: slot)
    storage.deinitialize(at: slot)
    storage.initialization = .empty
    return result
}

let heapResult = callHeap()
print("heap probe =", heapResult)
