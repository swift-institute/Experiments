// MARK: - Storage.Protocol Specialization Gate — Concrete Call Sites
//
// See StorageProtocolGeneric.swift for the hypothesis/result header.
//
// This SECOND module invokes the generic `probe` with two concrete conformers:
//   - struct: Storage<Int>.Inline<8>
//   - class:  Storage<Int>.Pool
// The cross-module boundary + -c release is what [EXP-017] requires for an
// adoption-grade specialization claim.
//
// Toolchain: Apple Swift 6.3.2
// Platform: macOS 26 (arm64)
// Status: CONFIRMED — see Outputs/sil-grep.txt

import StorageProtocolGeneric

import Storage_Inline_Primitives
import Storage_Pool_Primitives
import Storage_Initialization_Primitives
import Index_Primitives

// MARK: - Struct conformer: Storage.Inline

/// Calls the generic `probe` with a concrete `Storage<Int>.Inline<8>`.
/// `@inline(never)` keeps the specialized call body intact for the SIL dump.
@inline(never)
func callInline() -> Int {
    var storage = Storage<Int>.Inline<8>()
    let slot: Index<Int>.Bounded<8> = 3
    storage.initialize(to: 42, at: slot)
    let result = probe(storage, at: Index<Int>(slot))
    _ = storage.move(at: slot)
    return result
}

// MARK: - Class conformer: Storage.Pool

/// Calls the generic `probe` with a concrete `Storage<Int>.Pool`.
@inline(never)
func callPool() -> Int {
    let pool = try! Storage<Int>.Pool(capacity: Index<Int>.Count(8))
    let slot = try! pool.allocate()
    unsafe pool.pointer(at: slot).initialize(to: 99)
    let result = probe(pool, at: slot)
    unsafe pool.pointer(at: slot).deinitialize(count: .one)
    try! pool.deallocate(at: slot)
    return result
}

let inlineResult = callInline()
let poolResult = callPool()
print("inline probe =", inlineResult)
print("pool probe   =", poolResult)
