// MARK: - V05: Class-Reference Interaction
// Purpose: Test interaction between class references (Storage.Heap) and @_rawLayout
//          types in the same struct. Ring.Inline can't be in Ring's struct body
//          because Ring stores Storage.Heap (class ref).
// Hypothesis: Class ref + @_rawLayout sibling field contributes to crash
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED in isolation — class ref + @_rawLayout compiles fine standalone.
//
//         PRODUCTION FINDING (2026-03-20):
//         Ring.Inline can't be in Ring's struct body because Ring stores
//         Storage.Heap (class ref). Slab/Arena CAN host Inline because their
//         storage types aren't class-based. The class reference adds to the
//         cross-module SIL complexity that triggers the LLVM verifier crash.
//
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: rawlayout-release-verifier-crash (V13-V27, RealStorageModule)
// Supports: New finding #2 — class-ref interaction

// --- Simulated class-based storage (mirrors Storage.Heap) ---

final class HeapStorage<Element: ~Copyable>: @unchecked Sendable {
    let buffer: UnsafeMutablePointer<Element>
    var count: Int

    init(capacity: Int) {
        self.buffer = .allocate(capacity: capacity)
        self.count = 0
    }

    deinit {
        for i in 0..<count {
            unsafe buffer.advanced(by: i).deinitialize(count: 1)
        }
        buffer.deallocate()
    }
}

// --- @_rawLayout type ---

@_rawLayout(size: 64, alignment: 8)
struct InlineStorage<Element: ~Copyable>: ~Copyable {
    deinit { }
}

// --- Container with class ref + @_rawLayout sibling ---

enum Container<Element: ~Copyable> {
    struct Ring: ~Copyable {
        var heap: HeapStorage<Element>  // class reference

        struct Inline<let capacity: Int>: ~Copyable {
            var storage: InlineStorage<Element>  // @_rawLayout

            init() {
                self.storage = InlineStorage()
            }

            deinit { }
        }

        init(capacity: Int) {
            self.heap = HeapStorage(capacity: capacity)
        }
    }
}

func test() {
    let ring = Container<Int>.Ring(capacity: 8)
    let _ = Container<Int>.Ring.Inline<4>()
    print("V05: Class ref (\(type(of: ring.heap))) + @_rawLayout — OK (standalone)")
    print("NOTE: In production, Ring.Inline in Ring's struct body crashes because")
    print("      Ring stores Storage.Heap (class ref). Slab/Arena CAN host Inline.")
}

test()
