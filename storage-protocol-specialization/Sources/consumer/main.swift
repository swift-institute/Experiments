// MARK: - Storage.Protocol Specialization Verification
// Purpose: Verify that a Layer-2 algorithm generic over `some StorageProtocol` specializes
//          (no witness-table dispatch on `pointer(at:)`) in RELEASE across a MODULE boundary
//          — the conditions that actually matter for the buffer/storage refactor ([EXP-017]).
// Hypothesis: With a statically-known concrete storage, the optimizer specializes the generic
//          core; the cross-module consumer makes a plain call into specialized code. Storage
//          being `~Copyable` with a suppressed associated Element does not defeat this.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108)
// Platform: arm64-apple-macosx26.0
//
// Result: CONFIRMED — the generic core specializes; no witness-table dispatch on the hot path.
// Date: 2026-05-24
//
// Evidence:
//   1. Runtime (release, cross-module): `sum: 10240000` (Outputs/run.txt) — correct.
//   2. Within-module SIL (Outputs/core.sil): `LinearHeap.total` contains NO witness_method,
//      NO apply, NO call — `Operations.sum<HeapStorage>` was specialized AND inlined to raw
//      pointer arithmetic: struct_extract HeapStorage.base → index_addr → load → sadd.
//      The `witness_method` lines that remain are the unused generic fallback bodies.
//   3. Cross-module SIL (Outputs/consumer.sil): grep witness_method = 0. With SIL bodies
//      available (@inlinable / package-CMO), `total` inlines to direct pointer arithmetic in
//      the consumer. Default cross-PACKAGE (non-inlinable) instead makes an opaque call into
//      the already-specialized concrete `total` — still 0 witness dispatch.
//
// Conditions: two protocol conformers present (real witness table); storage is ~Copyable;
// Element is a suppressed associated type. None of these defeat specialization.
//
// Scope ([EXP-020]): this is a faithful REDUCTION proving the COMPILER CAPABILITY the
// Layer-2-hoist design relies on. It does NOT prove the production swift-buffer-linear
// refactor specializes — that requires doing the refactor and re-checking in-package SIL.

import StorageCore

let leaf = LinearHeap(capacity: 1024)

// Hot loop across the module boundary into the non-@inlinable concrete leaf.
var acc = 0
for _ in 0..<10_000 {
    acc &+= leaf.total(count: 1024)
}

// Each total(count: 1024) sums 1024 ones → 1024; × 10_000 iterations.
print("sum:", acc)  // expect: 10240000
