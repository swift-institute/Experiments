// MARK: - unsafeBitCast of Generic Thin Function Pointer
//
// Purpose: Validate whether Swift 6.3.1 can unsafeBitCast a generic
//   `@convention(thin)` function pointer without crashing. This is the
//   workaround justification for `Ownership.Transfer.Box.Header` storing
//   `destroyPayload: (UnsafeMutableRawPointer, Int) -> Void` as a
//   heap-allocating closure (capturing `T` and `E` for deinitialize)
//   instead of a thin function pointer.
//
// Hypothesis: STILL CRASHES on Swift 6.3.1. The previous documentation
//   stated "Swift 6.2.3 crashes when unsafeBitCast'ing generic thin
//   function pointers" without a tracking URL. Revalidate here.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Status: STILL PRESENT (verified 2026-04-23)
//
// Result: STILL PRESENT — V1 fails to compile with
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//           error: INTERNAL ERROR: feature not implemented:
//                  nontrivial thin function reference
//         at the return-closure site (main.swift:33:12). The closure
//         captures generic type `T` to call `deinitialize(count: 1)` —
//         that capture makes the thin function reference "nontrivial",
//         which the compiler does not support.
//
//         V2 (closure baseline, current workaround) compiles and runs
//         cleanly.
//
//         Decision: keep `Ownership.Transfer.Box.Header.destroyPayload`
//         as a heap-allocating closure per [DOC-045] WORKAROUND in the
//         source. Revisit when the compiler implements nontrivial thin
//         function references or Swift provides a static witness API.

// ============================================================================
// MARK: - V1: Thin function pointer with generic signature (compile-time probe)
// ============================================================================
//
// A destroy function needs to know `T` to call `.deinitialize(count: 1)`,
// but consumers of the Box header shouldn't have to know `T`. The
// "ideal" shape: specialise per T and erase via unsafeBitCast.

typealias TypeErasedDestroy = @convention(thin) (UnsafeMutableRawPointer, Int) -> Void

func makeTypedDestroy<T>(_ type: T.Type) -> @convention(thin) (UnsafeMutableRawPointer, Int) -> Void {
    return { base, offset in
        unsafe (base + offset).assumingMemoryBound(to: T.self).deinitialize(count: 1)
    }
}

struct IntPayload {
    var value: Int
    init(_ v: Int) { self.value = v }
}

// Allocate a payload and destroy it via the bitcast.
do {
    let ptr = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<IntPayload>.size,
                                               alignment: MemoryLayout<IntPayload>.alignment)
    let payloadPtr = unsafe ptr.assumingMemoryBound(to: IntPayload.self)
    unsafe payloadPtr.initialize(to: IntPayload(42))

    // Obtain thin function pointer specialised on IntPayload
    let specialized = makeTypedDestroy(IntPayload.self)

    // Erase generic signature via unsafeBitCast
    let erased: TypeErasedDestroy = unsafe unsafeBitCast(specialized, to: TypeErasedDestroy.self)

    // Invoke erased
    unsafe erased(ptr, 0)
    unsafe ptr.deallocate()

    print("V1 thin-fn-ptr bitcast: completed without crash")
}

// ============================================================================
// MARK: - V2: Closure-capture baseline (current workaround, documented)
// ============================================================================

typealias ClosureDestroy = (UnsafeMutableRawPointer, Int) -> Void

func makeClosureDestroy<T>(_ type: T.Type) -> ClosureDestroy {
    return { base, offset in
        unsafe (base + offset).assumingMemoryBound(to: T.self).deinitialize(count: 1)
    }
}

do {
    let ptr = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<IntPayload>.size,
                                               alignment: MemoryLayout<IntPayload>.alignment)
    let payloadPtr = unsafe ptr.assumingMemoryBound(to: IntPayload.self)
    unsafe payloadPtr.initialize(to: IntPayload(99))

    let closure = makeClosureDestroy(IntPayload.self)
    unsafe closure(ptr, 0)
    unsafe ptr.deallocate()

    print("V2 closure-capture baseline: completed")
}

// Expected outcomes:
//   V1 completes → workaround is obsolete; migrate Box.Header to thin fn ptr
//   V1 crashes at compile or runtime → workaround stays, update comment
//                                      with the 6.3.1 diagnostic
