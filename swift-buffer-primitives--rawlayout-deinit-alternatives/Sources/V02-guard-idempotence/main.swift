// MARK: - V02: Deinit Guard Idempotence
// Purpose: Test reference-type guard patterns that enable idempotent cleanup
//          from non-mutating functions (like deinit). Guards prevent double-free
//          when deinitialize() is called explicitly before deinit runs.
// Hypothesis: Reference-type guard enables idempotent non-mutating cleanup
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — dedicated IdempotentGuard class enables clean idempotent
//         cleanup from non-mutating contexts.
//
//         V1: CONFIRMED — basic reference mutation from non-mutating works
//         V2: CONFIRMED — DeinitGuard class (idempotent)
//         V3: NOT VIABLE — AnyObject? requires mutating
//         V4: CONFIRMED — dedicated IdempotentGuard class (cleanest)
//         V5: CONFIRMED — guard pattern with @_rawLayout storage
//         V6: CONFIRMED — combined approach with existing field
//
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: deinit-guard-idempotence (V1-V6)
// Supports: per-slot-initialization-tracking.md, inline-deinitialize-state-reset.md

import Synchronization

// --- V1: Basic reference mutation from non-mutating ---

final class Counter: Sendable {
    let _value = Atomic<Int>(0)
    var value: Int { _value.load(ordering: .relaxed) }
    func increment() { _value.wrappingAdd(1, ordering: .relaxed) }
}

struct V1_RefMutation: ~Copyable {
    let counter = Counter()

    func nonMutatingIncrement() {
        counter.increment()
    }
}

// --- V4: Dedicated IdempotentGuard class (recommended pattern) ---

final class IdempotentGuard: Sendable {
    let _cleaned = Atomic<Bool>(false)

    /// Returns true if this is the FIRST call (cleanup should proceed).
    /// Returns false on subsequent calls (cleanup already done).
    func claim() -> Bool {
        !_cleaned.exchange(true, ordering: .acquiringAndReleasing)
    }
}

struct V4_Guarded: ~Copyable {
    let guard_ = IdempotentGuard()

    @_rawLayout(size: 64, alignment: 8)
    struct _Storage: ~Copyable { }
    var storage = _Storage()

    /// Safe to call multiple times — only first call does cleanup.
    func cleanup() {
        guard guard_.claim() else {
            print("  V4: cleanup already done, skipping")
            return
        }
        print("  V4: performing cleanup (first call)")
    }

    deinit {
        cleanup()
    }
}

// --- Tests ---

func testV1() {
    print("=== V1: Reference mutation from non-mutating ===")
    let v = V1_RefMutation()
    v.nonMutatingIncrement()
    v.nonMutatingIncrement()
    print("  Counter: \(v.counter.value)")  // 2
}

func testV4() {
    print("\n=== V4: IdempotentGuard ===")
    do {
        let v = V4_Guarded()
        v.cleanup()  // First call — performs cleanup
        v.cleanup()  // Second call — skipped
        // deinit also calls cleanup() — skipped (already done)
    }
}

func testV4_deinit_only() {
    print("\n=== V4: Deinit-only path ===")
    do {
        let _ = V4_Guarded()
        // No explicit cleanup — deinit handles it
    }
}

testV1()
testV4()
testV4_deinit_only()

print("\nSUMMARY:")
print("  IdempotentGuard pattern enables safe idempotent cleanup")
print("  from non-mutating functions (including deinit).")
print("  Prevents double-free when explicit deinitialize() precedes deinit.")
