// MARK: - V01: Baseline — Minimal @_rawLayout + Deinit Types
// Purpose: Establish baseline — standalone @_rawLayout + deinit types do NOT crash.
//          This proves the bug is context-sensitive per [EXP-004a].
// Hypothesis: Minimal ~Copyable struct with @_rawLayout + deinit compiles in release
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — no crash. Standalone types build fine under -O.
//         The crash requires sufficient cross-module serialized SIL.
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: rawlayout-deinit-investigation (Variants 1-3)
// Supports: diagnosis Step 5 — standalone reproducer does not crash

import Synchronization

// --- Infrastructure ---

final class DeinitTracker: Sendable {
    let _count = Atomic<Int>(0)
    var count: Int { _count.load(ordering: .relaxed) }
    func increment() { _count.wrappingAdd(1, ordering: .relaxed) }
}

// --- Variant 1a: Simple ~Copyable struct with @_rawLayout + deinit ---

@_rawLayout(size: 16, alignment: 8)
struct RawStorage1: ~Copyable {
    deinit { }
}

// --- Variant 1b: ~Copyable struct with @_rawLayout + tracked deinit ---

@_rawLayout(size: 16, alignment: 8)
struct RawStorage2: ~Copyable {
    deinit { }
}

// --- Variant 1c: Generic ~Copyable with @_rawLayout ---

@_rawLayout(size: 16, alignment: 8)
struct GenericRawStorage<Element: ~Copyable>: ~Copyable {
    deinit { }
}

// --- Variant 1d: Value-generic ~Copyable with @_rawLayout ---

@_rawLayout(size: 16, alignment: 8)
struct ValueGenericRawStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    deinit { }
}

// --- Variant 1e: Nested in generic enum (mirrors Buffer<Element> pattern) ---

enum Container<Element: ~Copyable> {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    struct Inline<let capacity: Int>: ~Copyable {
        deinit { }
    }
}

// --- Instantiation ---

func test1a() {
    let _ = RawStorage1()
    print("V01-1a: simple @_rawLayout + deinit — OK")
}

func test1b() {
    let _ = RawStorage2()
    print("V01-1b: tracked deinit — OK")
}

func test1c() {
    let _ = GenericRawStorage<Int>()
    print("V01-1c: generic @_rawLayout — OK")
}

func test1d() {
    let _ = ValueGenericRawStorage<Int, 4>()
    print("V01-1d: value-generic @_rawLayout — OK")
}

func test1e() {
    let _ = Container<Int>.Inline<4>()
    print("V01-1e: nested in generic enum — OK")
}

test1a()
test1b()
test1c()
test1d()
test1e()
print("\nAll V01 variants pass — standalone types do not crash under -O")
