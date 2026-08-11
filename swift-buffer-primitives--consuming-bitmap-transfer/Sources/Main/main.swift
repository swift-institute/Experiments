// MARK: - Consuming Bitmap Transfer Experiment
// Purpose: Find the principled way to move a ~Copyable field from a consumed
//          struct (declared in Core module) into a class in another module.
//
// Toolchain: Swift 6.2
// Platform: macOS (arm64)
//
// Result: CONFIRMED — Variant 7 (mutating swap) is the principled solution
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-02-11
//
// Findings:
//   Variant 1 (direct partial consume): REFUTED — "non-frozen type"
//   Variant 3 (consume self to local): REFUTED — "non-frozen type"
//   Variant 5a (consuming helper, tuple return): REFUTED — tuple with ~Copyable unsupported
//   Variant 5b (consuming helper, deinit): REFUTED — "cannot partially consume when deinit"
//   Variant 6 (@frozen + deinit): REFUTED — deinit blocks even @frozen
//   Variant 7 (mutating takeBitmap swap): CONFIRMED — clean ownership transfer
//   Variant 8 (no-deinit, cross-module): REFUTED — "non-frozen type"
//
// Evidence (Variant 7 output):
//   Container.deinit — bitmap at deinit has []     ← empty replacement
//   Bitmap.deinit (data: [])                       ← replacement cleaned up
//   state.bitmap.data = [7, 8, 9]                  ← State owns original data
//   State.deinit — bitmap has 3 entries             ← State cleans up
//   Bitmap.deinit (data: [7, 8, 9])                ← original bitmap freed
//
// Why Variant 7 works:
//   1. takeBitmap() is MUTATING, not CONSUMING — no partial consumption
//   2. Swap replaces bitmap with empty sentinel — deinit finds nothing
//   3. The original bitmap is MOVED into the return value
//   4. The consuming func accesses Copyable fields normally, calls mutating
//      method for ~Copyable field, then self is consumed (deinit runs)
//
// Design principle:
//   For ~Copyable types with deinit, the swap pattern is the principled way
//   to transfer ownership of ~Copyable fields. The Core module provides
//   the mutating accessor; consumers call it before self is destroyed.

import Core

final class State {
    let storage: Storage
    var bitmap: Bitmap

    init(storage: Storage, bitmap: consuming Bitmap) {
        self.storage = storage
        self.bitmap = bitmap
    }

    deinit {
        print("State.deinit — bitmap has \(bitmap.data.count) entries")
    }
}

// MARK: - Variant 7: Mutating takeBitmap() swap pattern — CONFIRMED

extension Container {
    consuming func variant7() -> State {
        let s = storage
        let b = header.takeBitmap()
        return State(storage: s, bitmap: b)
    }
}

// MARK: - Test

func testVariant7() {
    print("=== Variant 7: takeBitmap() swap ===")
    let c = Container(
        header: Header(bitmap: Bitmap(data: [7, 8, 9])),
        storage: Storage(name: "v7")
    )
    let state = c.variant7()
    print("state.bitmap.data = \(state.bitmap.data)")
    print("state.storage.name = \(state.storage.name)")
}

testVariant7()
print("=== Done ===")
