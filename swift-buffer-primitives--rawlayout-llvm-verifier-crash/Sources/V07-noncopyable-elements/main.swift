// MARK: - V07: ~Copyable Elements in @_rawLayout
// Purpose: Verify @_rawLayout supports ~Copyable elements.
//          Eliminates ~Copyable element type as a contributing factor to the crash.
// Hypothesis: @_rawLayout works with ~Copyable elements
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — @_rawLayout fully supports ~Copyable elements.
//         All 7 variants compile and run. ~Copyable element type is NOT
//         a contributing factor to the LLVM verifier crash.
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: rawlayout-noncopyable-elements
// Supports: eliminates ~Copyable elements as crash cause

// --- Variant 1: Copyable element (baseline) ---

@_rawLayout(likeArrayOf: Int, count: 4)
struct V1_Copyable: ~Copyable { }

// --- Variant 2: ~Copyable element ---

struct Resource: ~Copyable {
    var value: Int
    init(_ v: Int) { value = v }
}

@_rawLayout(likeArrayOf: Resource, count: 4)
struct V2_Noncopyable: ~Copyable { }

// --- Variant 3: Generic outer struct with ~Copyable ---

struct GenericStorage<Element: ~Copyable>: ~Copyable {
    @_rawLayout(likeArrayOf: Element, count: 4)
    struct Inline: ~Copyable { }
}

// --- Variant 4: Nested in generic enum (production pattern) ---

enum Container<Element: ~Copyable> {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    struct Inline<let capacity: Int>: ~Copyable { }
}

// --- Variant 5: Full replica with nested types ---

enum FullReplica<Element: ~Copyable> {
    struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        struct _Raw: ~Copyable { }

        var _storage: _Raw

        init() { self._storage = _Raw() }

        deinit { }
    }
}

// --- Instantiation ---

func test() {
    let _ = V1_Copyable()
    print("V07-1: Copyable element — OK")

    let _ = V2_Noncopyable()
    print("V07-2: ~Copyable element — OK")

    let _ = GenericStorage<Int>.Inline()
    let _ = GenericStorage<Resource>.Inline()
    print("V07-3: Generic outer struct — OK")

    let _ = Container<Int>.Inline<4>()
    let _ = Container<Resource>.Inline<4>()
    print("V07-4: Nested in generic enum — OK")

    let _ = FullReplica<Int>.Inline<4>()
    let _ = FullReplica<Resource>.Inline<4>()
    print("V07-5: Full replica with deinit — OK")

    print("\nAll V07 variants pass — @_rawLayout supports ~Copyable elements")
}

test()
