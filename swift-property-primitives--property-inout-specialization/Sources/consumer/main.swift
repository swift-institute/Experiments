// MARK: - Property.Inout Specialization Verification
// Purpose: Does a storage-generic operation, reached THROUGH the real `Property.Inout`
//          accessor stack (phantom-tag → Tagged<Tag, Ownership.Inout<Base>> → withUnsafePointer
//          borrow → _modify coroutine), still specialize to ZERO witness-table dispatch on
//          `pointer(at:)` in RELEASE across a MODULE boundary — and stay correct (no trip of
//          swiftlang/swift#81624 or the documented borrow-init release miscompile)?
// Hypothesis: The Property.Inout indirection does NOT defeat specialization of the generic
//          core; safe usage compiles and runs correctly in release cross-module.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108)
// Platform: arm64-apple-macosx26.0
//
// Result: CONFIRMED — the property pattern specializes; reuse locus = CONCRETE-Base.
// Date: 2026-05-24
//
// Findings:
//  • Correctness: release + cross-module run correct (checksum 10241024 / checksumB 10240512).
//    Neither variant tripped swiftlang/swift#81624 nor the borrow-init release miscompile.
//  • Variant A (concrete Base == LinearBuffer): the Property.Inout accessor + the whole
//    Tagged<Tag, Ownership.Inout<Base>> stack FLATTEN away — in the defining module `all`
//    has 0 witness_method and a direct `index_addr` loop (storage abstraction gone). A
//    consumer calls a pre-specialized concrete symbol → zero witness dispatch UNCONDITIONALLY
//    (no @inlinable needed). The static-enum result (storage-protocol-specialization) transfers
//    fully through the real property stack.
//  • Variant B (generic Base: LinearBufferProtocol): in the defining module `all` keeps
//    2 witness_method (LinearBufferProtocol.store + StorageProtocol.pointer) and NO specialized
//    all<LinearBuffer> is emitted. It only collapses when SIL bodies are visible (@inlinable /
//    same-package CMO). A resilient cross-PACKAGE consumer would dispatch through witnesses
//    unless `all`/`bumpShared` are @inlinable — and @inlinable on this ~Copyable Property.Inout
//    path is exactly what Property.Inout.swift documents as miscompile-prone.
//
// DECISION: use Variant A — concrete-Base Property.Inout accessors forwarding to a shared
// generic-over-storage core. It specializes unconditionally and stays clear of the @inlinable
// sharp edges. (Internal `Operations` here is just the proven generic core as scaffolding; in
// production the shared algorithm would live as StorageProtocol extension methods, NOT a public
// `Buffer.Linear.Operations` — the accessor IS the surface.)
//
// Scope ([EXP-020]): proves the compiler capability; production swift-buffer-linear refactor
// still needs in-package SIL recheck. Companion: swift-institute/Experiments/storage-protocol-specialization.

import PropCore

var buf = LinearBuffer(capacity: 1024)  // every slot initialized to 1

// Hot loop across the module boundary through the property accessor (Variant A).
for _ in 0..<10_000 {
    buf.bump.all(by: 1, count: 1024)
}

// Each slot: 1 + 10_000 = 10_001; × 1024 slots = 10_241_024.
print("checksum:", buf.checksum(count: 1024))  // expect: 10241024

// Variant B — protocol-Base shared accessor, cross-module.
var bufB = LinearBuffer(capacity: 512)
for _ in 0..<10_000 {
    bufB.bumpShared.all(by: 2, count: 512)
}
// Each slot: 1 + 20_000 = 20_001; × 512 = 10_240_512.
print("checksumB:", bufB.checksum(count: 512))  // expect: 10240512
